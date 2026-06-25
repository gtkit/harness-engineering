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

assert_global_claude_skill() {
    local file="$1"

    assert_file_contains "$file" "CLAUDE.md"
    assert_file_contains "$file" ".harness/guides/"
    assert_file_contains "$file" "AGENTS.md"
    assert_file_not_contains "$file" "## 第零章"
    assert_file_not_contains "$file" "## 行为纪律"
}

assert_global_codex_skill() {
    local file="$1"

    assert_file_contains "$file" "AGENTS.md"
    assert_file_contains "$file" ".harness/guides/"
    assert_file_not_contains "$file" "CLAUDE.md"
    assert_file_not_contains "$file" "## 第零章"
    assert_file_not_contains "$file" "## 行为纪律"
}

assert_error_journal_runtime() {
    local project_dir="$1"
    local output

    test -f "${project_dir}/.harness/scripts/read-error-journal.sh" || fail "missing read-error-journal.sh in ${project_dir}"
    test -f "${project_dir}/.harness/scripts/append-error-journal.sh" || fail "missing append-error-journal.sh in ${project_dir}"
    test -f "${project_dir}/.harness/scripts/read-error-journal.ps1" || fail "missing read-error-journal.ps1 in ${project_dir}"
    test -f "${project_dir}/.harness/scripts/append-error-journal.ps1" || fail "missing append-error-journal.ps1 in ${project_dir}"

    output="$(bash "${project_dir}/.harness/scripts/read-error-journal.sh" "${project_dir}")"
    printf '%s' "$output" | grep -Fq "Error Journal" || fail "expected read-error-journal output for ${project_dir}"

    bash "${project_dir}/.harness/scripts/append-error-journal.sh" "${project_dir}" user-correction harness "smoke test summary" >/dev/null
    assert_file_contains "${project_dir}/.harness/error-journal.md" "smoke test summary"
    assert_file_contains "${project_dir}/.harness/error-journal.md" "## [ERR-"
}

assert_gitignore_baseline() {
    local file="$1"

    for line in \
        ".openspec-auto-backup/" \
        ".openspec-auto/" \
        ".idea/" \
        ".vscode/" \
        ".Ds_Store" \
        ".DS_Store" \
        "*.log" \
        "findings.md" \
        "progress.md" \
        "task_plan.md" \
        "# Harness: 本地工具与 Agent 运行产物" \
        ".harness/" \
        ".claude/" \
        ".codex/" \
        ".agents/" \
        "openspec/" \
        "AGENTS.md" \
        "CLAUDE.md" \
        "tools/"; do
        assert_line_exists "$file" "$line"
    done
    # 整目录忽略后，旧的细粒度规则不应再单独出现
    assert_file_not_contains "$file" ".harness/error-journal.md"
    assert_file_not_contains "$file" ".harness/VERSION"
}

assert_version_file() {
    local project_dir="$1"
    local harness_name="$2"
    local file="${project_dir}/.harness/VERSION"

    test -f "$file" || fail "missing .harness/VERSION in ${project_dir}"
    assert_file_contains "$file" "harness: ${harness_name}"
    assert_file_contains "$file" "source-commit:"
    assert_file_contains "$file" "installed-at:"
    assert_file_contains "$file" "installer: setup.sh"
}

assert_harness_commands() {
    local project_dir="$1"
    local commands_dir="${project_dir}/.claude/commands/harness"

    for file in \
        doctor.md \
        init-openspec.md \
        research.md \
        plan.md \
        implement.md \
        review.md; do
        test -f "${commands_dir}/${file}" || fail "missing harness command ${file} in ${project_dir}"
    done

    assert_file_contains "${commands_dir}/doctor.md" "Harness Doctor"
    assert_file_contains "${commands_dir}/research.md" "constraint set"
    assert_file_contains "${commands_dir}/plan.md" "zero-decision"
    assert_file_contains "${commands_dir}/implement.md" "approved plan"
    assert_file_contains "${commands_dir}/review.md" "质量"
}

