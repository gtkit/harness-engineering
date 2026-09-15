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
#   harness-refresh apply [--no-openspec] [-- <openspec-auto install 额外参数>]
#                                   # 对清单里所有落后的项目执行 <harness> <dir> --force
#   harness-refresh apply --all ... # 不管是否落后，全部执行
#   harness-refresh apply --no-force ...
#                                   # 不强刷：只补缺失文件、修复只剩托管块的入口文件，本地改动一律保留
#
# 报告只读 .harness/VERSION，不碰项目文件。apply 每次覆盖前先把该项目的 CLAUDE.md、AGENTS.md、
# .harness/guides/ 备份到 ~/.config/harness-engineering/backups/<UTC 时间戳>/<项目名>/——这些文件
# 在 .git/info/exclude 里不入库，覆盖后没有别的地方能找回。
# ============================================================

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECTS_FILE="${HARNESS_PROJECTS_FILE:-${HOME}/.config/harness-engineering/projects.txt}"
CURRENT_COMMIT="$(git -C "${ROOT_DIR}" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"

usage() {
    echo "用法: harness-refresh | harness-refresh add <dir>... | harness-refresh apply [--all] [--no-force] [--no-openspec] [-- <openspec-auto 参数>]"
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

# 备份一个项目里会被覆盖的本地文件；输出备份目录
backup_project() {
    local dir="$1" name="$2" stamp="$3"
    local dest="${HOME}/.config/harness-engineering/backups/${stamp}/${name}"
    mkdir -p "$dest"
    local f
    for f in CLAUDE.md AGENTS.md; do
        [ -f "${dir}/${f}" ] && cp "${dir}/${f}" "${dest}/${f}"
    done
    [ -d "${dir}/.harness/guides" ] && cp -R "${dir}/.harness/guides" "${dest}/guides"
    printf '%s\n' "$dest"
}

apply() {
    local all=0 force=1
    local init_args=()
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --all) all=1 ;;
            --no-force) force=0 ;;
            --no-openspec) init_args+=(--no-openspec) ;;
            --) shift; init_args+=(-- "$@"); break ;;
            *) echo "✗ 未知选项: $1"; usage ;;
        esac
        shift
    done
    [ "$force" = 1 ] && init_args=(--force "${init_args[@]+"${init_args[@]}"}")
    local stamp
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    local dir harness commit backup done_count=0 failed=""
    while IFS= read -r dir; do
        [ -d "$dir" ] || continue
        harness="$(version_field "$dir" harness)"
        [ -n "$harness" ] || continue
        commit="$(version_field "$dir" source-commit)"
        if [ "$all" = 0 ] && [ "$commit" = "${CURRENT_COMMIT}" ]; then
            continue
        fi
        backup="$(backup_project "$dir" "$(basename "$dir")" "$stamp")"
        echo "============================================"
        echo "  刷新 ${dir}（${harness} ${commit} → ${CURRENT_COMMIT}）"
        echo "  备份：${backup}"
        echo "============================================"
        # 单个项目失败不中断批量：记下来最后一起报，其余项目照常刷新
        if HARNESS_CMD_NAME="$harness" bash "${ROOT_DIR}/scripts/harness-init.sh" "$harness" "$dir" "${init_args[@]+"${init_args[@]}"}"; then
            done_count=$((done_count + 1))
        else
            failed="${failed}${dir}
"
        fi
    done <<EOF
$(list_projects)
EOF
    printf '\n已刷新 %d 个项目；覆盖前的本地文件在 %s/.config/harness-engineering/backups/%s/\n' "$done_count" "$HOME" "$stamp"
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
