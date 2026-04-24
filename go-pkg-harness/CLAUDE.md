# CLAUDE.md

> Go 扩展包（第三方库）开发专用。Claude Code 每次对话自动加载。

## 强制加载

**每次对话必须加载 go-pkg-harness skill 并遵守全部规则。**

## 项目性质

这是一个 **Go 扩展包**（供其他项目引用的第三方库），不是业务服务。
库代码标准比业务代码更高——你写的每一行都会被别人依赖。

- **Go 1.26**，使用所有现代特性
- **零外部依赖优先**，JSON 场景除外；必须引入第三方时优先用 `github.com/gtkit/*`
- **JSON 必须用 `github.com/gtkit/json` 或 `github.com/gtkit/json/v2`，禁止 `encoding/json`**
- 规范文档在 `.harness/guides/`
- 错误记忆在 `.harness/error-journal.md`

## 行为底线

1. 禁止编造——不确定的标准库 API 不写
2. 禁止自由发挥——只写要求的功能
3. 禁止跳过检查——每次交付附合规摘要
4. 库代码零容忍——不留 TODO、不留 panic、不留未处理的 error
5. 多解陈列——指令存在多种合理解释时，并列呈现给用户选择，不默默择一
6. 反推更简方案——发现比用户原方案更简单的做法，主动提出并说明权衡，不默默按原方案堆代码
7. 量化自检——写完自问"senior 会不会觉得过度复杂？200 行能否压到 50 行？"；库 API 对外暴露面能小则小，单次使用的内部代码不写抽象 / 配置项 / 扩展点

## 外科式修改（Surgical Changes）

每一行 diff 必须能追溯到用户的本次请求。库代码的 diff 粒度比业务代码更严——导出面积不可因顺手扩大。

- **不顺手改**：相邻无关代码、注释、格式、命名、import 顺序一律不动
- **不重构未坏的代码**：你偏好的写法不是改动理由，匹配既有风格
- **只清自己的孤儿**：本次改动产生的未引用 import / 变量 / 函数必须清理；既有死代码发现了**提一下，别删**
- **导出面保护**：改 bug 不新增导出符号；新增导出 API 必须是用户明确要求的功能
- **边界测试**：提交前对着 diff 逐行问"这一行为什么存在？"——答不上来就删

## 可验证目标（Goal-Driven Execution）

动手前把模糊任务转成可验证目标，再编码。

**转换模板：**

| 模糊指令 | 可验证目标 |
|---------|----------|
| "加个校验" | 写非法输入表驱动测试 → 让它通过 |
| "修这个 bug" | 写复现用例测试 → 让它通过 |
| "重构 X" | 确认改前测试全绿 → 改后测试仍全绿 + benchmark 不退化 |
| "让它能跑" | 不可验证，退回用户澄清成功标准 |

**多步任务先列计划：**

    1. [步骤] → verify: [可观察的检查]
    2. [步骤] → verify: [可观察的检查]

强目标让你独立闭环；弱目标会把你和用户都拖进反复澄清循环。

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

## Git Tag 与版本发布（SemVer 强制）

Go 扩展包的依赖解析直接按 tag 走，版本号即对外契约，规则不可违背。

### 标签格式

- 正式版：`vX.Y.Z`（必须以 `v` 开头，Go Module 硬要求）
- 预发布：`vX.Y.Z-rc.N` / `vX.Y.Z-beta.N` / `vX.Y.Z-alpha.N`
- 禁止：`1.2.3`（缺 `v` 前缀）、`v1.2`（缺 PATCH）、`release-1.2.3`、`latest`

### 版本号递增规则（Semantic Versioning 2.0.0）

- **MAJOR**：不兼容的 API 变更——删除/重命名导出符号、改函数签名、改返回类型、改行为语义、改错误类型
- **MINOR**：向后兼容的新功能——新增导出 API、新增可选字段、新增 Option
- **PATCH**：向后兼容的修复——Bug 修复、文档修正、内部重构、性能优化

### v0.x.y 与 v2+ 特殊规则

- `v0.x.y`：开发期不做兼容性承诺，但破坏性变更至少升 MINOR，便于下游识别
- `v1.0.0`：宣告稳定，此后严格遵守 SemVer，MAJOR 不可回退
- `v2.0.0` 及以上：`go.mod` 的 module path 必须带 `/v2`、`/v3` 后缀，且仓库需通过子目录（`v2/`）或分支提供该 major 版本（Go Module 规则）

### 打 tag 前必须通过

```bash
go vet ./...
golangci-lint run ./...
go test -race -count=1 -timeout=5m ./...
go test -bench=. -benchmem -count=3 ./...
go test -coverprofile=coverage.out ./...
```

