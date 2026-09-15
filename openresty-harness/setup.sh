#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# openresty-harness 安装脚本（macOS / Linux）
# OpenResty / ngx_lua 项目（网关、WAF、Nginx 内 Lua 接口服务、Lua 脚本集合）
#
# 用法：
#   cd /path/to/your-project
#   bash /path/to/harness-engineering/openresty-harness/setup.sh
#
# 实际逻辑在共享库 scripts/install-harness.sh，本文件只做入口装配。
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=../scripts/install-harness.sh
. "${SCRIPT_DIR}/../scripts/install-harness.sh"

install_harness "openresty-harness" "openresty-harness" "${SCRIPT_DIR}"
