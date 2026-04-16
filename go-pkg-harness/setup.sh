#!/bin/bash
set -euo pipefail

# ============================================================
# go-pkg-harness 安装脚本（macOS / Linux）
# Go 扩展包（第三方库）开发专用
#
# 用法：
#   cd /path/to/your-go-package
#   bash /path/to/setup.sh
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(pwd)"

echo ""
echo "============================================"
echo "  go-pkg-harness 安装"
echo "  Go 扩展包开发专用"
echo "============================================"
echo ""
echo "  脚本位置:  ${SCRIPT_DIR}"
echo "  项目目录:  ${PROJECT_DIR}"
echo ""

if [ ! -d "${SCRIPT_DIR}/guides" ]; then
    echo "✗ 错误: 找不到 ${SCRIPT_DIR}/guides/"
    exit 1
fi

# ==========================================================
# Step 1: 全局 Skill
# ==========================================================

echo "--------------------------------------------"
echo "[Step 1] 安装全局 Skill"
echo "--------------------------------------------"
echo ""

# Claude Code
CLAUDE_SKILL_DIR="${HOME}/.claude/skills/go-pkg-harness"
mkdir -p "${CLAUDE_SKILL_DIR}"
cp "${SCRIPT_DIR}/SKILL.md" "${CLAUDE_SKILL_DIR}/SKILL.md"
echo "  ✓ ~/.claude/skills/go-pkg-harness/SKILL.md"

# Codex
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
CODEX_SKILL_DIR="${CODEX_HOME}/skills/go-pkg-harness"
mkdir -p "${CODEX_SKILL_DIR}"
cat > "${CODEX_SKILL_DIR}/SKILL.md" << 'EOF'
---
name: go-pkg-harness
description: Go 扩展包开发专用 Harness skill。包结构、Functional Options、GoDoc、Example 测试、Benchmark、泛型、API 兼容性。所有 Go 包/库开发任务都应触发。
---

# Go Package Harness Skill

完整规则在项目根目录 AGENTS.md。
专项规范在 .harness/guides/。
EOF
echo "  ✓ ~/.codex/skills/go-pkg-harness/SKILL.md"

echo ""

# ==========================================================
# Step 2: 项目级文件
# ==========================================================

echo "--------------------------------------------"
echo "[Step 2] 安装项目级文件"
echo "--------------------------------------------"
echo ""

# CLAUDE.md
if [ ! -f "${PROJECT_DIR}/CLAUDE.md" ]; then
    cp "${SCRIPT_DIR}/CLAUDE.md" "${PROJECT_DIR}/CLAUDE.md"
    echo "  ✓ CLAUDE.md"
else
    echo "  ⊘ CLAUDE.md 已存在，跳过"
fi

# AGENTS.md
if [ ! -f "${PROJECT_DIR}/AGENTS.md" ]; then
    cp "${SCRIPT_DIR}/AGENTS.md" "${PROJECT_DIR}/AGENTS.md"
    echo "  ✓ AGENTS.md"
else
    echo "  ⊘ AGENTS.md 已存在，跳过"
fi

# .harness/guides/
mkdir -p "${PROJECT_DIR}/.harness/guides"
for f in "${SCRIPT_DIR}/guides/"*.md; do
    filename="$(basename "$f")"
    if [ "$filename" = "error-journal-template.md" ]; then
        continue
    fi
    cp "$f" "${PROJECT_DIR}/.harness/guides/${filename}"
done
GUIDE_COUNT=$(ls "${PROJECT_DIR}/.harness/guides/"*.md 2>/dev/null | wc -l | tr -d ' ')
echo "  ✓ .harness/guides/ — ${GUIDE_COUNT} 个规范文档"

# error-journal
if [ ! -f "${PROJECT_DIR}/.harness/error-journal.md" ]; then
    cp "${SCRIPT_DIR}/guides/error-journal-template.md" "${PROJECT_DIR}/.harness/error-journal.md"
    echo "  ✓ .harness/error-journal.md"
else
    echo "  ⊘ .harness/error-journal.md 已存在，保留"
fi

echo ""

# ==========================================================
# Step 3: .gitignore
# ==========================================================

echo "--------------------------------------------"
echo "[Step 3] 更新 .gitignore"
echo "--------------------------------------------"
echo ""

if [ -f "${PROJECT_DIR}/.gitignore" ]; then
    if ! grep -q "error-journal.md" "${PROJECT_DIR}/.gitignore" 2>/dev/null; then
        printf '\n# Harness: Agent 错误记忆\n.harness/error-journal.md\n' >> "${PROJECT_DIR}/.gitignore"
        echo "  ✓ .gitignore 已更新"
    else
        echo "  ⊘ .gitignore 已包含相关规则"
    fi
else
    echo "  ⊘ 无 .gitignore，跳过"
fi

echo ""

# ==========================================================
# 完成
# ==========================================================

echo "============================================"
echo "  安装完成"
echo "============================================"
echo ""
echo "  ${PROJECT_DIR}/"
echo "  ├── CLAUDE.md"
echo "  ├── AGENTS.md"
echo "  └── .harness/"
echo "      ├── error-journal.md"
echo "      └── guides/"
echo "          ├── pkg-structure.md     包结构、接口、Options"
echo "          ├── pkg-errors.md        错误体系"
echo "          ├── pkg-testing.md       测试、Benchmark、Example"
echo "          ├── pkg-docs.md          GoDoc、README、CHANGELOG"
echo "          ├── pkg-generics.md      泛型应用"
echo "          └── pkg-review.md        包级审查清单"
echo ""
