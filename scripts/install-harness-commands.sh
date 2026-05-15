#!/usr/bin/env bash
set -euo pipefail

install_harness_commands() {
    local harness_root="$1"
    local project_dir="$2"
    local force_project_files="${3:-0}"
    local source_dir="${harness_root}/commands/harness"
    local target_dir="${project_dir}/.claude/commands/harness"

    if [ ! -d "${source_dir}" ]; then
        echo "✗ 错误: 找不到 ${source_dir}"
        return 1
    fi

    mkdir -p "${target_dir}"

    local copied=0
    local preserved=0
    local found=0
    local f
    local filename
    local dest

    for f in "${source_dir}/"*.md; do
        if [ ! -e "$f" ]; then
            continue
        fi
        found=1
        filename="$(basename "$f")"
        dest="${target_dir}/${filename}"
        if [ "${force_project_files}" = "1" ] || [ ! -f "${dest}" ]; then
            cp "$f" "${dest}"
            copied=$((copied + 1))
        else
            preserved=$((preserved + 1))
        fi
    done

    if [ "${found}" = "0" ]; then
        echo "✗ 错误: ${source_dir} 下没有可安装的命令模板"
        return 1
    fi

    if [ "${force_project_files}" = "1" ]; then
        echo "  ✓ .claude/commands/harness/ — 已刷新 ${copied} 个命令"
    else
        echo "  ✓ .claude/commands/harness/ — 新增 ${copied} 个，保留 ${preserved} 个"
    fi
}
