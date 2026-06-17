#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# go-harness 安装脚本（macOS / Linux）
# 纯 Go 后端业务服务（Gin + GORM + gtkit）
#
# 用法：
#   cd /path/to/your-project
#   bash /path/to/harness-engineering/go-harness/setup.sh
#
# 实际逻辑在共享库 scripts/install-harness.sh，本文件只做入口装配。
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=../scripts/install-harness.sh
. "${SCRIPT_DIR}/../scripts/install-harness.sh"

install_harness "go-harness" "go-harness" "${SCRIPT_DIR}"
