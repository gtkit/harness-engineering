#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# go-grpc-harness 安装脚本（macOS / Linux）
# 纯 Go gRPC 后端服务（grpc-go + buf + protovalidate + ormx + gtkit）
#
# 用法：
#   cd /path/to/your-project
#   bash /path/to/harness-engineering/go-grpc-harness/setup.sh
#
# 只装规则（CLAUDE.md/AGENTS.md/.harness/），对存量项目安全。
# 新项目要生成代码骨架用同目录 scaffold.sh。
# 实际逻辑在共享库 scripts/install-harness.sh，本文件只做入口装配。
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=../scripts/install-harness.sh
. "${SCRIPT_DIR}/../scripts/install-harness.sh"

install_harness "go-grpc-harness" "go-grpc-harness" "${SCRIPT_DIR}"
