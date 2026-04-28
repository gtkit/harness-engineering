#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_DIR="$(pwd)"
FORCE_GUIDES="${HARNESS_FORCE_GUIDES:-0}"
FORCE_PROJECT_FILES="${HARNESS_FORCE_PROJECT_FILES:-0}"
ERROR_JOURNAL_RUNTIME_DIR="${HARNESS_ROOT}/scripts/error-journal"

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
echo "  laravel-harness 安装"
echo "============================================"
echo ""
echo "  脚本位置:  ${SCRIPT_DIR}"
echo "  项目目录:  ${PROJECT_DIR}"
echo ""

if [ ! -d "${SCRIPT_DIR}/guides" ]; then
    echo "✗ 错误: 找不到 ${SCRIPT_DIR}/guides/ 目录"
    exit 1
fi

if [ ! -d "${ERROR_JOURNAL_RUNTIME_DIR}" ]; then
    echo "✗ 错误: 找不到 ${ERROR_JOURNAL_RUNTIME_DIR}"
    exit 1
fi

if [ ! -f "${SCRIPT_DIR}/SKILL.codex.md" ]; then
    echo "✗ 错误: 找不到 ${SCRIPT_DIR}/SKILL.codex.md"
    exit 1
fi

echo "--------------------------------------------"
echo "[Step 1] 安装全局 Skill"
echo "--------------------------------------------"
echo ""

CLAUDE_SKILL_DIR="${HOME}/.claude/skills/laravel-harness"
mkdir -p "${CLAUDE_SKILL_DIR}"
cp "${SCRIPT_DIR}/SKILL.md" "${CLAUDE_SKILL_DIR}/SKILL.md"
echo "  ✓ ${CLAUDE_SKILL_DIR}/SKILL.md"

CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
CODEX_SKILL_DIR="${CODEX_HOME}/skills/laravel-harness"
mkdir -p "${CODEX_SKILL_DIR}"
cp "${SCRIPT_DIR}/SKILL.codex.md" "${CODEX_SKILL_DIR}/SKILL.md"
echo "  ✓ ${CODEX_SKILL_DIR}/SKILL.md"

echo ""
echo "--------------------------------------------"
echo "[Step 2] 安装项目级文件"
echo "--------------------------------------------"
echo ""

if [ "${FORCE_PROJECT_FILES}" = "1" ] || [ ! -f "${PROJECT_DIR}/CLAUDE.md" ]; then
    cp "${SCRIPT_DIR}/CLAUDE.md" "${PROJECT_DIR}/CLAUDE.md"
    if [ "${FORCE_PROJECT_FILES}" = "1" ]; then
        echo "  ✓ CLAUDE.md（已刷新）"
    else
        echo "  ✓ CLAUDE.md"
    fi
else
    echo "  ⊘ CLAUDE.md 已存在，跳过"
fi

if [ "${FORCE_PROJECT_FILES}" = "1" ] || [ ! -f "${PROJECT_DIR}/AGENTS.md" ]; then
    cp "${SCRIPT_DIR}/AGENTS.md" "${PROJECT_DIR}/AGENTS.md"
    if [ "${FORCE_PROJECT_FILES}" = "1" ]; then
        echo "  ✓ AGENTS.md（已刷新）"
    else
        echo "  ✓ AGENTS.md"
    fi
else
    echo "  ⊘ AGENTS.md 已存在，跳过"
fi

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

mkdir -p "${PROJECT_DIR}/.harness/scripts"
RUNTIME_COPIED=0
RUNTIME_PRESERVED=0
for f in "${ERROR_JOURNAL_RUNTIME_DIR}/"*; do
    filename="$(basename "$f")"
    dest="${PROJECT_DIR}/.harness/scripts/${filename}"
    if [ "${FORCE_PROJECT_FILES}" = "1" ] || [ ! -f "$dest" ]; then
        cp "$f" "$dest"
        RUNTIME_COPIED=$((RUNTIME_COPIED + 1))
    else
        RUNTIME_PRESERVED=$((RUNTIME_PRESERVED + 1))
    fi
done
if [ "${FORCE_PROJECT_FILES}" = "1" ]; then
    echo "  ✓ .harness/scripts/ — 已刷新 ${RUNTIME_COPIED} 个 runtime 脚本"
else
    echo "  ✓ .harness/scripts/ — 新增 ${RUNTIME_COPIED} 个，保留 ${RUNTIME_PRESERVED} 个"
fi

if [ ! -f "${PROJECT_DIR}/.harness/error-journal.md" ]; then
    cp "${SCRIPT_DIR}/guides/error-journal-template.md" "${PROJECT_DIR}/.harness/error-journal.md"
    echo "  ✓ .harness/error-journal.md"
else
    echo "  ⊘ .harness/error-journal.md 已存在，保留现有记录"
fi

echo ""
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
    "findings.md"
    "progress.md"
    "task_plan.md"
    ".harness/error-journal.md"
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
echo "============================================"
echo "  安装完成"
echo "============================================"
echo ""
echo "  全局 Skill："
echo "    ~/.claude/skills/laravel-harness/SKILL.md"
echo "    ~/.codex/skills/laravel-harness/SKILL.md"
echo ""
echo "  项目文件："
echo "    ${PROJECT_DIR}/"
echo "    ├── CLAUDE.md"
echo "    ├── AGENTS.md"
echo "    └── .harness/"
echo "        ├── error-journal.md"
echo "        ├── guides/"
echo "            ├── architecture.md"
echo "            ├── http-and-api.md"
echo "            ├── data-and-eloquent.md"
echo "            ├── queues-events-scheduling.md"
echo "            ├── notifications-and-mail.md"
echo "            ├── testing-and-validation.md"
echo "            ├── laravel-modules.md"
echo "            └── review-checklist.md"
echo "        └── scripts/"
echo "            ├── read-error-journal.sh"
echo "            ├── append-error-journal.sh"
echo "            ├── read-error-journal.ps1"
echo "            └── append-error-journal.ps1"
echo ""
