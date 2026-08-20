#!/bin/sh

# uv 替身脚本（通过 AIG_UV_BIN 挂给 AI-Infra-Guard）
#
# 背景：新版 uv 中 `uv run --no-project` 会在"空隔离环境"里执行命令，
# 构建时安装的任何依赖（系统 site-packages 或项目 .venv）都不可见，
# 导致 AIG-PromptSecurity / skill-scan 等任务报 ModuleNotFoundError。
#
# 处理：拦截 "run --no-project <script> ..."，改用系统 python3 直接执行
#（依赖已在镜像构建时装入系统 site-packages）；其余 uv 调用原样透传。

if [ "$1" = "run" ] && [ "$2" = "--no-project" ]; then
    shift 2
    exec python3 "$@"
fi

exec /usr/local/bin/uv "$@"
