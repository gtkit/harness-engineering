#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# fullstack-harness 安装脚本（macOS / Linux）
# Go 后端 + Vue 前端，同一项目目录
#
# 用法：
#   cd /path/to/your-project
#   bash /path/to/harness-engineering/fullstack-harness/setup.sh
#
# 实际逻辑在共享库 scripts/install-harness.sh，本文件只做入口装配。
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=../scripts/install-harness.sh
. "${SCRIPT_DIR}/../scripts/install-harness.sh"

install_harness "fullstack-harness" "fullstack-harness" "${SCRIPT_DIR}"
