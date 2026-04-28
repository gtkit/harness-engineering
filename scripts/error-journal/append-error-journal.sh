#!/usr/bin/env sh
set -eu

if [ "$#" -lt 4 ]; then
  echo "usage: $0 <repo-root> <event-type> <area> <summary>" >&2
  exit 1
fi

ROOT="$1"
shift
EVENT_TYPE="$1"
shift
AREA="$1"
shift
SUMMARY="$*"

FILE="${ROOT}/.harness/error-journal.md"

if [ ! -f "${FILE}" ]; then
  echo "missing: ${FILE}" >&2
  exit 1
fi

DAY="$(date '+%Y%m%d')"
STAMP="$(date '+%Y-%m-%dT%H:%M:%S%z')"
COUNT="$(grep -c '^## \[ERR-' "${FILE}" 2>/dev/null || true)"
SEQ="$(printf '%03d' "$((COUNT + 1))")"
ID="ERR-${DAY}-${SEQ}"

cat >>"${FILE}" <<EOF

## [${ID}] ${EVENT_TYPE}

**Logged**: ${STAMP}
**Status**: open
**Area**: ${AREA}

### Summary
${SUMMARY}

### What Happened
待补充

### Root Cause
待补充

### Corrective Action
待补充

### Prevention Rule
待补充

### Related Files
- 待补充

### Validation Added
- 待补充

---
EOF

printf '%s\n' "${ID}"
