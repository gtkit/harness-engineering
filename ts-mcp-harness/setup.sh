#!/usr/bin/env bash
set -euo pipefail

# TypeScript MCP 规则入口；只安装 harness，不安装 Node/Go 或业务依赖。
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=../scripts/install-harness.sh
. "${SCRIPT_DIR}/../scripts/install-harness.sh"

install_harness "ts-mcp-harness" "ts-mcp-harness" "${SCRIPT_DIR}"
