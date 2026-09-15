#!/usr/bin/env bash
set -euo pipefail

# 文件名沿用早期的 "commands"：现在装的是 skills（Claude Code 与 Codex 各一份）与 Claude 的
# 路径限定 rules，旧的 .claude/commands/harness/ 会被清掉。

# _harness_copy_tree <source_dir> <target_dir> <force> <label>
# 把 source_dir 下的 .md 文件（含一层子目录里的 SKILL.md）复制到 target_dir；
# 已存在的文件默认保留，force=1 时覆盖。输出 "新增 保留" 两个计数。
_harness_copy_tree() {
    local source_dir="$1"
    local target_dir="$2"
    local force="$3"
    local copied=0
    local preserved=0
    local f rel dest

    while IFS= read -r f; do
        rel="${f#"${source_dir}"/}"
        dest="${target_dir}/${rel}"
        mkdir -p "$(dirname "${dest}")"
        if [ "${force}" = "1" ] || [ ! -f "${dest}" ]; then
            cp "$f" "${dest}"
            copied=$((copied + 1))
        else
            preserved=$((preserved + 1))
        fi
    done <<EOF
$(find "${source_dir}" -type f -name '*.md' | sort)
EOF
    printf '%s %s\n' "${copied}" "${preserved}"
}

_harness_report_copy() {
    local label="$1"
    local force="$2"
    local counts="$3"
    local copied="${counts% *}"
    local preserved="${counts#* }"
    if [ "${force}" = "1" ]; then
        echo "  ✓ ${label} — 已刷新 ${copied} 个"
    else
        echo "  ✓ ${label} — 新增 ${copied} 个，保留 ${preserved} 个"
    fi
}

# install_harness_skills <harness_root> <module_dir> <project_dir> <force_project_files>
install_harness_skills() {
    local harness_root="$1"
    local module_dir="$2"
    local project_dir="$3"
    local force="${4:-0}"
    local skills_dir="${harness_root}/skills"
    local rules_dir="${module_dir}/rules"

    if [ ! -d "${skills_dir}" ] || [ -z "$(find "${skills_dir}" -name SKILL.md -print -quit)" ]; then
        echo "✗ 错误: ${skills_dir} 下没有可安装的 skill"
        return 1
    fi

    # 1.10.0 及更早版本装的是 .claude/commands/harness/，Claude Code 已把 commands 标为旧格式
    if [ -d "${project_dir}/.claude/commands/harness" ]; then
        rm -rf "${project_dir}/.claude/commands/harness"
        rmdir "${project_dir}/.claude/commands" 2>/dev/null || true
        echo "  ✓ 已移除旧的 .claude/commands/harness/（改为 skills）"
    fi

    # 同一份 SKILL.md 双端各装一份：Claude Code 读 .claude/skills，Codex 读 .agents/skills
    _harness_report_copy ".claude/skills/harness-*/" "${force}" \
        "$(_harness_copy_tree "${skills_dir}" "${project_dir}/.claude/skills" "${force}")"
    _harness_report_copy ".agents/skills/harness-*/" "${force}" \
        "$(_harness_copy_tree "${skills_dir}" "${project_dir}/.agents/skills" "${force}")"

    # Claude Code 的路径限定规则：只在读到匹配文件时把对应 guide 拉进上下文
    if [ -d "${rules_dir}" ]; then
        _harness_report_copy ".claude/rules/harness-*.md" "${force}" \
            "$(_harness_copy_tree "${rules_dir}" "${project_dir}/.claude/rules" "${force}")"
    fi
}
