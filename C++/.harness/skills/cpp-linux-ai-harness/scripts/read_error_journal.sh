#!/usr/bin/env sh
set -eu

ROOT="${1:-.}"
FILE="${ROOT}/.harness/error-journal.md"

if [ ! -f "${FILE}" ]; then
  echo "missing: ${FILE}" >&2
  exit 1
fi

sed -n '1,240p' "${FILE}"
