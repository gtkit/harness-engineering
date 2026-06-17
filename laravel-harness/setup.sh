#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# laravel-harness 安装脚本（macOS / Linux）
# 纯 Laravel 项目（API / Web）
#
# 用法：
#   cd /path/to/your-project
#   bash /path/to/harness-engineering/laravel-harness/setup.sh
#
# 实际逻辑在共享库 scripts/install-harness.sh，本文件只做入口装配。
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=../scripts/install-harness.sh
. "${SCRIPT_DIR}/../scripts/install-harness.sh"

install_harness "laravel-harness" "laravel-harness" "${SCRIPT_DIR}"
