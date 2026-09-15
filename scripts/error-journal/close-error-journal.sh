#!/usr/bin/env sh
set -eu

# 关闭一条错误记录：把该条目的 Status 从 open 改为 closed，并记下关闭时间。
# SessionStart hook 只注入 open 的条目，关闭后就不再每次会话都出现。
if [ "$#" -lt 2 ]; then
  echo "usage: $0 <repo-root> <ERR-ID> [resolution]" >&2
  exit 1
fi

ROOT="$1"
ID="$2"
shift 2
RESOLUTION="$*"
FILE="${ROOT}/.harness/error-journal.md"

if [ ! -f "${FILE}" ]; then
  echo "missing: ${FILE}" >&2
  exit 1
fi
if ! grep -q "^## \[${ID}\]" "${FILE}"; then
  echo "not found: ${ID}" >&2
  exit 1
fi

STAMP="$(date '+%Y-%m-%dT%H:%M:%S%z')"
TMP="$(mktemp)"
# 只改目标条目内部的 Status 行：从匹配标题起，遇到下一条标题前的第一个 **Status**: open
awk -v id="## [${ID}]" -v stamp="${STAMP}" -v note="${RESOLUTION}" '
  index($0, id) == 1 { inside = 1; print; next }
  /^## \[ERR-/ { inside = 0 }
  inside && /^\*\*Status\*\*: open/ {
    print "**Status**: closed"
    print "**Closed**: " stamp
    if (note != "") print "**Resolution**: " note
    inside = 0
    next
  }
  { print }
' "${FILE}" > "${TMP}"
mv "${TMP}" "${FILE}"
printf '%s closed\n' "${ID}"
