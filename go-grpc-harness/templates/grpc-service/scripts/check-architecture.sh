#!/usr/bin/env bash
# 架构传感器:分层禁令检查(无违例=通过,退出码 0)。
# 规则来源: .harness/guides/architecture.md。
# 用 grep 而非 rg,保证 CI/裸机可移植。
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0

# check <描述> <ERE 模式> <目录...>
check() {
  local desc="$1" pattern="$2"
  shift 2
  local out
  out=$(grep -rEn --include='*.go' --exclude='*_test.go' "$pattern" "$@" 2>/dev/null || true)
  if [ -n "${out}" ]; then
    echo "✗ ${desc}:"
    echo "${out}"
    fail=1
  fi
}

# module 层(application/transport)禁止基础设施与熔断/渠道 SDK
check "module 层禁止 gorm/repository/gobreaker" \
  'gorm\.io/gorm|internal/repository/|sony/gobreaker' \
  internal/module

# repository 禁止业务模块
check "repository 禁止 module" \
  'internal/module/' \
  internal/repository

# internal/pkg 禁止反向依赖业务模块
check "internal/pkg 禁止反向依赖 internal/module" \
  'internal/module/' \
  internal/pkg

# 渠道 client 单点供给示例(接入有 token 互斥类约束的 SDK 时启用,把 <sdk> 换成真实包名):
# out=$(grep -rEn --include='*.go' --exclude='*_test.go' '<sdk>\.New\(' internal | grep -v 'internal/runtime/module/<supplier>/' || true)
# [ -n "${out}" ] && { echo "✗ <sdk>.New 出现在共享供给组件之外:"; echo "${out}"; fail=1; }

if [ "${fail}" -eq 0 ]; then
  echo "✓ 架构传感器通过"
fi
exit "${fail}"
