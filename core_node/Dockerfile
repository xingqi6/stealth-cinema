# 使用用户指定的 Luna 镜像
FROM ghcr.io/szemeng76/lunatv:5.9.1

# 切换到 root 安装依赖
USER root

# 1. 安装 Redis (替代 Kvrocks), Python (用于脚本)
RUN apk add --no-cache redis python3 py3-pip bash jq curl && \
    python3 -m venv /root/env_core && \
    /root/env_core/bin/pip install --no-cache-dir requests webdavclient3

# 2. 创建数据目录
RUN mkdir -p /data && chmod 777 /data

# 3. 环境变量配置 (固化用户配置)
ENV USERNAME=admin
ENV PASSWORD=000000
ENV NEXT_PUBLIC_STORAGE_TYPE=kvrocks
# 这里指向本地 Redis，虽然变量名叫 KVROCKS，但 Redis 协议兼容
ENV KVROCKS_URL=redis://127.0.0.1:6666
ENV SITE_BASE=https://your-domain.com
ENV NEXT_PUBLIC_SITE_NAME="LunaTV Enhanced"

# HF 端口
ENV PORT=3000
EXPOSE 3000

# 4. 植入启动脚本
COPY boot.sh /boot.sh
RUN chmod +x /boot.sh

# 5. 启动
ENTRYPOINT ["/bin/bash", "/boot.sh"]
