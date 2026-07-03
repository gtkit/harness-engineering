#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# go-grpc-harness 脚手架:从 templates/grpc-service 生成新项目骨架
#
# 用法:
#   bash /path/to/harness-engineering/go-grpc-harness/scaffold.sh <module-name> <target-dir>
#   例: bash go-grpc-harness/scaffold.sh my-order-service ~/go/src/Project/my-order-service
#
# 三条护栏:
#   1. 只对新项目生效:目标目录存在 go.mod / cmd / internal 任一即拒绝
#      (存量项目只能装规则,用 setup.sh);
#   2. 绝不覆盖:任何目标文件已存在即中止;
#   3. 末尾自动调 setup.sh 装规则(CLAUDE.md/AGENTS.md/.harness/),
#      规则与骨架同版本交付。
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/templates/grpc-service"
TEMPLATE_MODULE="example-grpc-service"

usage() {
    echo "用法: scaffold.sh <module-name> <target-dir>"
    echo "  module-name: 新项目的 go module 名(如 my-order-service 或 github.com/org/svc)"
    echo "  target-dir : 目标目录(不存在则创建;必须是空目录或不含 Go 工程痕迹)"
    exit 1
}

[ "$#" -eq 2 ] || usage
MODULE_NAME="$1"
TARGET_DIR="$2"

if [ ! -d "${TEMPLATE_DIR}" ]; then
    echo "✗ 错误: 找不到模板目录 ${TEMPLATE_DIR}"
    exit 1
fi
case "${MODULE_NAME}" in
    *[!a-zA-Z0-9./_-]*|"")
        echo "✗ 错误: module 名含非法字符: ${MODULE_NAME}"
        exit 1
        ;;
esac

mkdir -p "${TARGET_DIR}"
TARGET_DIR="$(cd "${TARGET_DIR}" && pwd)"

# ---------- 护栏 1: 只对新项目生效 ----------
for marker in go.mod cmd internal; do
    if [ -e "${TARGET_DIR}/${marker}" ]; then
        echo "✗ 拒绝: ${TARGET_DIR} 已存在 ${marker} —— 目标像是存量项目。"
        echo "  存量项目只能安装规则: bash ${SCRIPT_DIR}/setup.sh"
        exit 1
    fi
done

# ---------- 护栏 2: 绝不覆盖 ----------
conflict=0
while IFS= read -r f; do
    rel="${f#"${TEMPLATE_DIR}"/}"
    if [ -e "${TARGET_DIR}/${rel}" ]; then
        echo "✗ 目标文件已存在: ${rel}"
        conflict=1
    fi
done < <(find "${TEMPLATE_DIR}" -type f ! -name '.DS_Store')
if [ "${conflict}" -ne 0 ]; then
    echo "✗ 拒绝: 存在文件冲突,不做任何写入。"
    exit 1
fi

echo ""
echo "============================================"
echo "  go-grpc-harness 脚手架"
echo "============================================"
echo ""
echo "  模板:      ${TEMPLATE_DIR}"
echo "  目标:      ${TARGET_DIR}"
echo "  module:    ${MODULE_NAME}"
echo ""

# ---------- 复制模板 ----------
(cd "${TEMPLATE_DIR}" && find . -type f ! -name '.DS_Store' ! -path './bin/*' ! -path './.proto-deps/*' -print0 |
    while IFS= read -r -d '' f; do
        dest="${TARGET_DIR}/${f#./}"
        mkdir -p "$(dirname "${dest}")"
        cp "${f}" "${dest}"
    done)
echo "  ✓ 模板文件已复制"

# ---------- module 名替换(go 源码 / go.mod / proto / yaml) ----------
# 注意排除 pb/:生成产物里的序列化 descriptor 含长度前缀的 go_package 字符串,
# 文本替换会破坏长度前缀导致 proto 注册 panic。descriptor 里的旧字符串运行时无用
# (仅供 codegen);用户换业务域后 make gen 会按已替换的 proto 正确重生。
escaped_module="$(printf '%s' "${MODULE_NAME}" | sed 's/[\/&]/\\&/g')"
_scaffold_sed_targets() {
    find "${TARGET_DIR}" -type f ! -path "${TARGET_DIR}/pb/*" \
        \( -name '*.go' -o -name 'go.mod' -o -name '*.proto' -o -name '*.yaml' -o -name '*.yml' -o -name 'Makefile' -o -name '*.md' \) -print0
}
if sed --version >/dev/null 2>&1; then
    _scaffold_sed_targets | xargs -0 sed -i "s|${TEMPLATE_MODULE}|${escaped_module}|g"      # GNU sed(Linux)
else
    _scaffold_sed_targets | xargs -0 sed -i '' "s|${TEMPLATE_MODULE}|${escaped_module}|g"   # BSD sed(macOS)
fi
echo "  ✓ module 名已替换: ${TEMPLATE_MODULE} → ${MODULE_NAME}(pb/ 产物不替换,make gen 重生)"

chmod +x "${TARGET_DIR}/scripts/"*.sh

# pb 产物按新 module 名重生(descriptor 里的 go_package 与 proto 同步,proto-check 直接可过);
# 本机没有 buf 时模板 pb 仍可构建运行,首次 make gen 后完全同步。
if command -v buf >/dev/null 2>&1; then
    if (cd "${TARGET_DIR}" && buf generate); then
        echo "  ✓ pb/ 已按新 module 名重新生成"
    else
        echo "  ⚠ buf generate 失败:pb/ 暂为模板产物(可构建),稍后手动 make gen"
    fi
else
    echo "  ⚠ 未检测到 buf:pb/ 暂为模板产物(可构建),安装工具链后 make gen 同步"
fi
echo ""

# ---------- 护栏 3 / 规则安装 ----------
echo "--------------------------------------------"
echo "  安装 harness 规则(setup.sh)"
echo "--------------------------------------------"
(cd "${TARGET_DIR}" && bash "${SCRIPT_DIR}/setup.sh")

echo ""
echo "============================================"
echo "  脚手架完成"
echo "============================================"
echo ""
echo "  下一步(见 ${TARGET_DIR}/README.md 的 TODO 清单):"
echo "    cd ${TARGET_DIR}"
echo "    bash scripts/install-proto-tools.sh   # 如未装 buf 工具链"
echo "    go mod tidy && make check             # 验收全绿再开工"
echo "    cp config/env/env.yml.example config/env/env.yml"
echo ""
