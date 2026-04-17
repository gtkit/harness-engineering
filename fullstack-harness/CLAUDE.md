# CLAUDE.md

> Claude Code 每次对话自动加载，fullstack-harness skill 始终生效。

## 强制加载

**每次对话必须加载 fullstack-harness skill 并遵守全部规则。**
无论任务多简单，只要涉及本项目代码（Go 或 Vue），所有规则生效。

## 项目信息

- **后端**：Go 1.26.2 + Gin + GORM + gtkit — 代码在 `backend/`
- **前端**：Vue 3 + Vite + TypeScript + Pinia — 代码在 `frontend/`
- **JSON**：后端统一使用 `github.com/gtkit/json` 或 `github.com/gtkit/json/v2`
- **规范文档**：`.harness/guides/`（唯一来源）
- **错误记忆**：`.harness/error-journal.md`（每次任务前读取）

## 行为底线

1. 禁止编造——不确定就问
2. 禁止自由发挥——只做要求的事
3. 禁止跳过检查——每次交付附合规摘要
4. Logic 四步走完——理解 → 提取 → 组织 → 合规
5. 前后端不混——后端任务不自动补前端，反之亦然
6. 清理杂物——发现 `.idea/`、`.DS_Store` 或 `.Ds_Store` 必须删除

## 沟通与提交规范

### 沟通语言

**与用户的所有对话必须使用简体中文**，包括解释、确认、进度汇报、错误说明。

### Commit 规范（强制）

- 格式：`<类型>(<范围>): <标题>`，必要时附正文和页脚
- 语言：Header / Body / Footer 全部使用简体中文
- 类型：`feat` | `fix` | `docs` | `style` | `refactor` | `perf` | `test` | `chore` | `ci` | `revert`
- 标题：祈使句、现在时态（用"添加"而非"添加了"），结尾不加句号
- 范围：尽可能具体（如 `auth`、`ui`、`api`），不确定可省略括号
- 正文：仅在需要解释"为什么"时添加，说明动机而非实现
- 页脚：关联 Issue 用 `Closes #ID`；破坏性变更以 `BREAKING CHANGE:` 开头
- 输出限制：仅输出 Commit Message，不加代码块标记、不加寒暄
- 示例：
  - `fix(auth): 修复移动端登录页面显示异常`
  - `feat(cart): 添加购物车核心功能`
