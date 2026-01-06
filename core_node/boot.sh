#!/bin/bash

# ==========================================
# Kernel Monitor Daemon (隐匿启动脚本)
# ==========================================

# 1. 环境准备
# 激活 Python 虚拟环境 (Dockerfile 中创建)
if [ -f "$HOME/env_core/bin/activate" ]; then
    source $HOME/env_core/bin/activate
fi

# 定义数据路径 (Redis数据 + Luna数据)
DATA_DIR="/data"
mkdir -p "$DATA_DIR"

# 2. 启动 Redis (作为后台数据库)
echo "[Kernel] Initializing internal storage subsystem..."
# 配置 Redis 将数据持久化到我们的备份目录
redis-server --port 6666 --dir "$DATA_DIR" --dbfilename dump.rdb --daemonize yes

# 3. WebDAV 恢复逻辑 (保留5份策略)
WEBDAV_BACKUP_PATH=${WEBDAV_BACKUP_PATH:-"luna_core_backup"}
WEBDAV_URL=${WEBDAV_URL%/}
FULL_WEBDAV_URL="${WEBDAV_URL}/${WEBDAV_BACKUP_PATH}"
BACKUP_PREFIX="core_snapshot_"

init_remote_dir() {
    if [[ -n "$WEBDAV_URL" ]]; then
        curl -s -X MKCOL -u "$WEBDAV_USERNAME:$WEBDAV_PASSWORD" "${FULL_WEBDAV_URL}" > /dev/null
    fi
}

restore_snapshot() {
    if [[ -z "$WEBDAV_URL" ]]; then return; fi
    echo "[Kernel] Checking for remote state..."
    python3 -c "
import sys, os, tarfile, requests, shutil, time
from webdav3.client import Client

opts = {
    'webdav_hostname': '$FULL_WEBDAV_URL',
    'webdav_login': '$WEBDAV_USERNAME',
    'webdav_password': '$WEBDAV_PASSWORD',
    'disable_check': True
}
try:
    client = Client(opts)
    backups = [f for f in client.list() if f.endswith('.tar.gz') and f.startswith('$BACKUP_PREFIX')]
    
    if not backups:
        print('[Kernel] Clean boot sequence.')
        sys.exit()
        
    latest = sorted(backups)[-1]
    print(f'[Kernel] Restoring state: {latest}')
    
    local_tmp = f'/tmp/{latest}'
    with requests.get(f'$FULL_WEBDAV_URL/{latest}', auth=('$WEBDAV_USERNAME', '$WEBDAV_PASSWORD'), stream=True) as r:
        if r.status_code == 200:
            with open(local_tmp, 'wb') as f:
                for chunk in r.iter_content(8192): f.write(chunk)
            
            # 停止 Redis 以便覆盖数据
            os.system('redis-cli -p 6666 shutdown')
            time.sleep(2)
            
            # 解压
            if os.path.exists('$DATA_DIR'): shutil.rmtree('$DATA_DIR')
            os.makedirs('$DATA_DIR', exist_ok=True)
            with tarfile.open(local_tmp, 'r:gz') as tar: tar.extractall('$DATA_DIR')
            
            # 重启 Redis
            os.system('redis-server --port 6666 --dir $DATA_DIR --dbfilename dump.rdb --daemonize yes')
            print('[Kernel] State restored.')
            os.remove(local_tmp)
except Exception as e:
    print(f'[Kernel] Warning: {str(e)}')
"
}

# 4. 守护进程：定时备份 (保留5份)
sync_loop() {
    if [[ -z "$WEBDAV_URL" ]]; then return; fi
    init_remote_dir
    while true; do
        INTERVAL=${SYNC_INTERVAL:-3600}
        sleep $INTERVAL
        
        # 触发 Redis 保存数据到磁盘
        redis-cli -p 6666 save
        
        if [ -d "$DATA_DIR" ]; then
            TS=$(date +%Y%m%d_%H%M%S)
            FNAME="${BACKUP_PREFIX}${TS}.tar.gz"
            TMP_FILE="/tmp/$FNAME"
            
            # 打包 /data 目录
            tar -czf "$TMP_FILE" -C "$DATA_DIR" .
            
            curl -f -s -u "$WEBDAV_USERNAME:$WEBDAV_PASSWORD" -T "$TMP_FILE" "$FULL_WEBDAV_URL/$FNAME"
            
            if [ $? -eq 0 ]; then
                echo "[Kernel] Snapshot saved: $FNAME"
                # 清理旧备份
                python3 -c "
from webdav3.client import Client
opts = {
    'webdav_hostname': '$FULL_WEBDAV_URL',
    'webdav_login': '$WEBDAV_USERNAME',
    'webdav_password': '$WEBDAV_PASSWORD'
}
try:
    c = Client(opts)
    files = sorted([f for f in c.list() if f.startswith('$BACKUP_PREFIX')])
    if len(files) > 5:
        for f in files[:-5]:
            c.clean(f)
except: pass
"
            fi
            rm -f "$TMP_FILE"
        fi
    done
}

# 执行恢复
restore_snapshot
# 后台启动备份循环
sync_loop &

# 5. 启动 Luna TV (主程序)
echo "[Kernel] Launching application interface..."
# 设置 Redis 连接串 (指向本地)
export KVROCKS_URL="redis://127.0.0.1:6666"

# 伪装并启动
# 注意：基于 lunatv 5.9.1 镜像，我们需要知道它原来的 CMD。
# 假设它是 node 且入口在 /app/server.js 或 next.js
# 我们直接调用 docker-entrypoint 或者 npm start
# 如果原镜像有 entrypoint，通常位于 /usr/local/bin/docker-entrypoint.sh
exec /usr/local/bin/docker-entrypoint.sh
