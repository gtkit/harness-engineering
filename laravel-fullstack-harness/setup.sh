#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# laravel-fullstack-harness 安装脚本（macOS / Linux）
# Laravel 后端 + Vue 前端，同一仓库
#
# 用法：
#   cd /path/to/your-project
#   bash /path/to/harness-engineering/laravel-fullstack-harness/setup.sh
#
# 实际逻辑在共享库 scripts/install-harness.sh，本文件只做入口装配。
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=../scripts/install-harness.sh
. "${SCRIPT_DIR}/../scripts/install-harness.sh"

install_harness "laravel-fullstack-harness" "laravel-fullstack-harness" "${SCRIPT_DIR}"
