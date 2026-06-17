#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# go-pkg-harness 安装脚本（macOS / Linux）
# Go 扩展包 / 第三方库开发专用
#
# 用法：
#   cd /path/to/your-project
#   bash /path/to/harness-engineering/go-pkg-harness/setup.sh
#
# 实际逻辑在共享库 scripts/install-harness.sh，本文件只做入口装配。
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=../scripts/install-harness.sh
. "${SCRIPT_DIR}/../scripts/install-harness.sh"

install_harness "go-pkg-harness" "go-pkg-harness" "${SCRIPT_DIR}"
