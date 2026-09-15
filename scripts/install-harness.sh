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

# 忽略规则单一源头：sh / ps1 必须保持一致（见 tests/*smoke*）。
#
# 分两处落地：
#   - .gitignore（可入库）：只放通用构建 / 编辑器 / OS 产物，不暴露本地工具链。
#   - .git/info/exclude（仅本地、绝不入库）：本地工具与 Agent 运行产物，
#     避免忽略规则本身泄露"本项目使用了 AI 工具"。
# _harness_gitignore_patterns <module_name>
# module_name 用于区分库项目与应用项目：go-pkg-harness 是纯扩展包，
# 不产生 .env 运行配置，其余 harness 面向应用/服务，一律忽略 .env。
_harness_gitignore_patterns() {
    local module_name="${1:-}"

    cat <<'EOF'
.idea/
.vscode/
.Ds_Store
.DS_Store
*.log
*.out
EOF

    if [ "${module_name}" != "go-pkg-harness" ]; then
        printf '%s\n' '.env'
    fi
}

# openspec-auto 现在全部落在 .openspec-auto/ 下，不再需要忽略任何非隐藏的 tools 目录。
_harness_exclude_patterns() {
    cat <<'EOF'
.openspec-auto-backup/
.openspec-auto/
.harness/
.claude/
.codex/
.agents/
openspec/
AGENTS.md
CLAUDE.md
.learnings/
findings.md
progress.md
task_plan.md
EOF
}

# 旧版本（1.x）曾把上述本地工具规则连同 "# Harness:" 标题一起误写进 .gitignore，
# 迁移时需从 .gitignore 里精确剔除这些历史行（通用产物行保留）。
# 1.7.0 ~ 1.10.0 还写过整目录 tools/（会把业务自己的 tools/ 挡在版本库外），
# 之后短暂写过 tools/openspec/；两条都从 .gitignore 与 .git/info/exclude 里剔除。
_HARNESS_LEGACY_GITIGNORE_HEADER="# Harness: 本地工具与 Agent 运行产物"
_HARNESS_LEGACY_TOOLS_PATTERNS="tools/
tools/openspec/"

_harness_legacy_gitignore_patterns() {
    _harness_exclude_patterns
    printf '%s\n' "${_HARNESS_LEGACY_TOOLS_PATTERNS}"
}

_harness_append_unique_line() {
    local file="$1"
    local line="$2"

    if ! grep -Fxq "$line" "$file" 2>/dev/null; then
        printf '%s\n' "$line" >> "$file"
        return 0
    fi
    return 1
}

# 若文件非空且结尾无换行，补一个换行，避免后续 append 粘到最后一行。
_harness_ensure_trailing_newline() {
    local file="$1"
    [ -s "$file" ] || return 0
    if [ -n "$(tail -c1 "$file" 2>/dev/null)" ]; then
        printf '\n' >> "$file"
    fi
}

# 精确删除文件中与 line 完全相同的行；有删除返回 0，否则返回 1。
_harness_remove_exact_line() {
    local file="$1"
    local line="$2"
    [ -f "$file" ] || return 1
    grep -Fxq -- "$line" "$file" || return 1
    local tmp
    tmp="$(mktemp)"
    grep -Fxv -- "$line" "$file" > "$tmp" || true
    mv "$tmp" "$file"
}

# openspec-auto 往 CLAUDE.md / AGENTS.md 注入的托管块。harness 整文件比对与刷新时把它
# 摘出来单独处理：比对时忽略它（否则装过 openspec-auto 的项目每次重跑都被判为"与模板不同"），
# 强制刷新时先写模板再把块原样追加回去，不用再重跑 openspec-auto 补块。
_HARNESS_OPENSPEC_BLOCK_START="<!-- OPENSPEC-AUTO:START -->"
_HARNESS_OPENSPEC_BLOCK_END="<!-- OPENSPEC-AUTO:END -->"

# 输出文件中的托管块（含起止标记行）；没有块时无输出。
_harness_extract_managed_block() {
    local file="$1"
    [ -f "$file" ] || return 0
    awk -v s="${_HARNESS_OPENSPEC_BLOCK_START}" -v e="${_HARNESS_OPENSPEC_BLOCK_END}" '
        $0 == s { inside = 1 }
        inside { print }
        $0 == e { inside = 0 }
    ' "$file"
}

