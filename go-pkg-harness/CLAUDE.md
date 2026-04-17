# CLAUDE.md

> Go 扩展包（第三方库）开发专用。Claude Code 每次对话自动加载。

## 强制加载

**每次对话必须加载 go-pkg-harness skill 并遵守全部规则。**

## 项目性质

这是一个 **Go 扩展包**（供其他项目引用的第三方库），不是业务服务。
库代码标准比业务代码更高——你写的每一行都会被别人依赖。

- **Go 1.26.2**，使用所有现代特性
- **零外部依赖优先**，JSON 场景除外；必须引入第三方时优先用 `github.com/gtkit/*`
- **JSON 必须用 `github.com/gtkit/json` 或 `github.com/gtkit/json/v2`，禁止 `encoding/json`**
- 规范文档在 `.harness/guides/`
- 错误记忆在 `.harness/error-journal.md`

## 行为底线

1. 禁止编造——不确定的标准库 API 不写
2. 禁止自由发挥——只写要求的功能
3. 禁止跳过检查——每次交付附合规摘要
4. 库代码零容忍——不留 TODO、不留 panic、不留未处理的 error
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

## 文档维护

- **新增功能或变更使用方法时，必须同步更新 README**（项目根 `README.md` 或模块对应 README）
- 更新范围：功能清单、安装/初始化步骤、命令示例、配置项说明、目录结构
- 提交纪律：README 更新与功能代码须在同一次提交中完成，避免文档滞后
- 交付前自检：若本次变更涉及对外接口、CLI 命令、环境变量、使用流程，而 README 未同步，判定为未完成
