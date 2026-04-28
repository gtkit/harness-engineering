#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-write}"

MODULES=(
    "go-harness"
    "fullstack-harness"
    "go-pkg-harness"
    "laravel-harness"
    "laravel-fullstack-harness"
)

render_claude_file() {
    local agents_path="$1"

    cat <<'EOF'
# CLAUDE.md

> Claude Code 项目级完整规则入口。
> 为避免依赖全局厚 skill，本文件承载完整项目规则；与 `AGENTS.md` 应保持同级完整。

---
EOF

    awk 'started { print } /^## / && !started { started = 1; print }' "$agents_path"
}

check_mode() {
    local module="$1"
    local agents_path="${ROOT_DIR}/${module}/AGENTS.md"
    local claude_path="${ROOT_DIR}/${module}/CLAUDE.md"
    local tmp_file

    tmp_file="$(mktemp)"
    render_claude_file "$agents_path" > "$tmp_file"

    if ! cmp -s "$tmp_file" "$claude_path"; then
        printf 'CLAUDE sync mismatch: %s\n' "$module" >&2
        diff -u "$claude_path" "$tmp_file" || true
        rm -f "$tmp_file"
        return 1
    fi

    rm -f "$tmp_file"
}

write_mode() {
    local module="$1"
    local agents_path="${ROOT_DIR}/${module}/AGENTS.md"
    local claude_path="${ROOT_DIR}/${module}/CLAUDE.md"
    local tmp_file

    tmp_file="$(mktemp)"
    render_claude_file "$agents_path" > "$tmp_file"
    mv "$tmp_file" "$claude_path"
}

case "$MODE" in
    --check)
        for module in "${MODULES[@]}"; do
            check_mode "$module"
        done
        ;;
    write)
        for module in "${MODULES[@]}"; do
            write_mode "$module"
        done
        ;;
    *)
        printf 'Usage: %s [--check]\n' "$0" >&2
        exit 1
        ;;
esac
