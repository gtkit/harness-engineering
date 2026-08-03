#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# go-pkg-harness 安装脚本（macOS / Linux）
# Go 扩展包 / 第三方库开发专用
#
# 用法：
#   cd /path/to/your-project
#   bash /path/to/harness-engineering/go-pkg-harness/setup.sh
#
# 实际逻辑在共享库 scripts/install-harness.sh，本文件只做入口装配。
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=../scripts/install-harness.sh
. "${SCRIPT_DIR}/../scripts/install-harness.sh"

install_go_pkg_project_files() {
    local template_dir="$1"
    local project_dir
    project_dir="$(pwd)"
    local force_project_files="${HARNESS_FORCE_PROJECT_FILES:-0}"

    if [ ! -d "${template_dir}" ]; then
        echo "✗ 错误: 找不到 ${template_dir} 目录"
        exit 1
    fi
    if [ ! -f "${template_dir}/Makefile" ]; then
        echo "✗ 错误: 找不到 ${template_dir}/Makefile"
        exit 1
    fi
    if [ ! -f "${template_dir}/version.go.tmpl" ]; then
        echo "✗ 错误: 找不到 ${template_dir}/version.go.tmpl"
        exit 1
    fi

    echo "--------------------------------------------"
    echo "[go-pkg] 生成库项目文件"
    echo "--------------------------------------------"
    echo ""

    if [ "${force_project_files}" = "1" ] || [ ! -s "${project_dir}/Makefile" ]; then
        cp "${template_dir}/Makefile" "${project_dir}/Makefile"
        if [ "${force_project_files}" = "1" ]; then
            echo "  ✓ Makefile（已刷新）"
        elif [ -f "${project_dir}/Makefile" ]; then
            echo "  ✓ Makefile（已写入模板内容）"
        else
            echo "  ✓ Makefile"
        fi
    else
        echo "  ⊘ Makefile 已存在，跳过"
    fi

    local dir_name
    local package_name
    local package_note
    dir_name="$(basename "${project_dir}")"
    # package 名优先沿用目录内既有 .go 文件（同目录 package 名必须一致，否则编译失败）；
    # 目录里没有其它 Go 文件时按目录名推导，横线直接去掉（lenovo-pay → lenovopay）
    package_name="$(_go_pkg_existing_package "${project_dir}")"
    if [ -n "${package_name}" ]; then
        package_note="，沿用目录内既有 package 名"
    else
        package_name="${dir_name//-/}"
        package_note=""
        if [ "${package_name}" != "${dir_name}" ]; then
            package_note="，目录名的横线已去掉"
        fi
        if [[ ! "${package_name}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || _go_pkg_is_keyword "${package_name}"; then
            echo "  ! version.go 未生成：目录名 ${dir_name} 无法转成合法 Go package 名"
            echo ""
            return 0
        fi
    fi

    if [ "${force_project_files}" = "1" ] || [ ! -s "${project_dir}/version.go" ]; then
        sed "s/{{PACKAGE_NAME}}/${package_name}/g" "${template_dir}/version.go.tmpl" > "${project_dir}/version.go"
        if [ "${force_project_files}" = "1" ]; then
            echo "  ✓ version.go（package ${package_name}${package_note}，已刷新）"
        elif [ -f "${project_dir}/version.go" ]; then
            echo "  ✓ version.go（package ${package_name}${package_note}，已写入模板内容）"
        else
            echo "  ✓ version.go（package ${package_name}${package_note}）"
        fi
    else
        echo "  ⊘ version.go 已存在，跳过"
    fi
    echo ""
}

# 取目录内既有 .go 文件声明的 package 名（version.go 自身与测试文件除外），没有则输出空
_go_pkg_existing_package() {
    local project_dir="$1"
    local go_file
    local base_name
    local declared

    for go_file in "${project_dir}"/*.go; do
        [ -f "${go_file}" ] || continue
        base_name="$(basename "${go_file}")"
        case "${base_name}" in
            version.go|*_test.go)
                continue
                ;;
        esac
        declared="$(sed -n -E 's/^package[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/p' "${go_file}" | head -n1)"
        if [ -n "${declared}" ]; then
            printf '%s' "${declared}"
            return 0
        fi
    done
    return 0
}

_go_pkg_is_keyword() {
    case "$1" in
        break|default|func|interface|select|case|defer|go|map|struct|chan|else|goto|package|switch|const|fallthrough|if|range|type|continue|for|import|return|var)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

install_harness "go-pkg-harness" "go-pkg-harness" "${SCRIPT_DIR}"
install_go_pkg_project_files "${SCRIPT_DIR}/project-templates"
