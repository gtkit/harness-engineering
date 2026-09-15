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

assert_line_not_exists() {
    local file="$1"
    local line="$2"

    if grep -Fxq "$line" "$file"; then
        fail "expected ${file} to not contain line: ${line}"
    fi
}

# 全局 harness skill 已不再安装；setup 还要把旧版本装过的清掉
assert_no_global_skill() {
    local home_dir="$1"
    local module="$2"
    test ! -e "${home_dir}/.claude/skills/${module}" || fail "legacy global skill must be removed: ${home_dir}/.claude/skills/${module}"
    test ! -e "${home_dir}/.agents/skills/${module}" || fail "legacy global skill must be removed: ${home_dir}/.agents/skills/${module}"
    test ! -e "${home_dir}/.codex/skills/${module}" || fail "legacy global skill must be removed: ${home_dir}/.codex/skills/${module}"
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

# assert_gitignore_baseline <gitignore_file> <module_name>
assert_gitignore_baseline() {
    local file="$1"
    local module_name="${2:-}"

    test -n "${module_name}" || fail "assert_gitignore_baseline needs a module name"

    # .gitignore 只保留通用构建 / 编辑器 / OS 产物
    for line in \
        ".idea/" \
        ".vscode/" \
        ".Ds_Store" \
        ".DS_Store" \
        "*.log" \
        "*.out"; do
        assert_line_exists "$file" "$line"
    done
    # go-pkg-harness 是纯扩展包，不产生 .env 运行配置；其余 harness 一律忽略 .env
    if [ "${module_name}" = "go-pkg-harness" ]; then
        assert_line_not_exists "$file" ".env"
    else
        assert_line_exists "$file" ".env"
    fi
    # 本地工具与运行产物、旧 Harness 标题绝不能出现在 .gitignore（应在 .git/info/exclude）
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

    test -f "$file" || fail "expected .git/info/exclude at ${file}"
    # 旧版本写过的 tools/ 与 tools/openspec/ 必须已剔除
    assert_line_not_exists "$file" "tools/"
    assert_line_not_exists "$file" "tools/openspec/"
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
        ".learnings/" \
        "findings.md" \
        "progress.md" \
        "task_plan.md"; do
        assert_line_exists "$file" "$line"
    done
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

assert_harness_skills() {
    local project_dir="$1"
    local skills_root

    for skills_root in "${project_dir}/.claude/skills" "${project_dir}/.agents/skills"; do
        for name in doctor init-openspec research plan implement review; do
            test -f "${skills_root}/harness-${name}/SKILL.md" || fail "missing skill harness-${name} in ${skills_root}"
            assert_line_exists "${skills_root}/harness-${name}/SKILL.md" "name: harness-${name}"
        done
        assert_file_contains "${skills_root}/harness-doctor/SKILL.md" "Harness Doctor"
        assert_file_contains "${skills_root}/harness-research/SKILL.md" "constraint set"
        assert_file_contains "${skills_root}/harness-plan/SKILL.md" "zero-decision"
        assert_file_contains "${skills_root}/harness-implement/SKILL.md" "approved plan"
        assert_file_contains "${skills_root}/harness-review/SKILL.md" "质量"
    done
    test ! -e "${project_dir}/.claude/commands/harness" || fail "legacy .claude/commands/harness must be removed in ${project_dir}"
    local rule_file
    rule_file="$(find "${project_dir}/.claude/rules" -maxdepth 1 -name 'harness-*.md' 2>/dev/null | head -n1)"
    test -n "${rule_file}" || fail "missing .claude/rules/harness-*.md in ${project_dir}"
    assert_file_contains "${rule_file}" "paths:"
    assert_file_contains "${rule_file}" ".harness/guides/"
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
        [ -f "$guide" ] || continue
        guide_name="$(basename "$guide")"
        [ "$guide_name" = "error-journal-template.md" ] && continue
        assert_file_contains "$agents_file" "$guide_name"
    done
    # shared-guides.txt 拉进来的公共 guide 同样必须被入口文件引用
    if [ -f "${ROOT_DIR}/${harness_dir}/shared-guides.txt" ]; then
        while IFS= read -r guide || [ -n "$guide" ]; do
            guide="${guide%%#*}"
            guide="$(printf '%s' "$guide" | tr -d '[:space:]')"
            [ -n "$guide" ] || continue
            test -f "${ROOT_DIR}/shared/guides/${guide}" || fail "shared guide missing: ${guide} (referenced by ${harness_dir})"
            guide_name="$(basename "$guide")"
            [ "$guide_name" = "error-journal-template.md" ] && continue
            assert_file_contains "$agents_file" "$guide_name"
        done < "${ROOT_DIR}/${harness_dir}/shared-guides.txt"
    fi
}

# 入口规则文件必须真的在版本库里。go-grpc-harness 的 AGENTS.md / CLAUDE.md 曾被
# .git/info/exclude 的无斜杠 "AGENTS.md" / "CLAUDE.md" 规则挡在库外（该规则匹配任意层级），
# clone 后 setup.sh 找不到 CLAUDE.md 直接报错退出。
assert_entry_files_tracked() {
    local harness_dir="$1"
    local file

    git -C "${ROOT_DIR}" rev-parse --git-dir >/dev/null 2>&1 || return 0

    for file in AGENTS.md CLAUDE.md; do
        git -C "${ROOT_DIR}" ls-files --error-unmatch "${harness_dir}/${file}" >/dev/null 2>&1 \
            || fail "${harness_dir}/${file} 不在版本库中：clone 后 setup 会因找不到该文件而失败"
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
    local expected_package="${2:-}"
    local package_name
    local detected_version
    local tag_body
    local fmt_write_count

    if [ -n "${expected_package}" ]; then
        package_name="${expected_package}"
    else
        package_name="$(basename "$project_dir")"
        package_name="${package_name//-/}"
    fi

    test -f "${project_dir}/Makefile" || fail "go-pkg-harness should generate Makefile"
    test -f "${project_dir}/version.go" || fail "go-pkg-harness should generate version.go"
    assert_file_contains "${project_dir}/Makefile" "golangci-lint run"
    assert_file_contains "${project_dir}/Makefile" "govulncheck ./..."
    assert_file_contains "${project_dir}/Makefile" "git tag -a"
    assert_file_contains "${project_dir}/Makefile" "delcommit:"
    assert_file_contains "${project_dir}/Makefile" "git reset --soft HEAD~1"

    # 发版入口与可覆盖的门禁配置
    assert_file_contains "${project_dir}/Makefile" "release-patch:"
    assert_file_contains "${project_dir}/Makefile" "release-minor:"
    assert_file_contains "${project_dir}/Makefile" "push-tag:"
    assert_file_contains "${project_dir}/Makefile" "fmt:"
    assert_file_contains "${project_dir}/Makefile" "BUMP              ?= patch"
    assert_file_contains "${project_dir}/Makefile" "COVERAGE_MIN      ?= 80"
    assert_file_contains "${project_dir}/Makefile" "REQUIRE_CHANGELOG ?= 1"
    assert_file_contains "${project_dir}/Makefile" "工作区不干净"
    assert_file_contains "${project_dir}/Makefile" "go mod tidy -diff"
    # MAJOR 只 bump tag 不改 module path 是错误发布，脚本必须拒绝
    assert_file_contains "${project_dir}/Makefile" "本脚本不处理 MAJOR"

    # 两步发布的核心不变量：tag 目标推 main，标签留给 push-tag 推
    tag_body="$(awk '/^tag:/ {f=1; next} f && /^[a-zA-Z]/ {exit} f' "${project_dir}/Makefile")"
    printf '%s' "${tag_body}" | grep -Fq 'git push $(RELEASE_REMOTE) HEAD' \
        || fail "tag target should push main to \$(RELEASE_REMOTE)"
    if printf '%s' "${tag_body}" | grep -Fq 'git push $(RELEASE_REMOTE) "$$new"'; then
        fail "tag target must not push the tag itself; that is push-tag's job"
    fi
    assert_file_contains "${project_dir}/Makefile" 'git push $(RELEASE_REMOTE) "$$tag"'

    # tool 是只读检查，唯一允许写文件的格式化入口是 fmt
    fmt_write_count="$(grep -c -- 'gofumpt -l -w' "${project_dir}/Makefile")"
    if [ "${fmt_write_count}" != "1" ]; then
        fail "expected exactly one 'gofumpt -l -w' (fmt target only), got ${fmt_write_count}"
    fi

    assert_line_exists "${project_dir}/version.go" "package ${package_name}"
    assert_line_exists "${project_dir}/version.go" 'const Version = "v0.1.0"'
    assert_file_contains "${project_dir}/version.go" "// Version 是本包的当前版本号"
    assert_file_contains "${project_dir}/version.go" "make release-patch / make release-minor"

    # 发版脚本取文件里第一个匹配到的版本号，注释不得抢在 const 行前面
    detected_version="$(grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' "${project_dir}/version.go" | head -n1)"
    if [ "${detected_version}" != "v0.1.0" ]; then
        fail "release script would read '${detected_version}' from ${project_dir}/version.go"
    fi
}

run_setup() {
    local harness_dir="$1"
    local project_dir="$2"
    local sandbox_home="$3"
    local force_project_files="${4:-0}"

    # setup 会把本地工具规则写进 .git/info/exclude，夹具需先是 git 仓库
    git init -q "$project_dir" >/dev/null 2>&1 || true

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
assert_file_contains "${workflow_file}" "bash -n go-harness/setup.sh go-grpc-harness/setup.sh fullstack-harness/setup.sh go-pkg-harness/setup.sh laravel-harness/setup.sh laravel-fullstack-harness/setup.sh"
assert_file_contains "${workflow_file}" "bash scripts/sync-claude-from-agents.sh --check"
assert_file_contains "${workflow_file}" "bash tests/setup_smoke_test.sh"

for harness_dir in go-harness go-grpc-harness fullstack-harness go-pkg-harness laravel-harness laravel-fullstack-harness; do
    assert_all_guides_are_referenced "${harness_dir}"
    assert_entry_files_tracked "${harness_dir}"
done

tmpdir="$(mktemp -d /tmp/harness-smoke-XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

go_home="${tmpdir}/go-home"
go_project="${tmpdir}/go-project"
mkdir -p "$go_home" "$go_project" "${go_home}/.claude/skills/go-harness" "${go_home}/.codex/skills/go-harness"
printf 'legacy\n' > "${go_home}/.claude/skills/go-harness/SKILL.md"
printf 'legacy\n' > "${go_home}/.codex/skills/go-harness/SKILL.md"
run_setup "go-harness" "$go_project" "$go_home"

test -f "${go_project}/.gitignore" || fail "go-harness should create .gitignore when missing"
assert_gitignore_baseline "${go_project}/.gitignore" "go-harness"
assert_exclude_baseline "${go_project}/.git/info/exclude"
assert_generated_docs_do_not_require_cleanup "${go_project}"
assert_no_global_skill "${go_home}" go-harness
assert_error_journal_runtime "${go_project}"
assert_version_file "${go_project}" "go-harness"
assert_harness_skills "${go_project}"
assert_installed_guides_match_source "go-harness" "${go_project}"

    printf 'LOCAL CHANGE\n' > "${go_project}/.harness/guides/architecture.md"
    run_setup "go-harness" "$go_project" "$go_home"
    assert_file_contains "${go_project}/.harness/guides/architecture.md" "LOCAL CHANGE"

    printf 'LOCAL SCRIPT\n' > "${go_project}/.harness/scripts/read-error-journal.sh"
    run_setup "go-harness" "$go_project" "$go_home"
    assert_file_contains "${go_project}/.harness/scripts/read-error-journal.sh" "LOCAL SCRIPT"

    printf 'LOCAL COMMAND\n' > "${go_project}/.claude/skills/harness-doctor/SKILL.md"
    run_setup "go-harness" "$go_project" "$go_home"
    assert_file_contains "${go_project}/.claude/skills/harness-doctor/SKILL.md" "LOCAL COMMAND"

    printf 'LOCAL CLAUDE\n' > "${go_project}/CLAUDE.md"
    printf 'LOCAL AGENTS\n' > "${go_project}/AGENTS.md"
    run_setup "go-harness" "$go_project" "$go_home" "1"
    assert_file_not_contains "${go_project}/CLAUDE.md" "LOCAL CLAUDE"
    assert_file_not_contains "${go_project}/AGENTS.md" "LOCAL AGENTS"
    assert_file_not_contains "${go_project}/.claude/skills/harness-doctor/SKILL.md" "LOCAL COMMAND"
    assert_file_contains "${go_project}/.claude/skills/harness-doctor/SKILL.md" "Harness Doctor"
    assert_file_contains "${go_project}/CLAUDE.md" "## 分层架构（不可逾越）"
    assert_file_contains "${go_project}/AGENTS.md" "## 分层架构（不可逾越）"
    assert_file_not_contains "${go_project}/.harness/scripts/read-error-journal.sh" "LOCAL SCRIPT"
    assert_file_contains "${go_project}/.harness/scripts/read-error-journal.sh" "sed -n '1,240p'"

# --- 迁移：旧版本把本地工具规则误写进 .gitignore，重跑 setup 应清理并迁移到 .git/info/exclude ---
migrate_project="${tmpdir}/migrate-project"
migrate_home="${tmpdir}/migrate-home"
mkdir -p "$migrate_project" "$migrate_home"
git init -q "$migrate_project"
cat > "${migrate_project}/.gitignore" <<'LEGACY'
# 业务自定义
/build/

# Harness: 本地工具与 Agent 运行产物
.idea/
.DS_Store
*.log
.harness/
.claude/
.codex/
.agents/
openspec/
CLAUDE.md
AGENTS.md
tools/
.learnings/
findings.md
progress.md
task_plan.md
.openspec-auto/
.openspec-auto-backup/
LEGACY
run_setup "go-harness" "$migrate_project" "$migrate_home"
# 业务自定义规则必须原样保留
assert_line_exists "${migrate_project}/.gitignore" "/build/"
# 通用产物保留在 .gitignore，本地工具规则被迁移走
assert_gitignore_baseline "${migrate_project}/.gitignore" "go-harness"
assert_exclude_baseline "${migrate_project}/.git/info/exclude"

for harness_dir in go-grpc-harness fullstack-harness go-pkg-harness laravel-harness laravel-fullstack-harness; do
    if [ "${harness_dir}" = "go-pkg-harness" ]; then
        project_dir="${tmpdir}/pkgdemo"
    else
        project_dir="${tmpdir}/${harness_dir}-project"
    fi
    home_dir="${tmpdir}/${harness_dir}-home"
    mkdir -p "$project_dir" "$home_dir"
    run_setup "${harness_dir}" "${project_dir}" "${home_dir}"
    test -f "${project_dir}/.gitignore" || fail "${harness_dir} should create .gitignore when missing"
    assert_gitignore_baseline "${project_dir}/.gitignore" "${harness_dir}"
    assert_exclude_baseline "${project_dir}/.git/info/exclude"
    assert_generated_docs_do_not_require_cleanup "${project_dir}"
    assert_no_global_skill "${home_dir}" "${harness_dir}"
    assert_file_contains "${project_dir}/AGENTS.md" "工作流 skills（Claude Code 与 Codex 同一套）"
    assert_file_contains "${project_dir}/AGENTS.md" '$harness-research'
    assert_installed_guides_match_source "${harness_dir}" "${project_dir}"
    test -f "${project_dir}/.harness/scripts/read-error-journal.sh" || fail "${harness_dir} should install read-error-journal.sh"
    test -f "${project_dir}/.harness/scripts/append-error-journal.sh" || fail "${harness_dir} should install append-error-journal.sh"
    assert_version_file "${project_dir}" "${harness_dir}"
    assert_harness_skills "${project_dir}"
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

# 空目录 + 目录名带横线：package 名按目录名推导，横线直接去掉
dashed_pkg_project="${tmpdir}/lenovo-pay"
dashed_pkg_home="${tmpdir}/lenovo-pay-home"
mkdir -p "$dashed_pkg_project" "$dashed_pkg_home"
run_setup "go-pkg-harness" "$dashed_pkg_project" "$dashed_pkg_home"
assert_go_pkg_project_files "$dashed_pkg_project"
assert_line_exists "${dashed_pkg_project}/version.go" "package lenovopay"

# 目录内已有 .go 文件：沿用既有 package 名，不按目录名另起一个（否则同目录 package 冲突）
existing_pkg_project="${tmpdir}/go-pay"
existing_pkg_home="${tmpdir}/go-pay-home"
mkdir -p "$existing_pkg_project" "$existing_pkg_home"
printf 'package gopay\n\nfunc Noop() {}\n' > "${existing_pkg_project}/pay.go"
printf 'package gopay_test\n' > "${existing_pkg_project}/pay_test.go"
run_setup "go-pkg-harness" "$existing_pkg_project" "$existing_pkg_home"
assert_go_pkg_project_files "$existing_pkg_project" "gopay"
assert_line_exists "${existing_pkg_project}/version.go" "package gopay"

# 既有 package 名优先于旧 version.go 里的错误值，HARNESS_FORCE_PROJECT_FILES=1 能纠正
printf 'package go_pay\n' > "${existing_pkg_project}/version.go"
run_setup "go-pkg-harness" "$existing_pkg_project" "$existing_pkg_home" "1"
assert_go_pkg_project_files "$existing_pkg_project" "gopay"

assert_file_contains "${ROOT_DIR}/go-pkg-harness/AGENTS.md" "github.com/gtkit/json"
assert_file_contains "${ROOT_DIR}/go-pkg-harness/AGENTS.md" "纯零依赖公共库允许使用 \`encoding/json\`"
assert_file_contains "${ROOT_DIR}/go-pkg-harness/AGENTS.md" ".harness/guides/pkg-release-and-supply-chain.md"
assert_file_contains "${ROOT_DIR}/go-harness/AGENTS.md" ".harness/guides/testing-and-validation.md"
assert_file_contains "${ROOT_DIR}/go-harness/AGENTS.md" ".harness/guides/workers-and-scheduling.md"
assert_file_contains "${ROOT_DIR}/go-harness/CLAUDE.md" ".harness/guides/testing-and-validation.md"
assert_file_contains "${ROOT_DIR}/go-harness/CLAUDE.md" ".harness/guides/workers-and-scheduling.md"

assert_file_contains "${ROOT_DIR}/fullstack-harness/AGENTS.md" "backend/"
assert_file_contains "${ROOT_DIR}/fullstack-harness/AGENTS.md" "frontend/"
assert_file_contains "${ROOT_DIR}/fullstack-harness/AGENTS.md" ".harness/guides/testing-and-validation.md"
assert_file_contains "${ROOT_DIR}/fullstack-harness/AGENTS.md" ".harness/guides/workers-and-scheduling.md"
assert_file_not_contains "${ROOT_DIR}/fullstack-harness/AGENTS.md" "web/src/api/types.ts"
assert_file_contains "${ROOT_DIR}/README.md" "### Claude Code 怎么用"
assert_file_contains "${ROOT_DIR}/README.md" "### Codex 怎么用"
assert_file_contains "${ROOT_DIR}/README.md" '$harness-research'
assert_file_contains "${ROOT_DIR}/README.md" "docs/harness-command-workflow.md"
assert_file_contains "${ROOT_DIR}/docs/harness-command-workflow.md" "## 命令对照"
assert_file_contains "${ROOT_DIR}/docs/harness-command-workflow.md" "doctor -> research -> plan -> implement -> review"

for harness_dir in go-harness go-grpc-harness fullstack-harness go-pkg-harness laravel-harness laravel-fullstack-harness; do
    assert_file_contains "${ROOT_DIR}/${harness_dir}/AGENTS.md" "## 本机容器与镜像纪律（铁律）"
    assert_file_contains "${ROOT_DIR}/${harness_dir}/AGENTS.md" "docker images"
    assert_file_contains "${ROOT_DIR}/${harness_dir}/AGENTS.md" "docker ps -a"
    assert_file_contains "${ROOT_DIR}/${harness_dir}/CLAUDE.md" "## 本机容器与镜像纪律（铁律）"
    assert_file_contains "${ROOT_DIR}/${harness_dir}/CLAUDE.md" "docker images"
    assert_file_contains "${ROOT_DIR}/${harness_dir}/CLAUDE.md" "docker ps -a"
done

# --- 反证测试：入口文件托管块、自愈、hook 注册、shared guides、rules、SessionStart hook、harness-refresh ---
managed_home="${tmpdir}/managed-home"
managed_project="${tmpdir}/managed-project"
mkdir -p "$managed_home" "$managed_project"
run_setup "go-harness" "$managed_project" "$managed_home"

# 托管块保留：追加块后重跑应判为一致；改正文后强刷应刷新正文且块原样保留
printf '\n<!-- OPENSPEC-AUTO:START -->\n# OpenSpec First Workflow\nblock body $HOME keep me\n<!-- OPENSPEC-AUTO:END -->\n' >> "${managed_project}/CLAUDE.md"
out="$( (cd "$managed_project" && HOME="$managed_home" CODEX_HOME="$managed_home/.codex" bash "${ROOT_DIR}/go-harness/setup.sh") )"
grep -Fq "CLAUDE.md 已存在且与本版本一致（含 openspec-auto 托管块）" <<<"$out" || fail "entry file with managed block must compare equal to template"
sed -i '' 's/^## 编码基线$/## 编码基线X/' "${managed_project}/CLAUDE.md"
out="$( (cd "$managed_project" && HOME="$managed_home" CODEX_HOME="$managed_home/.codex" bash "${ROOT_DIR}/go-harness/setup.sh") )"
grep -Fq "CLAUDE.md 已存在且内容与本版本模板不同，保留未动" <<<"$out" || fail "modified entry body must be reported and left untouched"
assert_file_contains "${managed_project}/CLAUDE.md" "编码基线X"
run_setup "go-harness" "$managed_project" "$managed_home" "1"
assert_file_not_contains "${managed_project}/CLAUDE.md" "编码基线X"
assert_file_contains "${managed_project}/CLAUDE.md" "## 编码基线"
assert_file_contains "${managed_project}/CLAUDE.md" 'block body $HOME keep me'
if [ "$(grep -c 'OPENSPEC-AUTO:START' "${managed_project}/CLAUDE.md")" != "1" ]; then
    fail "force refresh must keep exactly one managed block"
fi

# 自愈：入口文件只剩 openspec-auto 托管块时不算用户定制，普通 setup 必须补齐 harness 规则并保留块
heal_home="${tmpdir}/heal-home"
heal_project="${tmpdir}/heal-project"
mkdir -p "$heal_home" "$heal_project"
git init -q "$heal_project"
printf '<!-- OPENSPEC-AUTO:START -->\nopenspec only\n<!-- OPENSPEC-AUTO:END -->\n' | tee "${heal_project}/CLAUDE.md" > "${heal_project}/AGENTS.md"
run_setup "go-harness" "$heal_project" "$heal_home"
for f in CLAUDE.md AGENTS.md; do
    assert_file_contains "${heal_project}/${f}" "## Guide 加载表"
    assert_file_contains "${heal_project}/${f}" "openspec only"
    if [ "$(grep -c 'OPENSPEC-AUTO:START' "${heal_project}/${f}")" != "1" ]; then
        fail "self-heal must keep exactly one managed block in ${f}"
    fi
done

# hook 注册幂等：重跑两次，两份配置里各只有一条 harness 注册
run_setup "go-harness" "$managed_project" "$managed_home"
for cfg in .claude/settings.json .codex/hooks.json; do
    count="$(python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
print(sum(1 for e in d['hooks']['SessionStart'] for h in e['hooks'] if '/.harness/hooks/' in h['command']))" "${managed_project}/${cfg}")"
    [ "$count" = "1" ] || fail "expected exactly one harness SessionStart hook in ${cfg}, got ${count}"
done

# shared guides：装进项目的公共 guide 必须与 shared/guides 源一致；rules 必须带 paths 且指向存在的 guide
cmp -s "${ROOT_DIR}/shared/guides/go/db-patterns.md" "${managed_project}/.harness/guides/db-patterns.md" || fail "shared guide db-patterns.md must be installed verbatim"
cmp -s "${ROOT_DIR}/shared/guides/common/commit-and-changelog.md" "${managed_project}/.harness/guides/commit-and-changelog.md" || fail "shared guide commit-and-changelog.md must be installed verbatim"
for rule in "${managed_project}"/.claude/rules/harness-*.md; do
    guide="$(sed -n 's/.*`\.harness\/guides\/\([a-z0-9-]*\.md\)`.*/\1/p' "$rule" | head -n1)"
    [ -n "$guide" ] || fail "rule $(basename "$rule") must point to a guide"
    test -f "${managed_project}/.harness/guides/${guide}" || fail "rule $(basename "$rule") points to missing guide ${guide}"
    assert_file_contains "$rule" "paths:"
done

# SessionStart hook：无 open 条目且版本一致时静默；有 open 条目且版本落后时注入两条
assert_file_contains "${managed_project}/.harness/VERSION" "source-path: ${ROOT_DIR}"
hook_out="$(cd "$managed_project" && echo '{}' | python3 .harness/hooks/session_start.py)"
[ -z "$hook_out" ] || fail "session hook must print nothing when journal has no open entry and template is current, got: ${hook_out}"
err_id="$(bash "${managed_project}/.harness/scripts/append-error-journal.sh" "$managed_project" user-correction auth "入口边界改错")"
sed -i '' 's/^source-commit: .*/source-commit: 000000000000/' "${managed_project}/.harness/VERSION"
hook_out="$(cd "$managed_project" && echo '{}' | python3 .harness/hooks/session_start.py | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])')"
grep -Fq "$err_id" <<<"$hook_out" || fail "session hook must list open journal entry ${err_id}"
grep -Fq "入口边界改错" <<<"$hook_out" || fail "session hook must include the entry summary"
grep -Fq "go-harness --force-guides" <<<"$hook_out" || fail "session hook must suggest refresh when template commit differs"
bash "${managed_project}/.harness/scripts/close-error-journal.sh" "$managed_project" "$err_id" "已修" >/dev/null
hook_out="$(cd "$managed_project" && echo '{}' | python3 .harness/hooks/session_start.py | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])')"
if grep -Fq "$err_id" <<<"$hook_out"; then
    fail "closed journal entry must not be injected by session hook"
fi

# harness-refresh：报告识别落后 / 本地改动 / 未安装；apply --no-force 修自愈项目且不覆盖本地改动，并留下备份
refresh_home="${tmpdir}/refresh-home"
mkdir -p "$refresh_home"
printf 'LOCAL EDIT\n' >> "${managed_project}/AGENTS.md"
report="$(HOME="$refresh_home" HARNESS_PROJECTS_FILE="${tmpdir}/projects.txt" bash "${ROOT_DIR}/scripts/harness-refresh.sh" add "$managed_project" "$heal_project" "${tmpdir}/not-a-harness-project" 2>&1 || true)"
mkdir -p "${tmpdir}/not-a-harness-project"
report="$(HOME="$refresh_home" HARNESS_PROJECTS_FILE="${tmpdir}/projects.txt" bash "${ROOT_DIR}/scripts/harness-refresh.sh")"
grep -Fq "落后" <<<"$report" || fail "refresh report must flag the project with an outdated source-commit"
grep -Fq "入口文件与模板不同" <<<"$report" || fail "refresh report must flag locally edited entry files"
HOME="$refresh_home" HARNESS_PROJECTS_FILE="${tmpdir}/projects.txt" bash "${ROOT_DIR}/scripts/harness-refresh.sh" add "${tmpdir}/not-a-harness-project" >/dev/null
report="$(HOME="$refresh_home" HARNESS_PROJECTS_FILE="${tmpdir}/projects.txt" bash "${ROOT_DIR}/scripts/harness-refresh.sh")"
grep -Fq "未安装 harness" <<<"$report" || fail "refresh report must flag directories without .harness/VERSION"
apply_out="$(HOME="$refresh_home" HARNESS_PROJECTS_FILE="${tmpdir}/projects.txt" CODEX_HOME="$refresh_home/.codex" bash "${ROOT_DIR}/scripts/harness-refresh.sh" apply --no-force --no-openspec)"
assert_file_contains "${managed_project}/AGENTS.md" "LOCAL EDIT"
backup_dir="$(find "${refresh_home}/.config/harness-engineering/backups" -mindepth 2 -maxdepth 2 -name "$(basename "$managed_project")" | head -n1)"
[ -n "$backup_dir" ] || fail "refresh apply must back up the project before touching it"
assert_file_contains "${backup_dir}/AGENTS.md" "LOCAL EDIT"
test -d "${backup_dir}/guides" || fail "refresh apply backup must include .harness/guides"
grep -Fq "已刷新" <<<"$apply_out" || fail "refresh apply must report refreshed projects"

printf 'setup smoke test passed\n'
