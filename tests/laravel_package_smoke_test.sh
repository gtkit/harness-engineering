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

assert_file_not_contains() {
    local file="$1"
    local pattern="$2"

    if grep -Fq "$pattern" "$file"; then
        fail "expected ${file} to not contain: ${pattern}"
    fi
}

# .gitignore 只放通用构建 / 编辑器 / OS 产物；本地工具与 Agent 运行产物走 .git/info/exclude
assert_gitignore_baseline() {
    local file="$1"
    local line
    local pattern

    test -f "$file" || fail "expected .gitignore at ${file}"
    # laravel / laravel-fullstack 都是应用型 harness，.env 必须在 .gitignore 里
    for line in \
        ".idea/" \
        ".vscode/" \
        ".Ds_Store" \
        ".DS_Store" \
        "*.log" \
        "*.out" \
        ".env"; do
        assert_line_exists "$file" "$line"
    done
    for pattern in \
        "# Harness: 本地工具与 Agent 运行产物" \
        ".openspec-auto-backup/" \
        ".openspec-auto/" \
        ".harness/" \
        ".claude/" \
        ".codex/" \
        ".agents/" \
        "openspec/" \
        "AGENTS.md" \
        "CLAUDE.md" \
        "tools/" \
        ".learnings/" \
        "findings.md" \
        "progress.md" \
        "task_plan.md"; do
        assert_file_not_contains "$file" "$pattern"
    done
}

assert_exclude_baseline() {
    local file="$1"
    local line

    test -f "$file" || fail "expected .git/info/exclude at ${file}"
    for line in \
        "# 本地工具与运行产物（仅本地忽略，不进版本库）" \
        ".openspec-auto-backup/" \
        ".openspec-auto/" \
        ".harness/" \
        ".claude/" \
        ".codex/" \
        ".agents/" \
        "openspec/" \
        "AGENTS.md" \
        "CLAUDE.md" \
        "tools/" \
        ".learnings/" \
        "findings.md" \
        "progress.md" \
        "task_plan.md"; do
        assert_line_exists "$file" "$line"
    done
}

run_setup() {
    local harness_dir="$1"
    local project_dir="$2"
    local sandbox_home="$3"

    # setup 会把本地工具规则写进 .git/info/exclude，夹具需先是 git 仓库
    git init -q "$project_dir" >/dev/null 2>&1 || true

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

# setup.sh 现已收敛为薄包装，安装逻辑与 .gitignore 基线在共享库
install_lib="${ROOT_DIR}/scripts/install-harness.sh"
assert_file_contains "${laravel_pkg}/setup.sh" "install_harness"
assert_file_contains "${install_lib}" "HARNESS_FORCE_GUIDES"
assert_file_contains "${install_lib}" ".harness/"
assert_file_contains "${install_lib}" ".idea/"
assert_file_contains "${install_lib}" ".DS_Store"
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
assert_file_contains "${readme_file}" "/harness:doctor"
assert_file_contains "${readme_file}" "### Codex 怎么用"
assert_file_contains "${readme_file}" "harness research: 你的需求描述"
assert_file_contains "${readme_file}" "docs/harness-command-workflow.md"
assert_file_contains "${readme_file}" "commands/harness"
assert_file_contains "${ci_file}" "bash tests/laravel_package_smoke_test.sh"

tmpdir="$(mktemp -d /tmp/laravel-harness-smoke-XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

laravel_home="${tmpdir}/laravel-home"
laravel_project="${tmpdir}/laravel-project"
mkdir -p "$laravel_home" "$laravel_project"
run_setup "laravel-harness" "$laravel_project" "$laravel_home"

assert_gitignore_baseline "${laravel_project}/.gitignore"
assert_exclude_baseline "${laravel_project}/.git/info/exclude"
assert_file_exists "${laravel_project}/CLAUDE.md"
assert_file_exists "${laravel_project}/AGENTS.md"
assert_file_exists "${laravel_project}/.harness/guides/laravel-modules.md"
assert_file_exists "${laravel_project}/.harness/scripts/read-error-journal.sh"
assert_file_exists "${laravel_project}/.harness/scripts/append-error-journal.sh"
assert_file_exists "${laravel_project}/.claude/commands/harness/doctor.md"
assert_file_contains "${laravel_project}/.claude/commands/harness/doctor.md" "Harness Doctor"

printf 'LOCAL LARAVEL GUIDE\n' > "${laravel_project}/.harness/guides/http-and-api.md"
run_setup "laravel-harness" "$laravel_project" "$laravel_home"
assert_file_contains "${laravel_project}/.harness/guides/http-and-api.md" "LOCAL LARAVEL GUIDE"
assert_file_contains "${laravel_project}/.claude/commands/harness/doctor.md" "Harness Doctor"

laravel_fullstack_home="${tmpdir}/laravel-fullstack-home"
laravel_fullstack_project="${tmpdir}/laravel-fullstack-project"
mkdir -p "$laravel_fullstack_home" "$laravel_fullstack_project/backend" "$laravel_fullstack_project/frontend"
run_setup "laravel-fullstack-harness" "$laravel_fullstack_project" "$laravel_fullstack_home"

assert_gitignore_baseline "${laravel_fullstack_project}/.gitignore"
assert_exclude_baseline "${laravel_fullstack_project}/.git/info/exclude"
assert_file_exists "${laravel_fullstack_project}/.harness/guides/frontend-api.md"
assert_file_exists "${laravel_fullstack_project}/.harness/guides/frontend-architecture.md"
assert_file_exists "${laravel_fullstack_project}/.harness/guides/frontend-coding.md"
assert_file_exists "${laravel_fullstack_project}/.harness/scripts/read-error-journal.sh"
assert_file_exists "${laravel_fullstack_project}/.harness/scripts/append-error-journal.sh"
assert_file_exists "${laravel_fullstack_project}/.claude/commands/harness/doctor.md"
assert_file_contains "${laravel_fullstack_project}/.claude/commands/harness/doctor.md" "Harness Doctor"

printf 'Laravel package smoke test passed\n'
