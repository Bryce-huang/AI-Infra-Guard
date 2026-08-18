#!/bin/bash

# AI-Infra-Guard 函数平台单容器启动脚本
# 将 docker-compose 中的 webserver + agent + api-checker 合并到一个容器内：
#   - api-checker (uvicorn) 监听 127.0.0.1:8000（仅容器内）
#   - agent 通过 127.0.0.1 WebSocket 回连 webserver（不经过平台网关）
#   - webserver 监听 0.0.0.0:${PORT}（平台注入，默认 8080），作为 PID 主进程

set -u

PORT="${PORT:-8080}"

# 可写目录：默认落在 /tmp（函数平台根文件系统通常只读）
# 平台若挂载了持久卷，通过环境变量覆盖这些路径即可
export DB_PATH="${DB_PATH:-/tmp/aig/db/tasks.db}"
export UPLOAD_DIR="${UPLOAD_DIR:-/tmp/aig/uploads}"
export AIG_API_CHECKER_DATA_DIR="${AIG_API_CHECKER_DATA_DIR:-/tmp/aig/api-checker-data}"

export AIG_SERVER="127.0.0.1:${PORT}"
export AIG_API_CHECKER_URL="http://127.0.0.1:8000"

mkdir -p "$(dirname "$DB_PATH")" "$UPLOAD_DIR" "$AIG_API_CHECKER_DATA_DIR" /tmp/aig/logs

pids=()

cleanup() {
    echo "[faas] 收到终止信号，停止所有子进程..." >&2
    for p in "${pids[@]}"; do
        kill -TERM "$p" 2>/dev/null || true
    done
    wait 2>/dev/null || true
    exit 0
}
trap cleanup INT TERM

echo "[faas] 启动 api-checker (127.0.0.1:8000)..."
/app/api-checker-venv/bin/python -m uvicorn services.api_checker.server:app \
    --host 127.0.0.1 --port 8000 --no-access-log &
pids+=($!)

echo "[faas] 启动 agent (回连 127.0.0.1:${PORT})..."
/app/agent &
pids+=($!)

sleep 2

echo "[faas] 启动 webserver (0.0.0.0:${PORT})..."
./ai-infra-guard webserver --server "0.0.0.0:${PORT}" &
pids+=($!)

# 任一核心进程退出则整体退出，交给平台重新拉起实例
wait -n
echo "[faas] 检测到子进程退出，容器终止" >&2
cleanup