assert_guide_file_exists() {
    local project_dir="$1"
    local file="$2"

    test -f "${project_dir}/.harness/guides/${file}" || fail "missing guide ${file} in ${project_dir}"
}

assert_generated_docs_do_not_require_cleanup() {
    local project_dir="$1"

    assert_file_not_contains "${project_dir}/AGENTS.md" "清理杂物"
    assert_file_not_contains "${project_dir}/AGENTS.md" "必须删除并保持工作区干净"
    assert_file_not_contains "${project_dir}/CLAUDE.md" "清理杂物"
    assert_file_not_contains "${project_dir}/CLAUDE.md" "必须删除"
}

assert_all_guides_are_referenced() {
    local harness_dir="$1"
    local agents_file="${ROOT_DIR}/${harness_dir}/AGENTS.md"
    local guide
    local guide_name

    for guide in "${ROOT_DIR}/${harness_dir}/guides/"*.md; do
        guide_name="$(basename "$guide")"
        [ "$guide_name" = "error-journal-template.md" ] && continue
        assert_file_contains "$agents_file" "$guide_name"
    done
}

assert_installed_guides_match_source() {
    local harness_dir="$1"
    local project_dir="$2"
    local guide
    local guide_name

    for guide in "${ROOT_DIR}/${harness_dir}/guides/"*.md; do
        guide_name="$(basename "$guide")"
        [ "$guide_name" = "error-journal-template.md" ] && continue
        assert_guide_file_exists "$project_dir" "$guide_name"
        assert_file_contains "${project_dir}/AGENTS.md" "$guide_name"
    done
}

assert_go_pkg_project_files() {
    local project_dir="$1"
    local package_name
    package_name="$(basename "$project_dir")"

    test -f "${project_dir}/Makefile" || fail "go-pkg-harness should generate Makefile"
    test -f "${project_dir}/version.go" || fail "go-pkg-harness should generate version.go"
    assert_file_contains "${project_dir}/Makefile" "golangci-lint run"
    assert_file_contains "${project_dir}/Makefile" "govulncheck ./..."
    assert_file_contains "${project_dir}/Makefile" "git tag -a"
    assert_file_contains "${project_dir}/Makefile" "delcommit:"
    assert_file_contains "${project_dir}/Makefile" "git reset --soft HEAD~1"
    assert_file_contains "${project_dir}/version.go" "package ${package_name}"
    assert_file_contains "${project_dir}/version.go" 'const Version = "v0.1.0"'
}

run_setup() {
    local harness_dir="$1"
    local project_dir="$2"
    local sandbox_home="$3"
    local force_project_files="${4:-0}"

    (
        cd "$project_dir"
        HOME="$sandbox_home" CODEX_HOME="$sandbox_home/.codex" HARNESS_FORCE_PROJECT_FILES="$force_project_files" \
            bash "${ROOT_DIR}/${harness_dir}/setup.sh" >/dev/null
    )
}

workflow_file="${ROOT_DIR}/.github/workflows/ci.yml"
test -f "${workflow_file}" || fail "expected GitHub Actions workflow at ${workflow_file}"
assert_file_contains "${workflow_file}" "name: CI"
assert_file_contains "${workflow_file}" "push:"
assert_file_contains "${workflow_file}" "pull_request:"
assert_file_contains "${workflow_file}" "branches: [main]"
assert_file_contains "${workflow_file}" "runs-on: ubuntu-latest"
assert_file_contains "${workflow_file}" "uses: actions/checkout@v4"
assert_file_contains "${workflow_file}" "bash -n go-harness/setup.sh fullstack-harness/setup.sh go-pkg-harness/setup.sh laravel-harness/setup.sh laravel-fullstack-harness/setup.sh"
assert_file_contains "${workflow_file}" "bash scripts/sync-claude-from-agents.sh --check"
assert_file_contains "${workflow_file}" "bash tests/setup_smoke_test.sh"

