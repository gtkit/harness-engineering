#!/bin/bash
set -euo pipefail

# ============================================================
# go-harness 统一安装脚本（macOS / Linux）
#
# 用法：
#   cd /path/to/your-go-project
#   bash /path/to/go-harness-unified/setup.sh
#
# 做两件事：
#   1. 全局 Skill 装到 ~/.claude/skills/ 和 ~/.codex/skills/
#   2. 项目级文件装到当前目录
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(pwd)"
FORCE_GUIDES="${HARNESS_FORCE_GUIDES:-0}"

append_gitignore_line() {
    local file="$1"
    local line="$2"

    if ! grep -Fxq "$line" "$file" 2>/dev/null; then
        printf '%s\n' "$line" >> "$file"
        return 0
    fi
    return 1
}

echo ""
echo "============================================"
echo "  go-harness 安装"
echo "============================================"
echo ""
echo "  脚本位置:  ${SCRIPT_DIR}"
echo "  项目目录:  ${PROJECT_DIR}"
echo ""

# ---------- 检查 guides 目录 ----------

if [ ! -d "${SCRIPT_DIR}/guides" ]; then
    echo "✗ 错误: 找不到 ${SCRIPT_DIR}/guides/ 目录"
    echo "  请确认 setup.sh 和 guides/ 在同一目录下"
    exit 1
fi

# ==========================================================
# Step 1: 全局 Skill（只装一次，所有项目共享）
# ==========================================================

echo "--------------------------------------------"
echo "[Step 1] 安装全局 Skill"
echo "--------------------------------------------"
echo ""

# -- Claude Code --
CLAUDE_SKILL_DIR="${HOME}/.claude/skills/go-harness"
mkdir -p "${CLAUDE_SKILL_DIR}"
cp "${SCRIPT_DIR}/SKILL.md" "${CLAUDE_SKILL_DIR}/SKILL.md"
echo "  ✓ ${CLAUDE_SKILL_DIR}/SKILL.md"

# -- Codex --
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
CODEX_SKILL_DIR="${CODEX_HOME}/skills/go-harness"
mkdir -p "${CODEX_SKILL_DIR}"
cat > "${CODEX_SKILL_DIR}/SKILL.md" << 'CODEX_SKILL_EOF'
---
name: go-harness
description: Go 企业级 Harness Engineering skill。Go + Gin + GORM + gtkit 项目的架构约束、编码规范、测试标准、交叉验证。所有涉及 Go 代码的任务都应触发。
---

# Go Harness Skill

本 skill 的完整规则已写入项目根目录 AGENTS.md。
详细的专项规范在 .harness/guides/ 目录下。
当本 skill 被触发时，请确认已阅读 AGENTS.md 和对应的 guide 文件。
CODEX_SKILL_EOF
echo "  ✓ ${CODEX_SKILL_DIR}/SKILL.md"

echo ""

# ==========================================================
# Step 2: 项目级文件
# ==========================================================

echo "--------------------------------------------"
echo "[Step 2] 安装项目级文件到 ${PROJECT_DIR}"
echo "--------------------------------------------"
echo ""

# -- CLAUDE.md --
if [ ! -f "${PROJECT_DIR}/CLAUDE.md" ]; then
    cp "${SCRIPT_DIR}/CLAUDE.md" "${PROJECT_DIR}/CLAUDE.md"
    echo "  ✓ CLAUDE.md"
else
    echo "  ⊘ CLAUDE.md 已存在，跳过"
fi

# -- AGENTS.md --
if [ ! -f "${PROJECT_DIR}/AGENTS.md" ]; then
    cp "${SCRIPT_DIR}/AGENTS.md" "${PROJECT_DIR}/AGENTS.md"
    echo "  ✓ AGENTS.md"
else
    echo "  ⊘ AGENTS.md 已存在，跳过"
fi

# -- .harness/guides/ --
mkdir -p "${PROJECT_DIR}/.harness/guides"

GUIDE_COPIED=0
GUIDE_PRESERVED=0

