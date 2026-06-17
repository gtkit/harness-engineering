#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Harness 统一安装共享库（macOS / Linux）
#
# 5 套 harness 的 setup.sh 都是薄包装，统一调用本文件的 install_harness。
# 与 PowerShell 端 scripts/install-harness.ps1 的 Invoke-HarnessSetup 对齐，
# 把 .gitignore 规则、安装流程等收敛到单一源头，避免 sh / ps1 漂移。
# ============================================================

# shellcheck disable=SC1091
_HARNESS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 复用命令模板安装逻辑
# shellcheck source=./install-harness-commands.sh
. "${_HARNESS_LIB_DIR}/install-harness-commands.sh"

# .gitignore 单一源头：sh / ps1 必须保持一致（见 tests/*smoke*）。
# 整个 .harness/ 目录均为 setup 可再生的本地产物，不入库。
_harness_gitignore_patterns() {
    cat <<'EOF'
.openspec-auto-backup/
.openspec-auto/
.idea/
.vscode/
.Ds_Store
.DS_Store
*.log
findings.md
progress.md
task_plan.md
.harness/
.claude/
.codex/
.agents/
openspec/
AGENTS.md
CLAUDE.md
tools/
EOF
}

_harness_append_gitignore_line() {
    local file="$1"
    local line="$2"

    if ! grep -Fxq "$line" "$file" 2>/dev/null; then
        printf '%s\n' "$line" >> "$file"
        return 0
    fi
    return 1
}

