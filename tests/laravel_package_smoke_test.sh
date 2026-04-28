#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_file_exists() {
    local file="$1"
    test -f "$file" || fail "expected file: ${file}"
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"

    grep -Fq "$pattern" "$file" || fail "expected ${file} to contain: ${pattern}"
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

laravel_pkg="${ROOT_DIR}/laravel-harness"
laravel_fullstack_pkg="${ROOT_DIR}/laravel-fullstack-harness"
readme_file="${ROOT_DIR}/README.md"
ci_file="${ROOT_DIR}/.github/workflows/ci.yml"

assert_file_exists "${laravel_pkg}/setup.sh"
assert_file_exists "${laravel_pkg}/AGENTS.md"
assert_file_exists "${laravel_pkg}/SKILL.md"
assert_file_exists "${laravel_pkg}/SKILL.codex.md"
assert_file_exists "${laravel_pkg}/guides/architecture.md"
assert_file_exists "${laravel_pkg}/guides/http-and-api.md"
assert_file_exists "${laravel_pkg}/guides/data-and-eloquent.md"
assert_file_exists "${laravel_pkg}/guides/queues-events-scheduling.md"
assert_file_exists "${laravel_pkg}/guides/notifications-and-mail.md"
assert_file_exists "${laravel_pkg}/guides/testing-and-validation.md"
assert_file_exists "${laravel_pkg}/guides/laravel-modules.md"
assert_file_exists "${laravel_pkg}/guides/review-checklist.md"

assert_file_exists "${laravel_fullstack_pkg}/setup.sh"
assert_file_exists "${laravel_fullstack_pkg}/AGENTS.md"
assert_file_exists "${laravel_fullstack_pkg}/SKILL.md"
assert_file_exists "${laravel_fullstack_pkg}/SKILL.codex.md"
assert_file_exists "${laravel_fullstack_pkg}/guides/frontend-architecture.md"
assert_file_exists "${laravel_fullstack_pkg}/guides/frontend-api.md"
assert_file_exists "${laravel_fullstack_pkg}/guides/frontend-coding.md"

assert_file_contains "${laravel_pkg}/setup.sh" "HARNESS_FORCE_GUIDES"
assert_file_contains "${laravel_pkg}/setup.sh" ".harness/error-journal.md"
assert_file_contains "${laravel_pkg}/setup.sh" ".idea/"
assert_file_contains "${laravel_pkg}/setup.sh" ".DS_Store"
assert_file_contains "${laravel_pkg}/AGENTS.md" "nwidart/laravel-modules"
assert_file_contains "${laravel_pkg}/AGENTS.md" "Queue / Scheduler / Event / Notification"
assert_file_contains "${laravel_pkg}/guides/laravel-modules.md" "Modules/"

assert_file_contains "${laravel_fullstack_pkg}/AGENTS.md" "backend/"
assert_file_contains "${laravel_fullstack_pkg}/AGENTS.md" "frontend/"
assert_file_contains "${laravel_fullstack_pkg}/AGENTS.md" "Vue 3 + Vite + TypeScript"
assert_file_contains "${laravel_fullstack_pkg}/guides/frontend-api.md" "Laravel Resource"

assert_file_contains "${readme_file}" "laravel-harness"
assert_file_contains "${readme_file}" "laravel-fullstack-harness"
assert_file_contains "${readme_file}" "Laravel"
assert_file_contains "${ci_file}" "bash tests/laravel_package_smoke_test.sh"

tmpdir="$(mktemp -d /tmp/laravel-harness-smoke-XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

laravel_home="${tmpdir}/laravel-home"
laravel_project="${tmpdir}/laravel-project"
mkdir -p "$laravel_home" "$laravel_project"
run_setup "laravel-harness" "$laravel_project" "$laravel_home"

test -f "${laravel_project}/.gitignore" || fail "laravel-harness should create .gitignore"
assert_line_exists "${laravel_project}/.gitignore" ".harness/error-journal.md"
assert_line_exists "${laravel_project}/.gitignore" ".idea/"
assert_line_exists "${laravel_project}/.gitignore" ".DS_Store"
assert_line_exists "${laravel_project}/.gitignore" "findings.md"
assert_line_exists "${laravel_project}/.gitignore" "progress.md"
assert_line_exists "${laravel_project}/.gitignore" "task_plan.md"
assert_file_exists "${laravel_project}/CLAUDE.md"
assert_file_exists "${laravel_project}/AGENTS.md"
assert_file_exists "${laravel_project}/.harness/guides/laravel-modules.md"
assert_file_exists "${laravel_project}/.harness/scripts/read-error-journal.sh"
assert_file_exists "${laravel_project}/.harness/scripts/append-error-journal.sh"

printf 'LOCAL LARAVEL GUIDE\n' > "${laravel_project}/.harness/guides/http-and-api.md"
run_setup "laravel-harness" "$laravel_project" "$laravel_home"
assert_file_contains "${laravel_project}/.harness/guides/http-and-api.md" "LOCAL LARAVEL GUIDE"

laravel_fullstack_home="${tmpdir}/laravel-fullstack-home"
laravel_fullstack_project="${tmpdir}/laravel-fullstack-project"
mkdir -p "$laravel_fullstack_home" "$laravel_fullstack_project/backend" "$laravel_fullstack_project/frontend"
run_setup "laravel-fullstack-harness" "$laravel_fullstack_project" "$laravel_fullstack_home"

test -f "${laravel_fullstack_project}/.gitignore" || fail "laravel-fullstack-harness should create .gitignore"
assert_line_exists "${laravel_fullstack_project}/.gitignore" ".harness/error-journal.md"
assert_line_exists "${laravel_fullstack_project}/.gitignore" ".idea/"
assert_line_exists "${laravel_fullstack_project}/.gitignore" ".DS_Store"
assert_line_exists "${laravel_fullstack_project}/.gitignore" "findings.md"
assert_line_exists "${laravel_fullstack_project}/.gitignore" "progress.md"
assert_line_exists "${laravel_fullstack_project}/.gitignore" "task_plan.md"
assert_file_exists "${laravel_fullstack_project}/.harness/guides/frontend-api.md"
assert_file_exists "${laravel_fullstack_project}/.harness/guides/frontend-architecture.md"
assert_file_exists "${laravel_fullstack_project}/.harness/guides/frontend-coding.md"
assert_file_exists "${laravel_fullstack_project}/.harness/scripts/read-error-journal.sh"
assert_file_exists "${laravel_fullstack_project}/.harness/scripts/append-error-journal.sh"

printf 'Laravel package smoke test passed\n'
