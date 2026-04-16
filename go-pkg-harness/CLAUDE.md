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
