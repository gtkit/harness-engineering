#!/usr/bin/env bash
set -euo pipefail

# frontend-harness 安装脚本（macOS / Linux）
# Vue 3 + Vite/TypeScript 前端项目。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=../scripts/install-harness.sh
. "${SCRIPT_DIR}/../scripts/install-harness.sh"

install_harness "frontend-harness" "frontend-harness" "${SCRIPT_DIR}"
