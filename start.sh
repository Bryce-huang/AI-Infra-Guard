#!/bin/bash

# AI-Infra-Guard 启动脚本
# 创建必要的目录和文件，设置权限，启动服务

set -e

# 权限修改失败时提示并继续（例如挂载卷上无法改权限）
warn_or_continue() { echo "Warning: $1" >&2; }

echo 正在初始化 AI-Infra-Guard 服务...
# 以非 root 用户(app:apps)运行：仅初始化实际使用的可写目录，挂载卷权限不足时告警跳过
DB_DIR="$(dirname "${DB_PATH:-/app/db/tasks.db}")"
UPLOAD_DIR="${UPLOAD_DIR:-/app/uploads}"
mkdir -p "$DB_DIR" "$UPLOAD_DIR" ./logs 2>/dev/null || warn_or_continue "Skip directory creation on mounted volume"

echo 初始化日志文件...
touch ./logs/trpc.log 2>/dev/null || warn_or_continue "Skip log file creation on mounted volume"

echo 启动AI-Infra-Guard Web 服务...
# 函数平台会通过 PORT 环境变量注入监听端口；默认 8080（本地/容器部署不受影响）
exec ./ai-infra-guard webserver --server 0.0.0.0:${PORT:-8080}