# 输出去掉托管块（及其前置空行）后的文件内容，用于与模板比对。
_harness_strip_managed_block() {
    local file="$1"
    awk -v s="${_HARNESS_OPENSPEC_BLOCK_START}" -v e="${_HARNESS_OPENSPEC_BLOCK_END}" '
        $0 == s { inside = 1; next }
        $0 == e { inside = 0; next }
        !inside { print }
    ' "$file" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}

# 从 .gitignore 中剔除历史误写入的本地工具规则与旧标题；有剔除返回 0，否则返回 1。
_harness_strip_gitignore_legacy() {
    local file="$1"
    [ -f "$file" ] || return 1

    local removal
    removal="$(_harness_legacy_gitignore_patterns)"
    local tmp
    tmp="$(mktemp)"
    local removed=0
    local line
    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$line" = "${_HARNESS_LEGACY_GITIGNORE_HEADER}" ]; then
            removed=1
            continue
        fi
        if [ -n "$line" ] && printf '%s\n' "$removal" | grep -Fxq -- "$line"; then
            removed=1
            continue
        fi
        printf '%s\n' "$line" >> "$tmp"
    done < "$file"

    if [ "$removed" -eq 1 ]; then
        mv "$tmp" "$file"
        return 0
    fi
    rm -f "$tmp"
    return 1
}

# 解析项目的 .git/info/exclude 路径（兼容 worktree / submodule）；非 git 仓库输出空串。
_harness_resolve_exclude_file() {
    local project_dir="$1"
    if git -C "$project_dir" rev-parse --git-dir >/dev/null 2>&1; then
        local p
        p="$(cd "$project_dir" && git rev-parse --git-path info/exclude 2>/dev/null)"
        [ -n "$p" ] || return 0
        case "$p" in
            /*) printf '%s\n' "$p" ;;
            *)  printf '%s/%s\n' "$project_dir" "$p" ;;
        esac
    fi
}

# _harness_stage_guides <harness_root> <script_dir> <staged_dir>
_harness_stage_guides() {
    local harness_root="$1"
    local script_dir="$2"
    local staged="$3"
    local manifest="${script_dir}/shared-guides.txt"
    local rel
    if [ -f "${manifest}" ]; then
        while IFS= read -r rel || [ -n "$rel" ]; do
            rel="${rel%%#*}"
            rel="$(printf '%s' "$rel" | tr -d '[:space:]')"
            [ -n "$rel" ] || continue
            if [ ! -f "${harness_root}/shared/guides/${rel}" ]; then
                echo "✗ 错误: shared-guides.txt 引用的 shared/guides/${rel} 不存在"
                exit 1
            fi
            cp "${harness_root}/shared/guides/${rel}" "${staged}/$(basename "${rel}")"
        done < "${manifest}"
    fi
    local f
    for f in "${script_dir}/guides/"*.md; do
        [ -f "$f" ] && cp "$f" "${staged}/$(basename "$f")"
    done
    return 0
}

# SessionStart hook：把 error-journal 里 open 的条目和模板版本落后的提示注入会话上下文。
# 脚本放 .harness/hooks/，同一份注册进 Claude Code 的 .claude/settings.json 与 Codex 的 .codex/hooks.json；
# 命令按 python3 → python 探测解释器（Windows 官方安装包只有 python.exe）。
# 注册要改 JSON，用 python 做；本机没有 python 时跳过并提示，hook 脚本本身也跑不起来。
_HARNESS_HOOK_COMMAND='ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; PY="$(command -v python3 || command -v python)"; "$PY" "$ROOT/.harness/hooks/session_start.py"'

# _harness_register_hook <config_file> <python>
_harness_register_hook() {
    local config="$1"
    local python="$2"
    "$python" - "$config" "${_HARNESS_HOOK_COMMAND}" <<'PYEOF'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
command = sys.argv[2]
data = json.loads(path.read_text()) if path.is_file() and path.read_text().strip() else {}
hooks = data.setdefault("hooks", {})
entries = hooks.setdefault("SessionStart", [])
# 先剥掉旧的 harness 注册（按脚本路径识别），再写当前命令，命令串变化时也能刷新
kept = []
for entry in entries:
    remaining = [h for h in entry.get("hooks", []) if "/.harness/hooks/" not in h.get("command", "")]
    if remaining:
        entry["hooks"] = remaining
        kept.append(entry)
kept.append({"matcher": ".*", "hooks": [{"type": "command", "command": command, "timeout": 15}]})
hooks["SessionStart"] = kept
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
PYEOF
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

    # 差异清单：已存在且内容与本版本模板不同的文件（仅提示，不覆盖）。
    # 变量名里的 stale 只表示"与模板不同"，不断言方向——差异可能是本地落后，也可能是本地定制。
    _HARNESS_STALE_PROJECT_FILES=""
    _HARNESS_STALE_GUIDES=""

    # ---------- 前置检查 ----------
    if [ ! -d "${script_dir}/guides" ] && [ ! -f "${script_dir}/shared-guides.txt" ]; then
        echo "✗ 错误: ${script_dir} 下既没有 guides/ 也没有 shared-guides.txt"
        exit 1
    fi
    # guide 来源分两层：shared-guides.txt 列出的公共 guide（shared/guides/ 下），叠加本 harness 自己的
    # guides/*.md（同名以自己的为准）。先拼到暂存目录，后面的复制逻辑只看这一个目录。
    local staged_guides
    staged_guides="$(mktemp -d)"
    # 路径在设 trap 时就展开：trap 触发在函数返回之后，local 变量那时已不存在
    trap "rm -rf '${staged_guides}'" EXIT
    _harness_stage_guides "${harness_root}" "${script_dir}" "${staged_guides}"
    if [ ! -f "${staged_guides}/error-journal-template.md" ]; then
        echo "✗ 错误: ${module_name} 没有 error-journal-template.md（guides/ 或 shared 清单里都没有）"
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

    # Codex 官方的用户级 skill 目录是 ~/.agents/skills；1.10.0 及更早版本装在 $CODEX_HOME/skills（旧位置），
    # 两处同名会重复触发，迁移时把旧的删掉。
    local codex_skill_dir="${HOME}/.agents/skills/${module_name}"
    mkdir -p "${codex_skill_dir}"
    cp "${script_dir}/SKILL.codex.md" "${codex_skill_dir}/SKILL.md"
    echo "  ✓ ${codex_skill_dir}/SKILL.md"
    local legacy_codex_skill_dir="${CODEX_HOME:-${HOME}/.codex}/skills/${module_name}"
    if [ -f "${legacy_codex_skill_dir}/SKILL.md" ]; then
        rm -rf "${legacy_codex_skill_dir}"
        echo "  ✓ 已移除旧位置 ${legacy_codex_skill_dir}（Codex 现读 ~/.agents/skills）"
    fi
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
    local guide_stale=0
    local f filename dest
    for f in "${staged_guides}/"*.md; do
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
            if ! cmp -s "$f" "$dest"; then
                guide_stale=$((guide_stale + 1))
                _HARNESS_STALE_GUIDES="${_HARNESS_STALE_GUIDES}${filename} "
            fi
        fi
    done
    local guide_count
    guide_count=$(find "${project_dir}/.harness/guides" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
    if [ "${force_guides}" = "1" ]; then
        echo "  ✓ .harness/guides/ — ${guide_count} 个规范文档（强制刷新 ${guide_copied} 个）"
    else
        echo "  ✓ .harness/guides/ — ${guide_count} 个规范文档（新增 ${guide_copied} 个，保留 ${guide_preserved} 个）"
        if [ "${guide_stale}" -gt 0 ]; then
            echo "  ⚠ 其中 ${guide_stale} 个与本版本模板不同（未覆盖）"
        fi
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

    # -- .harness/hooks/（SessionStart hook）--
    mkdir -p "${project_dir}/.harness/hooks"
    cp "${harness_root}/scripts/hooks/session_start.py" "${project_dir}/.harness/hooks/session_start.py"
    local hook_python
    hook_python="$(command -v python3 || command -v python || true)"
    if [ -n "${hook_python}" ]; then
        _harness_register_hook "${project_dir}/.claude/settings.json" "${hook_python}"
        _harness_register_hook "${project_dir}/.codex/hooks.json" "${hook_python}"
        echo "  ✓ .harness/hooks/session_start.py 已注册到 .claude/settings.json 与 .codex/hooks.json"
    else
        echo "  ⚠ 本机没有 python3 / python，SessionStart hook 未注册（脚本已放到 .harness/hooks/，装好 Python 后重跑 setup）"
    fi

    # -- .harness/error-journal.md --
    if [ ! -f "${project_dir}/.harness/error-journal.md" ]; then
        cp "${staged_guides}/error-journal-template.md" "${project_dir}/.harness/error-journal.md"
        echo "  ✓ .harness/error-journal.md"
    else
        echo "  ⊘ .harness/error-journal.md 已存在，保留现有记录"
    fi
    echo ""

    # ==========================================================
    # Step 3: 项目级 skills（Claude Code + Codex）与 Claude 路径限定 rules
    # ==========================================================
    echo "--------------------------------------------"
    echo "[Step 3] 安装项目级 skills 与 rules"
    echo "--------------------------------------------"
    echo ""
    install_harness_skills "${harness_root}" "${script_dir}" "${project_dir}" "${force_project_files}"
    echo ""

    # ==========================================================
    # Step 4: .gitignore（通用产物）+ .git/info/exclude（本地工具/运行产物）
    # ==========================================================
    echo "--------------------------------------------"
    echo "[Step 4] 更新 .gitignore 与 .git/info/exclude"
    echo "--------------------------------------------"
    echo ""

    local pattern

    # -- 4a. .gitignore：仅通用构建 / 编辑器 / OS 产物 --
    local gitignore_file="${project_dir}/.gitignore"
    if [ ! -f "${gitignore_file}" ]; then
        touch "${gitignore_file}"
        echo "  ✓ 已创建 .gitignore"
    else
        echo "  ⊘ .gitignore 已存在，继续补充规则"
    fi

    # 迁移：把旧版本误写入 .gitignore 的本地工具规则清出去（移到 .git/info/exclude）
    if _harness_strip_gitignore_legacy "${gitignore_file}"; then
        echo "  ✓ 已从 .gitignore 清理历史本地工具规则（迁移到 .git/info/exclude）"
    fi

    _harness_ensure_trailing_newline "${gitignore_file}"
    local gitignore_updated=0
    while IFS= read -r pattern; do
        [ -n "${pattern}" ] || continue
        if _harness_append_unique_line "${gitignore_file}" "${pattern}"; then
            gitignore_updated=1
        fi
    done <<EOF
$(_harness_gitignore_patterns "${module_name}")
EOF
    if [ "${gitignore_updated}" -eq 1 ]; then
        echo "  ✓ .gitignore 已同步通用忽略规则"
    else
        echo "  ⊘ .gitignore 已包含通用规则"
    fi

    # -- 4b. .git/info/exclude：本地工具与 Agent 运行产物（绝不入库）--
    local exclude_file
    exclude_file="$(_harness_resolve_exclude_file "${project_dir}")"
    if [ -n "${exclude_file}" ]; then
        mkdir -p "$(dirname "${exclude_file}")"
        [ -f "${exclude_file}" ] || touch "${exclude_file}"

        local exclude_updated=0
        local exclude_header="# 本地工具与运行产物（仅本地忽略，不进版本库）"
        while IFS= read -r pattern; do
            if _harness_remove_exact_line "${exclude_file}" "${pattern}"; then
                exclude_updated=1
            fi
        done <<EOF
${_HARNESS_LEGACY_TOOLS_PATTERNS}
EOF
        if ! grep -Fxq "${exclude_header}" "${exclude_file}" 2>/dev/null; then
            _harness_ensure_trailing_newline "${exclude_file}"
            printf '%s\n' "${exclude_header}" >> "${exclude_file}"
            exclude_updated=1
        fi
        while IFS= read -r pattern; do
            [ -n "${pattern}" ] || continue
            if _harness_append_unique_line "${exclude_file}" "${pattern}"; then
                exclude_updated=1
            fi
        done <<EOF
$(_harness_exclude_patterns)
EOF
        if [ "${exclude_updated}" -eq 1 ]; then
            echo "  ✓ .git/info/exclude 已同步本地工具忽略规则"
        else
            echo "  ⊘ .git/info/exclude 已包含相关规则"
        fi
    else
        echo "  ⚠ 未检测到 git 仓库，跳过 .git/info/exclude"
        echo "    （请先 git init，再重跑 setup 以本地忽略 .harness/、CLAUDE.md 等）"
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
        printf 'source-path: %s\n' "${harness_root}"
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
    echo "    ${project_dir}/.harness/  (error-journal.md / guides/ ${guide_count} 篇 / scripts/ / hooks/)"
    echo "    ${project_dir}/.claude/skills/harness-*/  ${project_dir}/.agents/skills/harness-*/"
    echo "    ${project_dir}/.claude/rules/harness-*.md"
    echo ""
    echo "  全局 Skill 只是入口；项目规则维护在 CLAUDE.md、AGENTS.md 和 .harness/guides/。"
    echo ""

    if [ -n "${_HARNESS_STALE_PROJECT_FILES}${_HARNESS_STALE_GUIDES}" ]; then
        echo "--------------------------------------------"
        echo "  ⚠ 以下文件已存在且内容与本版本模板不同，本次未覆盖"
        echo "--------------------------------------------"
        if [ -n "${_HARNESS_STALE_PROJECT_FILES}" ]; then
            echo "    项目文件: ${_HARNESS_STALE_PROJECT_FILES}"
        fi
        if [ -n "${_HARNESS_STALE_GUIDES}" ]; then
            echo "    guides:   ${_HARNESS_STALE_GUIDES}"
        fi
        echo ""
        echo "  差异有两种可能：本地版本落后，或本地有意定制过。逐个 diff 确认属于哪种，"
        echo "  确认无需保留本地内容后，再用下面的命令强制刷新："
        echo "    HARNESS_FORCE_PROJECT_FILES=1 HARNESS_FORCE_GUIDES=1 bash ${script_dir}/setup.sh"
        echo ""
        echo "  注意：刷新 CLAUDE.md / AGENTS.md 是整文件覆盖；文件里的 openspec-auto 托管块"
        echo "  （OPENSPEC-AUTO:START/END）会原样保留，其余本地改动会丢失。"
        echo ""
    fi
}

# _harness_install_project_file <src> <dest> <label> <force>
# 只用于 CLAUDE.md / AGENTS.md：这两个文件可能带 openspec-auto 托管块，比对与刷新都要绕开它。
_harness_install_project_file() {
    local src="$1"
    local dest="$2"
    local label="$3"
    local force="$4"

    if [ ! -f "${dest}" ]; then
        cp "${src}" "${dest}"
        echo "  ✓ ${label}"
        return 0
    fi

    local block
    block="$(_harness_extract_managed_block "${dest}")"

    if [ "${force}" = "1" ]; then
        cp "${src}" "${dest}"
        if [ -n "${block}" ]; then
            printf '\n%s\n' "${block}" >> "${dest}"
            echo "  ✓ ${label}（已刷新，openspec-auto 托管块已保留）"
        else
            echo "  ✓ ${label}（已刷新）"
        fi
        return 0
    fi

    if [ -n "${block}" ]; then
        if [ "$(_harness_strip_managed_block "${dest}")" = "$(cat "${src}")" ]; then
            echo "  ⊘ ${label} 已存在且与本版本一致（含 openspec-auto 托管块），跳过"
            return 0
        fi
    elif cmp -s "${src}" "${dest}"; then
        echo "  ⊘ ${label} 已存在且与本版本一致，跳过"
        return 0
    fi

    echo "  ⚠ ${label} 已存在且内容与本版本模板不同，保留未动"
    _HARNESS_STALE_PROJECT_FILES="${_HARNESS_STALE_PROJECT_FILES}${label} "
}