并确认：

- `CHANGELOG.md` 已追加本版本条目
- 变更已合并到主干分支（一般是 `main`）
- 破坏性变更已在 CHANGELOG 和 tag message 中明确标注
- 所有导出 API 的 GoDoc 与 Example 测试齐全

### Tag 操作规范

- 必须使用附注标签：`git tag -a vX.Y.Z -m "..."`
- 禁止轻量标签（不带 `-a`）
- Tag message 使用简体中文
- 禁止重命名、删除或强制覆盖已推送的 tag——下游可能已缓存
- 发错版本时，打新 tag 修复（如 `v1.2.4`），不回滚旧 tag

### Tag Message 模板

```text
版本 vX.Y.Z

主要变更：
- feat: 新增 xxx
- fix: 修复 xxx

破坏性变更（如有）：
- BREAKING CHANGE: xxx 已删除，请使用 yyy 替代

相关 Issue：#123, #124
```

## 敏感信息与 .gitignore 安全基线

### 禁止入库（零容忍）

- 环境变量文件：`.env`、`.env.local`、`.env.production` 等
- 密钥文件：`*.pem`、`*.key`、`id_rsa`、`secrets.*`、`credentials.*`
- 带真实密钥的配置文件（`config.*.yml`、`application.properties` 含密钥版本等）
- 云服务凭据：AWS / 阿里云 / 腾讯云 AccessKey、Service Account JSON
- 系统 / IDE 产物：`.DS_Store`、`.idea/`、`.vscode/`（除非团队共享）
- 构建 / 测试产物：`dist/`、`build/`、`bin/`、`coverage/`、`*.log`

### 代码内禁止硬编码

- API Key、密码、Token、私钥、JWT Secret、Session Secret、加密 Salt 一律从环境变量或密钥管理服务读取
- 本地开发用 `.env.example` 提供占位符，真实值放 `.env`（不入库）
- 日志禁止打印完整密钥，必要时脱敏（如 `sk-****abcd`、`Bearer ****`）
- 返回给调用方的错误信息必须过滤敏感字段
- 测试禁止使用真实密钥，用 mock / fixture 替代
- **库代码额外约束**：导出 API 参数/返回值禁止包含明文密钥；文档与 Example 使用占位符

### .gitignore 必备条目

    .env
    .env.*
    !.env.example
    *.pem
    *.key
    secrets.*
    credentials.*
    .DS_Store
    .idea/
    bin/
    dist/
    build/
    coverage/
    coverage.out
    *.log

### 事故响应

- 发现敏感信息已入库：**立即吊销该密钥**，再从 Git 历史清除（`git filter-repo` / BFG）
- 已推送到远端的密钥视作"已泄露"，不可靠删除掩盖
- 事件记录到 `.harness/error-journal.md`，避免重蹈覆辙

## CHANGELOG 规范（Keep a Changelog）

根目录维护 `CHANGELOG.md`，遵循 [Keep a Changelog 1.1.0](https://keepachangelog.com/zh-CN/1.1.0/) 格式。**与 Git Tag 规范强绑定：发版必须先更新 CHANGELOG，再打 tag。**

### 区段结构（示例）

    # Changelog

    ## [Unreleased]

    ### Added
    ### Changed
    ### Deprecated
    ### Removed
    ### Fixed
    ### Security

    ## [1.2.0] - 2026-04-17

    ### Added
    - 新增 `WithTimeout` Option，用于配置请求超时（#123）

    ### Fixed
    - 修复并发场景下 `Client.Do` 可能 panic 的问题（#124）

### 变更类别

- **Added** 新功能
- **Changed** 现有功能的变更
- **Deprecated** 即将移除的功能
- **Removed** 已移除的功能
- **Fixed** Bug 修复
- **Security** 安全相关修复

### 写作约束

- 语言：简体中文
- 视角：站在下游用户 / 调用方角度描述，不写实现细节
- 粒度：一条一件事，对应一个 PR 或一组强相关 commit
- 关联：条目尾部附 Issue / PR 链接，如 `（#123）`
- 禁止写入：`refactor xxx`、`bump version`、`update deps` 等内部动作

### 维护纪律

- 每个 PR 合并主干时，同步更新 `[Unreleased]` 区段
- 发版时：将 `[Unreleased]` 内容剪切到新版本区段，附日期（`YYYY-MM-DD`），Unreleased 清空
- 破坏性变更在对应版本条目顶部用 **⚠ 破坏性变更** 标注，并与 tag message 的 `BREAKING CHANGE:` 描述保持一致