# install_harness <module_name> <display_name> <script_dir>
install_harness() {
    local module_name="$1"
    local display_name="${2:-$module_name}"
    local script_dir="$3"

    local harness_root
    harness_root="$(cd "${script_dir}/.." && pwd)"
    local project_dir
    project_dir="$(pwd)"
    local force_guides="${HARNESS_FORCE_GUIDES:-0}"
    local force_project_files="${HARNESS_FORCE_PROJECT_FILES:-0}"
    local error_journal_runtime_dir="${harness_root}/scripts/error-journal"

    # ---------- 前置检查 ----------
    if [ ! -d "${script_dir}/guides" ]; then
        echo "✗ 错误: 找不到 ${script_dir}/guides/ 目录"
        echo "  请确认 setup.sh 和 guides/ 在同一目录下"
        exit 1
    fi
    if [ ! -d "${error_journal_runtime_dir}" ]; then
        echo "✗ 错误: 找不到 ${error_journal_runtime_dir}"
        exit 1
    fi
    if [ ! -f "${script_dir}/SKILL.md" ]; then
        echo "✗ 错误: 找不到 ${script_dir}/SKILL.md"
        exit 1
    fi
    if [ ! -f "${script_dir}/SKILL.codex.md" ]; then
        echo "✗ 错误: 找不到 ${script_dir}/SKILL.codex.md"
        exit 1
    fi
    if [ ! -f "${script_dir}/CLAUDE.md" ]; then
        echo "✗ 错误: 找不到 ${script_dir}/CLAUDE.md"
        exit 1
    fi
    if [ ! -f "${script_dir}/AGENTS.md" ]; then
        echo "✗ 错误: 找不到 ${script_dir}/AGENTS.md"
        exit 1
    fi

    echo ""
    echo "============================================"
    echo "  ${display_name} 安装"
    echo "============================================"
    echo ""
    echo "  脚本位置:  ${script_dir}"
    echo "  项目目录:  ${project_dir}"
    echo ""

    # ==========================================================
    # Step 1: 全局 Skill（只装一次，所有项目共享）
    # ==========================================================
    echo "--------------------------------------------"
    echo "[Step 1] 安装全局 Skill"
    echo "--------------------------------------------"
    echo ""

    local claude_skill_dir="${HOME}/.claude/skills/${module_name}"
    mkdir -p "${claude_skill_dir}"
    cp "${script_dir}/SKILL.md" "${claude_skill_dir}/SKILL.md"
    echo "  ✓ ${claude_skill_dir}/SKILL.md"

    local codex_home="${CODEX_HOME:-${HOME}/.codex}"
    local codex_skill_dir="${codex_home}/skills/${module_name}"
    mkdir -p "${codex_skill_dir}"
    cp "${script_dir}/SKILL.codex.md" "${codex_skill_dir}/SKILL.md"
    echo "  ✓ ${codex_skill_dir}/SKILL.md"
    echo ""

    # ==========================================================
    # Step 2: 项目级文件
    # ==========================================================
    echo "--------------------------------------------"
    echo "[Step 2] 安装项目级文件到 ${project_dir}"
    echo "--------------------------------------------"
    echo ""

    _harness_install_project_file "${script_dir}/CLAUDE.md" "${project_dir}/CLAUDE.md" "CLAUDE.md" "${force_project_files}"
    _harness_install_project_file "${script_dir}/AGENTS.md" "${project_dir}/AGENTS.md" "AGENTS.md" "${force_project_files}"

    # -- .harness/guides/ --
    mkdir -p "${project_dir}/.harness/guides"
    local guide_copied=0
    local guide_preserved=0
    local f filename dest
    for f in "${script_dir}/guides/"*.md; do
        filename="$(basename "$f")"
        if [ "$filename" = "error-journal-template.md" ]; then
            continue
        fi
        dest="${project_dir}/.harness/guides/${filename}"
        if [ "${force_guides}" = "1" ] || [ ! -f "$dest" ]; then
            cp "$f" "$dest"
            guide_copied=$((guide_copied + 1))
        else
            guide_preserved=$((guide_preserved + 1))
        fi
    done
    local guide_count
    guide_count=$(find "${project_dir}/.harness/guides" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
    if [ "${force_guides}" = "1" ]; then
        echo "  ✓ .harness/guides/ — ${guide_count} 个规范文档（强制刷新 ${guide_copied} 个）"
    else
        echo "  ✓ .harness/guides/ — ${guide_count} 个规范文档（新增 ${guide_copied} 个，保留 ${guide_preserved} 个）"
    fi

    # -- .harness/scripts/（error-journal runtime）--
    mkdir -p "${project_dir}/.harness/scripts"
    local runtime_copied=0
    local runtime_preserved=0
    for f in "${error_journal_runtime_dir}/"*; do
        filename="$(basename "$f")"
        dest="${project_dir}/.harness/scripts/${filename}"
        if [ "${force_project_files}" = "1" ] || [ ! -f "$dest" ]; then
            cp "$f" "$dest"
            runtime_copied=$((runtime_copied + 1))
        else
            runtime_preserved=$((runtime_preserved + 1))
        fi
    done
    if [ "${force_project_files}" = "1" ]; then
        echo "  ✓ .harness/scripts/ — 已刷新 ${runtime_copied} 个 runtime 脚本"
    else
        echo "  ✓ .harness/scripts/ — 新增 ${runtime_copied} 个，保留 ${runtime_preserved} 个"
    fi

    # -- .harness/error-journal.md --
    if [ ! -f "${project_dir}/.harness/error-journal.md" ]; then
        cp "${script_dir}/guides/error-journal-template.md" "${project_dir}/.harness/error-journal.md"
        echo "  ✓ .harness/error-journal.md"
    else
        echo "  ⊘ .harness/error-journal.md 已存在，保留现有记录"
    fi
    echo ""

    # ==========================================================
    # Step 3: Claude Code Commands
    # ==========================================================
    echo "--------------------------------------------"
    echo "[Step 3] 安装 Claude Code Commands"
    echo "--------------------------------------------"
    echo ""
    install_harness_commands "${harness_root}" "${project_dir}" "${force_project_files}"
    echo ""

    # ==========================================================
    # Step 4: .gitignore
    # ==========================================================
    echo "--------------------------------------------"
    echo "[Step 4] 更新 .gitignore"
    echo "--------------------------------------------"
    echo ""

    local gitignore_file="${project_dir}/.gitignore"
    if [ ! -f "${gitignore_file}" ]; then
        touch "${gitignore_file}"
        echo "  ✓ 已创建 .gitignore"
    else
        echo "  ⊘ .gitignore 已存在，继续补充规则"
    fi

    local gitignore_updated=0
    if ! grep -Fq "# Harness: 本地工具与 Agent 运行产物" "${gitignore_file}" 2>/dev/null; then
        printf '\n# Harness: 本地工具与 Agent 运行产物\n' >> "${gitignore_file}"
        gitignore_updated=1
    fi
    local pattern
    while IFS= read -r pattern; do
        [ -n "${pattern}" ] || continue
        if _harness_append_gitignore_line "${gitignore_file}" "${pattern}"; then
            gitignore_updated=1
        fi
    done <<EOF
$(_harness_gitignore_patterns)
EOF

    if [ "${gitignore_updated}" -eq 1 ]; then
        echo "  ✓ .gitignore 已同步 Harness 忽略规则"
    else
        echo "  ⊘ .gitignore 已包含相关规则"
    fi
    echo ""

    # ==========================================================
    # Step 5: 写入 .harness/VERSION
    # ==========================================================
    echo "--------------------------------------------"
    echo "[Step 5] 写入 .harness/VERSION"
    echo "--------------------------------------------"
    echo ""

    local version_file="${project_dir}/.harness/VERSION"
    local source_commit source_tag installed_at
    source_commit="$(git -C "${harness_root}" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
    source_tag="$(git -C "${harness_root}" describe --tags --abbrev=0 2>/dev/null || true)"
    installed_at="$(date '+%Y-%m-%dT%H:%M:%S%z')"
    {
        printf 'harness: %s\n' "${module_name}"
        printf 'source-commit: %s\n' "${source_commit}"
        if [ -n "${source_tag:-}" ]; then
            printf 'source-tag: %s\n' "${source_tag}"
        fi
        printf 'installed-at: %s\n' "${installed_at}"
        printf 'installer: setup.sh\n'
    } > "${version_file}"
    echo "  ✓ 已写入 .harness/VERSION (commit: ${source_commit})"
    echo ""

    # ==========================================================
    # 完成
    # ==========================================================
    echo "============================================"
    echo "  安装完成"
    echo "============================================"
    echo ""
    echo "  全局 Skill（装一次，所有项目共享）："
    echo "    ${claude_skill_dir}/SKILL.md"
    echo "    ${codex_skill_dir}/SKILL.md"
    echo ""
    echo "  项目文件："
    echo "    ${project_dir}/CLAUDE.md"
    echo "    ${project_dir}/AGENTS.md"
    echo "    ${project_dir}/.harness/  (error-journal.md / guides/ ${guide_count} 篇 / scripts/)"
    echo "    ${project_dir}/.claude/commands/harness/"
    echo ""
    echo "  全局 Skill 只是入口；项目规则维护在 CLAUDE.md、AGENTS.md 和 .harness/guides/。"
    echo ""
}

# _harness_install_project_file <src> <dest> <label> <force>
_harness_install_project_file() {
    local src="$1"
    local dest="$2"
    local label="$3"
    local force="$4"

    if [ "${force}" = "1" ] || [ ! -f "${dest}" ]; then
        cp "${src}" "${dest}"
        if [ "${force}" = "1" ]; then
            echo "  ✓ ${label}（已刷新）"
        else
            echo "  ✓ ${label}"
        fi
    else
        echo "  ⊘ ${label} 已存在，跳过"
    fi
}