for harness_dir in go-harness fullstack-harness go-pkg-harness laravel-harness laravel-fullstack-harness; do
    assert_all_guides_are_referenced "${harness_dir}"
done

tmpdir="$(mktemp -d /tmp/harness-smoke-XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

go_home="${tmpdir}/go-home"
go_project="${tmpdir}/go-project"
mkdir -p "$go_home" "$go_project"
run_setup "go-harness" "$go_project" "$go_home"

test -f "${go_project}/.gitignore" || fail "go-harness should create .gitignore when missing"
assert_gitignore_baseline "${go_project}/.gitignore"
assert_generated_docs_do_not_require_cleanup "${go_project}"
assert_global_claude_skill "${go_home}/.claude/skills/go-harness/SKILL.md"
assert_global_codex_skill "${go_home}/.codex/skills/go-harness/SKILL.md"
assert_error_journal_runtime "${go_project}"
assert_version_file "${go_project}" "go-harness"
assert_harness_commands "${go_project}"
assert_installed_guides_match_source "go-harness" "${go_project}"

    printf 'LOCAL CHANGE\n' > "${go_project}/.harness/guides/architecture.md"
    run_setup "go-harness" "$go_project" "$go_home"
    assert_file_contains "${go_project}/.harness/guides/architecture.md" "LOCAL CHANGE"

    printf 'LOCAL SCRIPT\n' > "${go_project}/.harness/scripts/read-error-journal.sh"
    run_setup "go-harness" "$go_project" "$go_home"
    assert_file_contains "${go_project}/.harness/scripts/read-error-journal.sh" "LOCAL SCRIPT"

    printf 'LOCAL COMMAND\n' > "${go_project}/.claude/commands/harness/doctor.md"
    run_setup "go-harness" "$go_project" "$go_home"
    assert_file_contains "${go_project}/.claude/commands/harness/doctor.md" "LOCAL COMMAND"

    printf 'LOCAL CLAUDE\n' > "${go_project}/CLAUDE.md"
    printf 'LOCAL AGENTS\n' > "${go_project}/AGENTS.md"
    run_setup "go-harness" "$go_project" "$go_home" "1"
    assert_file_not_contains "${go_project}/CLAUDE.md" "LOCAL CLAUDE"
    assert_file_not_contains "${go_project}/AGENTS.md" "LOCAL AGENTS"
    assert_file_not_contains "${go_project}/.claude/commands/harness/doctor.md" "LOCAL COMMAND"
    assert_file_contains "${go_project}/.claude/commands/harness/doctor.md" "Harness Doctor"
    assert_file_contains "${go_project}/CLAUDE.md" "## 分层架构（不可逾越）"
    assert_file_contains "${go_project}/AGENTS.md" "## 分层架构（不可逾越）"
    assert_file_not_contains "${go_project}/.harness/scripts/read-error-journal.sh" "LOCAL SCRIPT"
    assert_file_contains "${go_project}/.harness/scripts/read-error-journal.sh" "sed -n '1,240p'"

for harness_dir in fullstack-harness go-pkg-harness laravel-harness laravel-fullstack-harness; do
    if [ "${harness_dir}" = "go-pkg-harness" ]; then
        project_dir="${tmpdir}/pkgdemo"
    else
        project_dir="${tmpdir}/${harness_dir}-project"
    fi
    home_dir="${tmpdir}/${harness_dir}-home"
    mkdir -p "$project_dir" "$home_dir"
    run_setup "${harness_dir}" "${project_dir}" "${home_dir}"
    test -f "${project_dir}/.gitignore" || fail "${harness_dir} should create .gitignore when missing"
    assert_gitignore_baseline "${project_dir}/.gitignore"
    assert_generated_docs_do_not_require_cleanup "${project_dir}"
    assert_global_claude_skill "${home_dir}/.claude/skills/${harness_dir}/SKILL.md"
    assert_global_codex_skill "${home_dir}/.codex/skills/${harness_dir}/SKILL.md"
    assert_file_contains "${project_dir}/AGENTS.md" "Codex 命令化工作流兼容入口"
    assert_file_contains "${project_dir}/AGENTS.md" "harness research: <需求>"
    assert_installed_guides_match_source "${harness_dir}" "${project_dir}"
    test -f "${project_dir}/.harness/scripts/read-error-journal.sh" || fail "${harness_dir} should install read-error-journal.sh"
    test -f "${project_dir}/.harness/scripts/append-error-journal.sh" || fail "${harness_dir} should install append-error-journal.sh"
    assert_version_file "${project_dir}" "${harness_dir}"
    assert_harness_commands "${project_dir}"
    if [ "${harness_dir}" = "go-pkg-harness" ]; then
        assert_go_pkg_project_files "${project_dir}"
    fi
