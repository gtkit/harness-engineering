#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 一条命令完成新项目初始化：harness 规则 + openspec-auto 工作流（macOS / Linux）
#
# 由 install.sh 生成的包装命令（go-harness / go-pkg-harness / ...）调用本脚本，
# 也可以直接执行：
#   bash scripts/harness-init.sh <harness> [project-dir] [选项] [-- <openspec-auto install 额外参数>]
#
#   <harness>      go-harness | go-grpc-harness | fullstack-harness | go-pkg-harness
#                  | laravel-harness | laravel-fullstack-harness | openresty-harness
#   [project-dir]  目标项目目录，缺省为当前目录；不存在则创建
#
# 选项：
#   --no-openspec          只装 harness，不接 openspec-auto
#   --force                强制刷新 CLAUDE.md / AGENTS.md / skills / rules / 运行脚本与 guides，
#                          并把 --force 传给 openspec-auto install
#   --force-project-files  只强制刷新 CLAUDE.md / AGENTS.md / skills / rules / 运行脚本
#   --force-guides         只强制刷新 .harness/guides/
#   --version              打印本仓库当前的 commit / tag
#   -- ...                 其后参数原样传给 openspec-auto install（如 --skip-codex-user-config）
#
# 顺序固定为 harness → openspec-auto：harness 整文件写入 CLAUDE.md / AGENTS.md，
# openspec-auto 再往这两个文件追加托管块；反过来 harness 会把入口文件判为"与模板不同"而跳过。
#
# openspec-auto 的查找顺序：
#   $OPENSPEC_AUTO_BIN → openspec-auto-bootstrap 仓库目录（$OPENSPEC_AUTO_BOOTSTRAP_DIR，
#   缺省为本仓库同级的 ../openspec-auto-bootstrap）→ PATH 上的 openspec-auto
# 三者都是直接运行仓库里的 sh 脚本，改了仓库即生效。
# ============================================================

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
    local d
    echo "用法: ${HARNESS_CMD_NAME:-harness-init.sh <harness>} [project-dir] [--no-openspec] [--force] [--force-project-files] [--force-guides] [-- <openspec-auto install 额外参数>]"
    if [ -z "${HARNESS_CMD_NAME:-}" ]; then
        echo ""
        echo "可用 harness："
        for d in "${ROOT_DIR}"/*/; do
            [ -f "${d}setup.sh" ] && echo "  $(basename "${d}")"
        done
    fi
    echo ""
    echo "go-grpc-harness 的全新项目可先用 go-grpc-harness/scaffold.sh 生成骨架，再用本命令接 openspec-auto。"
    exit "${1:-1}"
}

HARNESS="${1:-}"
[ -n "${HARNESS}" ] || usage
shift
SETUP="${ROOT_DIR}/${HARNESS}/setup.sh"
if [ ! -f "${SETUP}" ]; then
    echo "✗ 未知 harness: ${HARNESS}"
    usage
fi

PROJECT_DIR=""
WITH_OPENSPEC=1
FORCE_PROJECT_FILES=0
FORCE_GUIDES=0
OPENSPEC_ARGS=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --no-openspec) WITH_OPENSPEC=0 ;;
        --force) FORCE_PROJECT_FILES=1; FORCE_GUIDES=1 ;;
        --force-project-files) FORCE_PROJECT_FILES=1 ;;
        --force-guides) FORCE_GUIDES=1 ;;
        --version)
            git -C "${ROOT_DIR}" describe --tags --always --dirty 2>/dev/null || echo unknown
            exit 0
            ;;
        -h|--help) usage 0 ;;
        --)
            shift
            OPENSPEC_ARGS=("$@")
            break
            ;;
        -*) echo "✗ 未知选项: $1"; usage ;;
        *)
            if [ -n "${PROJECT_DIR}" ]; then
                echo "✗ 多余的参数: $1"; usage
            fi
            PROJECT_DIR="$1"
            ;;
    esac
    shift
done

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
    HARNESS_FORCE_PROJECT_FILES="${FORCE_PROJECT_FILES}" HARNESS_FORCE_GUIDES="${FORCE_GUIDES}" bash "${SETUP}"
)

[ "${WITH_OPENSPEC}" = 1 ] || exit 0

# ---------- Step 2: openspec-auto ----------
echo "============================================"
echo "  openspec-auto 安装"
echo "============================================"

RUNNER=()
RUNNER_NOTE=""
BOOTSTRAP_DIR="${OPENSPEC_AUTO_BOOTSTRAP_DIR:-${ROOT_DIR}/../openspec-auto-bootstrap}"
if [ -n "${OPENSPEC_AUTO_BIN:-}" ] && [ -x "${OPENSPEC_AUTO_BIN}" ]; then
    RUNNER=("${OPENSPEC_AUTO_BIN}" install)
    RUNNER_NOTE="OPENSPEC_AUTO_BIN"
elif [ -f "${BOOTSTRAP_DIR}/install.sh" ]; then
    RUNNER=(bash "${BOOTSTRAP_DIR}/install.sh")
    RUNNER_NOTE="仓库目录 $(cd "${BOOTSTRAP_DIR}" && pwd)"
elif command -v openspec-auto >/dev/null 2>&1; then
    RUNNER=("$(command -v openspec-auto)" install)
    RUNNER_NOTE="PATH 上的 openspec-auto，版本 $("${RUNNER[0]}" version 2>/dev/null || echo unknown)"
fi
if [ "${#RUNNER[@]}" -eq 0 ]; then
    echo "✗ harness 已装好，但找不到 openspec-auto。任选一种后重跑，或加 --no-openspec："
    echo "    git clone git@github.com:gtkit/openspec-auto-bootstrap.git $(cd "${ROOT_DIR}/.." && pwd)/openspec-auto-bootstrap"
    echo "    export OPENSPEC_AUTO_BIN=/path/to/openspec-auto"
    echo "    export OPENSPEC_AUTO_BOOTSTRAP_DIR=/path/to/openspec-auto-bootstrap"
    exit 1
fi

if [ "${FORCE_PROJECT_FILES}" = 1 ] && [ "${FORCE_GUIDES}" = 1 ]; then
    OPENSPEC_ARGS=(--force "${OPENSPEC_ARGS[@]+"${OPENSPEC_ARGS[@]}"}")
fi
echo "  运行器：${RUNNER_NOTE}"
"${RUNNER[@]}" "${OPENSPEC_ARGS[@]+"${OPENSPEC_ARGS[@]}"}" "${PROJECT_DIR}"

echo ""
echo "============================================"
echo "  初始化完成：${PROJECT_DIR}"
echo "============================================"
echo "  harness:       $(sed -n 's/^source-tag: //p' "${PROJECT_DIR}/.harness/VERSION" 2>/dev/null || true) (${HARNESS}, commit $(sed -n 's/^source-commit: //p' "${PROJECT_DIR}/.harness/VERSION" 2>/dev/null || echo unknown))"
echo "  openspec-auto: $(cat "${PROJECT_DIR}/.openspec-auto/version" 2>/dev/null || echo unknown)"
echo "  在项目根目录打开 Claude Code / Codex，直接描述需求即可；诊断用 /harness-doctor（Codex 用 \$harness-doctor）。"
