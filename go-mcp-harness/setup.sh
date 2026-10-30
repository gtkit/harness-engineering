#!/usr/bin/env bash
set -euo pipefail

# Go MCP 规则安装入口。只装 harness；传输选择由目标项目决定。
# 在已确认的目标原项目目录中执行，不生成业务代码或安装 Go 依赖。
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=../scripts/install-harness.sh
. "${SCRIPT_DIR}/../scripts/install-harness.sh"

install_harness "go-mcp-harness" "go-mcp-harness" "${SCRIPT_DIR}"