done

empty_pkg_project="${tmpdir}/emptypkg"
empty_pkg_home="${tmpdir}/emptypkg-home"
mkdir -p "$empty_pkg_project" "$empty_pkg_home"
: > "${empty_pkg_project}/Makefile"
: > "${empty_pkg_project}/version.go"
run_setup "go-pkg-harness" "$empty_pkg_project" "$empty_pkg_home"
assert_go_pkg_project_files "$empty_pkg_project"

assert_file_contains "${ROOT_DIR}/go-pkg-harness/AGENTS.md" "github.com/gtkit/json"
assert_file_contains "${ROOT_DIR}/go-pkg-harness/AGENTS.md" "纯零依赖公共库允许使用 \`encoding/json\`"
assert_file_contains "${ROOT_DIR}/go-pkg-harness/AGENTS.md" ".harness/guides/pkg-release-and-supply-chain.md"
assert_file_contains "${ROOT_DIR}/go-pkg-harness/SKILL.codex.md" "AGENTS.md"
assert_file_contains "${ROOT_DIR}/go-harness/AGENTS.md" ".harness/guides/testing-and-validation.md"
assert_file_contains "${ROOT_DIR}/go-harness/AGENTS.md" ".harness/guides/workers-and-scheduling.md"
assert_file_contains "${ROOT_DIR}/go-harness/CLAUDE.md" ".harness/guides/testing-and-validation.md"
assert_file_contains "${ROOT_DIR}/go-harness/CLAUDE.md" ".harness/guides/workers-and-scheduling.md"

assert_file_contains "${ROOT_DIR}/fullstack-harness/AGENTS.md" "backend/"
assert_file_contains "${ROOT_DIR}/fullstack-harness/AGENTS.md" "frontend/"
assert_file_contains "${ROOT_DIR}/fullstack-harness/AGENTS.md" ".harness/guides/testing-and-validation.md"
assert_file_contains "${ROOT_DIR}/fullstack-harness/AGENTS.md" ".harness/guides/workers-and-scheduling.md"
assert_file_not_contains "${ROOT_DIR}/fullstack-harness/AGENTS.md" "web/src/api/types.ts"
assert_file_contains "${ROOT_DIR}/go-harness/SKILL.md" "CLAUDE.md"
assert_file_contains "${ROOT_DIR}/go-harness/SKILL.md" "AGENTS.md"
assert_file_not_contains "${ROOT_DIR}/go-harness/SKILL.codex.md" "CLAUDE.md"
assert_file_contains "${ROOT_DIR}/README.md" "### Claude Code 怎么用"
assert_file_contains "${ROOT_DIR}/README.md" "### Codex 怎么用"
assert_file_contains "${ROOT_DIR}/README.md" "harness research: 你的需求描述"
assert_file_contains "${ROOT_DIR}/README.md" "docs/harness-command-workflow.md"
assert_file_contains "${ROOT_DIR}/docs/harness-command-workflow.md" "## 命令对照"
assert_file_contains "${ROOT_DIR}/docs/harness-command-workflow.md" "doctor -> research -> plan -> implement -> review"

printf 'setup smoke test passed\n'
