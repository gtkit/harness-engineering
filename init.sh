#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 一条命令完成新项目初始化：harness 规则 + openspec-auto 工作流（macOS / Linux）
#
# 用法：
#   bash /path/to/harness-engineering/init.sh <harness> [project-dir] [选项] [-- <openspec-auto install 额外参数>]
#
#   <harness>      go-harness | go-grpc-harness | fullstack-harness | go-pkg-harness
#                  | laravel-harness | laravel-fullstack-harness
#   [project-dir]  目标项目目录，缺省为当前目录；不存在则创建
#
# 选项：
#   --no-openspec  只装 harness，不接 openspec-auto
#   --force        harness 强制刷新 CLAUDE.md / AGENTS.md / guides / 运行脚本，
#                  并把 --force 传给 openspec-auto install
#   -- ...         其后参数原样传给 openspec-auto install（如 --skip-codex-user-config）
#
# 顺序固定为 harness → openspec-auto：harness 整文件写入 CLAUDE.md / AGENTS.md，
# openspec-auto 再往这两个文件追加托管块；反过来会让 harness 判定入口文件"与模板不同"而跳过。
#
# openspec-auto 的查找顺序：$OPENSPEC_AUTO_BIN → PATH 上的 openspec-auto
#   → $OPENSPEC_AUTO_BOOTSTRAP_DIR/install.sh → 本仓库同级目录 ../openspec-auto-bootstrap/install.sh
# ============================================================

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    local d
    echo "用法: bash ${0} <harness> [project-dir] [--no-openspec] [--force] [-- <openspec-auto install 额外参数>]"
    echo ""
    echo "可用 harness："
    for d in "${ROOT_DIR}"/*/; do
        [ -f "${d}setup.sh" ] && echo "  $(basename "${d}")"
    done
    echo ""
    echo "go-grpc-harness 的全新项目可先用 go-grpc-harness/scaffold.sh 生成骨架，再用本脚本接 openspec-auto。"
    exit 1
}

HARNESS=""
PROJECT_DIR=""
WITH_OPENSPEC=1
FORCE=0
OPENSPEC_ARGS=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --no-openspec) WITH_OPENSPEC=0 ;;
        --force) FORCE=1 ;;
        -h|--help) usage ;;
        --)
            shift
            OPENSPEC_ARGS=("$@")
            break
            ;;
        -*) echo "✗ 未知选项: $1"; usage ;;
        *)
            if [ -z "${HARNESS}" ]; then
                HARNESS="$1"
            elif [ -z "${PROJECT_DIR}" ]; then
                PROJECT_DIR="$1"
            else
                echo "✗ 多余的参数: $1"; usage
            fi
            ;;
    esac
    shift
done

[ -n "${HARNESS}" ] || usage
SETUP="${ROOT_DIR}/${HARNESS}/setup.sh"
if [ ! -f "${SETUP}" ]; then
    echo "✗ 未知 harness: ${HARNESS}"
    usage
fi

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
mkdir -p "${PROJECT_DIR}"
PROJECT_DIR="$(cd "${PROJECT_DIR}" && pwd)"

echo "============================================"
echo "  项目初始化：${HARNESS} $([ "${WITH_OPENSPEC}" = 1 ] && echo '+ openspec-auto')"
echo "  项目目录：${PROJECT_DIR}"
echo "============================================"

# harness 与 openspec-auto 的忽略规则都写在 .git/info/exclude，目标必须是 git 仓库
if ! git -C "${PROJECT_DIR}" rev-parse --git-dir >/dev/null 2>&1; then
    git init -q "${PROJECT_DIR}"
    echo "  ✓ 已 git init（忽略规则要写进 .git/info/exclude）"
fi

# ---------- Step 1: harness ----------
(
    cd "${PROJECT_DIR}"
    if [ "${FORCE}" = 1 ]; then
        HARNESS_FORCE_PROJECT_FILES=1 HARNESS_FORCE_GUIDES=1 bash "${SETUP}"
    else
        bash "${SETUP}"
    fi
)

[ "${WITH_OPENSPEC}" = 1 ] || exit 0

# ---------- Step 2: openspec-auto ----------
echo "============================================"
echo "  openspec-auto 安装"
echo "============================================"

RUNNER=()
if [ -n "${OPENSPEC_AUTO_BIN:-}" ] && [ -x "${OPENSPEC_AUTO_BIN}" ]; then
    RUNNER=("${OPENSPEC_AUTO_BIN}" install)
elif command -v openspec-auto >/dev/null 2>&1; then
    RUNNER=("$(command -v openspec-auto)" install)
else
    BOOTSTRAP_DIR="${OPENSPEC_AUTO_BOOTSTRAP_DIR:-${ROOT_DIR}/../openspec-auto-bootstrap}"
    if [ -f "${BOOTSTRAP_DIR}/install.sh" ]; then
        RUNNER=(bash "${BOOTSTRAP_DIR}/install.sh")
    fi
fi

if [ "${#RUNNER[@]}" -eq 0 ]; then
    echo "✗ harness 已装好，但找不到 openspec-auto。任选一种后重跑本脚本，或加 --no-openspec："
    echo "    go install github.com/gtkit/openspec-auto-bootstrap/cmd/openspec-auto@latest"
    echo "    export OPENSPEC_AUTO_BIN=/path/to/openspec-auto"
    echo "    export OPENSPEC_AUTO_BOOTSTRAP_DIR=/path/to/openspec-auto-bootstrap"
    exit 1
fi

if [ "${FORCE}" = 1 ]; then
    OPENSPEC_ARGS=(--force "${OPENSPEC_ARGS[@]+"${OPENSPEC_ARGS[@]}"}")
fi
echo "  运行器：${RUNNER[*]}"
"${RUNNER[@]}" "${OPENSPEC_ARGS[@]+"${OPENSPEC_ARGS[@]}"}" "${PROJECT_DIR}"

echo ""
echo "============================================"
echo "  初始化完成：${PROJECT_DIR}"
echo "============================================"
echo "  harness:       $(sed -n 's/^source-tag: //p' "${PROJECT_DIR}/.harness/VERSION" 2>/dev/null || true) (${HARNESS})"
echo "  openspec-auto: $(cat "${PROJECT_DIR}/.openspec-auto/version" 2>/dev/null || echo unknown)"
echo "  在项目根目录打开 Claude Code / Codex，直接描述需求即可；诊断用 /harness:doctor。"
