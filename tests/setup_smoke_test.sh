#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"

    grep -Fq "$pattern" "$file" || fail "expected ${file} to contain: ${pattern}"
}

assert_file_not_contains() {
    local file="$1"
    local pattern="$2"

    if grep -Fq "$pattern" "$file"; then
        fail "expected ${file} to not contain: ${pattern}"
    fi
}

assert_line_exists() {
    local file="$1"
    local line="$2"

    grep -Fxq "$line" "$file" || fail "expected ${file} to contain line: ${line}"
}

run_setup() {
    local harness_dir="$1"
    local project_dir="$2"
    local sandbox_home="$3"

    (
        cd "$project_dir"
        HOME="$sandbox_home" CODEX_HOME="$sandbox_home/.codex" \
            bash "${ROOT_DIR}/${harness_dir}/setup.sh" >/dev/null
    )
}

tmpdir="$(mktemp -d /tmp/harness-smoke-XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

go_home="${tmpdir}/go-home"
go_project="${tmpdir}/go-project"
mkdir -p "$go_home" "$go_project"
run_setup "go-harness" "$go_project" "$go_home"

test -f "${go_project}/.gitignore" || fail "go-harness should create .gitignore when missing"
assert_line_exists "${go_project}/.gitignore" ".harness/error-journal.md"
assert_line_exists "${go_project}/.gitignore" ".idea/"
assert_line_exists "${go_project}/.gitignore" ".DS_Store"

printf 'LOCAL CHANGE\n' > "${go_project}/.harness/guides/architecture.md"
run_setup "go-harness" "$go_project" "$go_home"
assert_file_contains "${go_project}/.harness/guides/architecture.md" "LOCAL CHANGE"

assert_file_contains "${ROOT_DIR}/go-harness/AGENTS.md" ".idea/"
assert_file_contains "${ROOT_DIR}/go-harness/AGENTS.md" ".DS_Store"
assert_file_contains "${ROOT_DIR}/go-pkg-harness/AGENTS.md" ".idea/"
assert_file_contains "${ROOT_DIR}/go-pkg-harness/AGENTS.md" ".DS_Store"
assert_file_contains "${ROOT_DIR}/go-pkg-harness/AGENTS.md" "github.com/gtkit/json"
assert_file_contains "${ROOT_DIR}/go-pkg-harness/AGENTS.md" "禁止 \`encoding/json\`"

assert_file_contains "${ROOT_DIR}/fullstack-harness/AGENTS.md" "backend/"
assert_file_contains "${ROOT_DIR}/fullstack-harness/AGENTS.md" "frontend/"
assert_file_not_contains "${ROOT_DIR}/fullstack-harness/AGENTS.md" "web/src/api/types.ts"
assert_file_not_contains "${ROOT_DIR}/go-harness/SKILL.md" "references/architecture.md"

printf 'setup smoke test passed\n'
