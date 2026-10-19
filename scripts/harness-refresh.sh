#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 批量查看 / 刷新多个项目的 harness 安装状态
#
# 项目清单：$HARNESS_PROJECTS_FILE，缺省 ~/.config/harness-engineering/projects.txt，
# 一行一个项目目录，# 开头是注释。
#
# 用法：
#   harness-refresh                 # 逐个项目报告：harness 名、已装 commit、是否落后、入口文件是否被改过
#   harness-refresh add <dir>...    # 把目录加进清单（已在清单里的跳过）
#   harness-refresh apply [--no-openspec]
#                                   # 对已安装项目执行 <harness> update <dir>，联动已安装 OpenSpec
#   harness-refresh apply --all ... # 兼容参数；安全模式始终检查所有已安装项目
#   harness-refresh apply --no-force ...
#                                   # 兼容参数；所有更新均备份并三方合并，冲突时该项目停止
#
# 报告只读 .harness/VERSION；apply 调用统一安全更新器，先备份所有托管文件和基线，
# 三方合并有冲突时不写该项目。备份位置按项目输出，其他项目可独立继续并汇总失败。
# ============================================================

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECTS_FILE="${HARNESS_PROJECTS_FILE:-${HOME}/.config/harness-engineering/projects.txt}"
CURRENT_COMMIT="$(git -C "${ROOT_DIR}" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"

usage() {
    echo "用法: harness-refresh | harness-refresh add <dir>... | harness-refresh apply [--all] [--no-force] [--no-openspec]"
    echo "清单文件: ${PROJECTS_FILE}"
    exit "${1:-1}"
}

# 读清单：去注释、去空行、展开 ~
list_projects() {
    [ -f "${PROJECTS_FILE}" ] || return 0
    local line
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [ -n "$line" ] || continue
        printf '%s\n' "${line/#\~/${HOME}}"
    done < "${PROJECTS_FILE}"
}

# 没装 harness（无 VERSION）时输出空串且返回 0：调用方在 set -e 下用 $(...) 赋值，失败会让整个脚本退出
version_field() {
    [ -f "$1/.harness/VERSION" ] || return 0
    sed -n "s/^$2: //p" "$1/.harness/VERSION" | head -n1
}

# 判断入口文件是否与模板不同（忽略 openspec-auto 托管块）；输出被改过的文件名
modified_entry_files() {
    local dir="$1" harness="$2" name
    for name in CLAUDE.md AGENTS.md; do
        [ -f "${dir}/${name}" ] || continue
        if [ "$(awk '$0=="<!-- OPENSPEC-AUTO:START -->"{s=1;next} $0=="<!-- OPENSPEC-AUTO:END -->"{s=0;next} !s' "${dir}/${name}" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')" != "$(cat "${ROOT_DIR}/${harness}/${name}")" ]; then
            printf '%s ' "$name"
        fi
    done
}

report() {
    local dir harness commit tag modified state
    local total=0 stale=0
    printf '模板仓库 HEAD: %s\n\n' "${CURRENT_COMMIT}"
    while IFS= read -r dir; do
        total=$((total + 1))
        if [ ! -d "$dir" ]; then
            printf '✗ %s\n    目录不存在\n' "$dir"
            continue
        fi
        harness="$(version_field "$dir" harness)"
        if [ -z "$harness" ]; then
            printf '✗ %s\n    未安装 harness（没有 .harness/VERSION）\n' "$dir"
            continue
        fi
        commit="$(version_field "$dir" source-commit)"
        tag="$(version_field "$dir" source-tag)"
        modified="$(modified_entry_files "$dir" "$harness")"
        if [ "$commit" = "${CURRENT_COMMIT}" ]; then
            state="最新"
        else
            state="落后"
            stale=$((stale + 1))
        fi
        printf '%s %s\n    %s  已装 %s%s\n' "$([ "$state" = 最新 ] && echo ✓ || echo ⚠)" "$dir" "$harness" "$commit" "${tag:+ ($tag)}"
        if [ -n "$modified" ]; then
            printf '    入口文件与模板不同（本地改动或版本落后）: %s\n' "$modified"
        fi
    done <<EOF
$(list_projects)
EOF
    printf '\n共 %d 个项目，%d 个落后。落后的用 harness-refresh apply 刷新。\n' "$total" "$stale"
}

add_projects() {
    [ "$#" -gt 0 ] || usage
    mkdir -p "$(dirname "${PROJECTS_FILE}")"
    touch "${PROJECTS_FILE}"
    local dir abs
    for dir in "$@"; do
        [ -d "$dir" ] || { echo "✗ 目录不存在: $dir"; continue; }
        abs="$(cd "$dir" && pwd)"
        if list_projects | grep -Fxq -- "$abs"; then
            echo "⊘ 已在清单: $abs"
        else
            printf '%s\n' "$abs" >> "${PROJECTS_FILE}"
            echo "✓ 已加入: $abs"
        fi
    done
}

apply() {
    local init_args=()
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --all) : ;; # compatibility; every installed project is checked safely
            --no-force) : ;; # retained compatibility alias; safe update never forces local content
            --no-openspec) init_args+=(--no-openspec) ;;
            --) echo "✗ 安全更新不接受 openspec-auto install 透传参数；请直接使用 update。" >&2; return 1 ;;
            *) echo "✗ 未知选项: $1"; usage ;;
        esac
        shift
    done
    local dir harness commit done_count=0 failed=""
    while IFS= read -r dir; do
        [ -d "$dir" ] || continue
        harness="$(version_field "$dir" harness)"
        [ -n "$harness" ] || continue
        commit="$(version_field "$dir" source-commit)"
        echo "============================================"
        echo "  刷新 ${dir}（${harness} ${commit} → ${CURRENT_COMMIT}）"
        echo "============================================"
        # 单个项目失败不中断批量：记下来最后一起报，其余项目照常刷新
        if HARNESS_CMD_NAME="$harness" bash "${ROOT_DIR}/scripts/harness-init.sh" "$harness" update "$dir" "${init_args[@]+"${init_args[@]}"}"; then
            done_count=$((done_count + 1))
        else
            failed="${failed}${dir}
"
        fi
    done <<EOF
$(list_projects)
EOF
    printf '\n已刷新 %d 个项目；各项目备份位置见上方输出。\n' "$done_count"
    if [ -n "$failed" ]; then
        printf '\n✗ 以下项目刷新失败（看上方对应输出）：\n%s' "$failed"
        return 1
    fi
}

case "${1:-}" in
    "") report ;;
    add) shift; add_projects "$@" ;;
    apply) shift; apply "$@" ;;
    -h|--help) usage 0 ;;
    *) echo "✗ 未知子命令: $1"; usage ;;
esac
