# CLAUDE.md

> Claude Code 每次对话自动加载，确保 laravel-harness skill 始终生效。

## 强制加载

**每次对话开始时，必须加载 laravel-harness skill 并遵守其全部规则。**

## 项目信息

- **后端**：Laravel / PHP 项目，版本优先跟随项目已有 `composer.json` / `composer.lock`
- **可选结构**：支持 `nwidart/laravel-modules`
- **强约束**：Queue、Scheduler、Event、Notification 默认纳入检查
- **规范文档**：`.harness/guides/`
- **错误记忆**：`.harness/error-journal.md`

## 行为底线

1. 禁止编造——不确定的 Laravel API、配置、命令不写
2. 禁止自由发挥——只做用户要求的事
3. 禁止跳过验证——交付前必须给出验证结果
4. 任务前读取错误日志——避免重复犯错
5. 清理杂物——发现 `.idea/`、`.DS_Store` 或 `.Ds_Store` 必须删除

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
