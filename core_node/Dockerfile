# 原始镜像
FROM ghcr.io/szemeng76/lunatv:5.9.1

USER root

# 1. 安装运行环境：Redis (数据库), Python (备份脚本), Bash
RUN apk add --no-cache redis python3 py3-pip bash jq curl && \
    python3 -m venv /root/env_core && \
    /root/env_core/bin/pip install --no-cache-dir requests webdavclient3

# 2. 准备数据目录
RUN mkdir -p /data && chmod 777 /data

# 3. 环境变量配置
# 【重要】HF 端口是 7860，这里必须覆盖原镜像的 3000
ENV PORT=7860
# 数据库指向本地 Redis
ENV NEXT_PUBLIC_STORAGE_TYPE=kvrocks
ENV KVROCKS_URL=redis://127.0.0.1:6666

EXPOSE 7860

# 4. 植入启动脚本
COPY boot.sh /boot.sh
RUN chmod +x /boot.sh

# 5. 启动入口
ENTRYPOINT ["/bin/bash", "/boot.sh"]
