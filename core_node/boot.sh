#!/bin/bash

# ==========================================
# Kernel Monitor Daemon (隐匿启动脚本)
# ==========================================

# 1. 环境准备
source /root/env_core/bin/activate
DATA_DIR="/data"
mkdir -p "$DATA_DIR"

# 2. 启动 Redis (数据库)
echo "[Kernel] Starting storage subsystem..."
# 后台启动 Redis，数据存放在 /data/dump.rdb
redis-server --port 6666 --dir "$DATA_DIR" --dbfilename dump.rdb --daemonize yes

# 3. WebDAV 恢复逻辑 (保留最新5份)
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
    echo "[Kernel] Syncing state from remote..."
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
        print('[Kernel] No remote backup found. Starting fresh.')
        sys.exit()
        
    latest = sorted(backups)[-1]
    print(f'[Kernel] Restoring backup: {latest}')
    
    local_tmp = f'/tmp/{latest}'
    with requests.get(f'$FULL_WEBDAV_URL/{latest}', auth=('$WEBDAV_USERNAME', '$WEBDAV_PASSWORD'), stream=True) as r:
        if r.status_code == 200:
            with open(local_tmp, 'wb') as f:
                for chunk in r.iter_content(8192): f.write(chunk)
            
            # 停止 Redis，恢复数据，再启动
            os.system('redis-cli -p 6666 shutdown')
            time.sleep(2)
            
            if os.path.exists('$DATA_DIR'): shutil.rmtree('$DATA_DIR')
            os.makedirs('$DATA_DIR', exist_ok=True)
            with tarfile.open(local_tmp, 'r:gz') as tar: tar.extractall('$DATA_DIR')
            
            os.system('redis-server --port 6666 --dir $DATA_DIR --dbfilename dump.rdb --daemonize yes')
            print('[Kernel] Restore complete.')
            os.remove(local_tmp)
except Exception as e:
    print(f'[Kernel] Warning: {str(e)}')
"
}

# 4. 守护进程：定时备份 (1小时一次，保留5份)
sync_loop() {
    if [[ -z "$WEBDAV_URL" ]]; then return; fi
    init_remote_dir
    while true; do
        INTERVAL=${SYNC_INTERVAL:-3600}
        sleep $INTERVAL
        
        # 强制 Redis 落盘
        redis-cli -p 6666 save
        
        if [ -d "$DATA_DIR" ]; then
            TS=$(date +%Y%m%d_%H%M%S)
            FNAME="${BACKUP_PREFIX}${TS}.tar.gz"
            TMP_FILE="/tmp/$FNAME"
            
            tar -czf "$TMP_FILE" -C "$DATA_DIR" .
            
            curl -f -s -u "$WEBDAV_USERNAME:$WEBDAV_PASSWORD" -T "$TMP_FILE" "$FULL_WEBDAV_URL/$FNAME"
            
            if [ $? -eq 0 ]; then
                echo "[Kernel] Backup saved: $FNAME"
                # 轮替逻辑
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

# 执行恢复和启动备份循环
restore_snapshot
sync_loop &

# 5. 启动 Luna TV 主程序 (修复版)
echo "[Kernel] Launching application interface..."

# 确保 Redis 没死
if ! pgrep -x "redis-server" > /dev/null; then
    redis-server --port 6666 --dir "$DATA_DIR" --dbfilename dump.rdb --daemonize yes
fi

# 切换到 App 目录 (Next.js 容器标准目录)
if [ -d "/app" ]; then
    cd /app
fi

# 智能启动逻辑
# Next.js 独立构建通常是 node server.js
# 开发构建通常是 npm start
if [ -f "server.js" ]; then
    echo "[Kernel] Starting via node server.js..."
    exec node server.js
elif [ -f "package.json" ]; then
    echo "[Kernel] Starting via npm start..."
    exec npm start
else
    echo "[Error] No entry file found. Keeping container alive for debug."
    ls -al
    sleep infinity
fi
