# 一次性工具容器：Tinybird CLI + Ghost schema
# 用于在 Zeabur 上临时部署，初始化 Tinybird（部署 schema、取凭证），用完即删。
# Dockerfile 参考官方 ghost-docker 的 tinybird 容器写法。

FROM python:3.14-slim

# Tinybird CLI 安装依赖（官方做法）
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 安装 Tinybird CLI（官方安装脚本，装到 /root/.local/bin）
RUN curl https://tinybird.co | sh
ENV PATH="/root/.local/bin:$PATH"

# 把 Ghost 官方 Tinybird schema 拷进镜像
COPY ghost-tinybird-schema ./ghost-tinybird-schema

# 保持容器运行，方便通过 Zeabur「命令执行」进入操作
CMD ["sleep", "infinity"]