for f in "${SCRIPT_DIR}/guides/"*.md; do
    filename="$(basename "$f")"
    if [ "$filename" = "error-journal-template.md" ]; then
        continue
    fi
    dest="${PROJECT_DIR}/.harness/guides/${filename}"
    if [ "${FORCE_GUIDES}" = "1" ] || [ ! -f "$dest" ]; then
        cp "$f" "$dest"
        GUIDE_COPIED=$((GUIDE_COPIED + 1))
    else
        GUIDE_PRESERVED=$((GUIDE_PRESERVED + 1))
    fi
done

GUIDE_COUNT=$(ls "${PROJECT_DIR}/.harness/guides/"*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "${FORCE_GUIDES}" = "1" ]; then
    echo "  ✓ .harness/guides/ — ${GUIDE_COUNT} 个规范文档（强制刷新 ${GUIDE_COPIED} 个）"
else
    echo "  ✓ .harness/guides/ — ${GUIDE_COUNT} 个规范文档（新增 ${GUIDE_COPIED} 个，保留 ${GUIDE_PRESERVED} 个）"
fi

# -- .harness/error-journal.md --
if [ ! -f "${PROJECT_DIR}/.harness/error-journal.md" ]; then
    cp "${SCRIPT_DIR}/guides/error-journal-template.md" "${PROJECT_DIR}/.harness/error-journal.md"
    echo "  ✓ .harness/error-journal.md"
else
    echo "  ⊘ .harness/error-journal.md 已存在，保留现有记录"
fi

echo ""

# ==========================================================
# Step 3: .gitignore
# ==========================================================

echo "--------------------------------------------"
echo "[Step 3] 更新 .gitignore"
echo "--------------------------------------------"
echo ""

GITIGNORE_FILE="${PROJECT_DIR}/.gitignore"
if [ ! -f "${GITIGNORE_FILE}" ]; then
    touch "${GITIGNORE_FILE}"
    echo "  ✓ 已创建 .gitignore"
else
    echo "  ⊘ .gitignore 已存在，继续补充规则"
fi

GITIGNORE_PATTERNS=(
    ".openspec-auto-backup/"
    ".openspec-auto/"
    ".idea/"
    ".vscode/"
    ".Ds_Store"
    ".DS_Store"
    "*.log"
    ".harness/"
    ".claude/"
    ".codex/"
    ".agents/"
    "openspec/"
    "AGENTS.md"
    "CLAUDE.md"
    "tools/"
)

GITIGNORE_UPDATED=0
if ! grep -Fq "# Harness: 本地工具与 Agent 运行产物" "${GITIGNORE_FILE}" 2>/dev/null; then
    printf '\n# Harness: 本地工具与 Agent 运行产物\n' >> "${GITIGNORE_FILE}"
    GITIGNORE_UPDATED=1
fi

for pattern in "${GITIGNORE_PATTERNS[@]}"; do
    if append_gitignore_line "${GITIGNORE_FILE}" "${pattern}"; then
        GITIGNORE_UPDATED=1
    fi
done

if [ "${GITIGNORE_UPDATED}" -eq 1 ]; then
    echo "  ✓ .gitignore 已同步 Harness 忽略规则"
else
    echo "  ⊘ .gitignore 已包含相关规则"
fi

echo ""

# ==========================================================
# 完成
# ==========================================================

echo "============================================"
echo "  安装完成"
echo "============================================"
echo ""
echo "  全局 Skill（装一次，所有项目共享）："
echo "    ~/.claude/skills/go-harness/SKILL.md"
echo "    ~/.codex/skills/go-harness/SKILL.md"
echo ""
echo "  项目文件："
echo "    ${PROJECT_DIR}/"
echo "    ├── CLAUDE.md"
echo "    ├── AGENTS.md"
echo "    └── .harness/"
echo "        ├── error-journal.md"
echo "        └── guides/"
echo "            ├── architecture.md"
echo "            ├── api-conventions.md"
echo "            ├── db-patterns.md"
echo "            ├── llm-integration.md"
echo "            ├── payment.md"
echo "            ├── pkg-design.md"
echo "            └── review-checklist.md"
echo ""
echo "  改规范只改 .harness/guides/，两个 Agent 自动同步。"
echo ""
