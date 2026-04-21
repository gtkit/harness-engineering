# AGENTS.md

> 本项目使用 Go 1.26 + Gin + GORM + github.com/gtkit/* 开发企业级 Web 服务。
> 以下规则适用于所有 Codex 任务，不可跳过。

---

## 行为纪律（铁律）

1. **禁止编造**：不确定的 API、包名、函数签名不写。不确定就说"我不确定，请确认"。
2. **禁止猜测**：不说"应该支持"、"大概是"。不确定的库版本/特性不写。
3. **严格按结构输出**：只做用户要求的事，不附加"你可能还需要"等扩展内容。
4. **不扩展无关内容**：用户要一个 handler，就只写 handler + 必要 DTO，不自动生成 model、migration。
5. **清理杂物**：发现项目中有 `.idea/`、`.DS_Store` 或误写的 `.Ds_Store`，必须删除并保持工作区干净。
6. **多解陈列**：指令存在多种合理解释时，并列呈现给用户选择，不默默择一实现。
7. **反推更简方案**：发现比用户原方案更简单的做法时，主动提出并说明权衡，不默默按原方案堆代码。
8. **量化自检**：写完自问"senior 会不会觉得过度复杂？200 行能否压到 50 行？"——答"是"就重写；单次使用的代码不写抽象 / 配置项 / 扩展点。

## 技术栈

- Go 1.26（使用所有现代特性：range-over-func、slices/maps/cmp、iterator 等）
- JSON 编解码统一使用 `github.com/gtkit/json` 或 `github.com/gtkit/json/v2`，禁止 `encoding/json`
- 依赖使用最新稳定版，不用 RC/Beta
- 已有 go.mod 的项目遵循已锁定版本

## Logic 思维链（每个任务四步走完）

**Step 1 理解需求**：逐字阅读指令，有歧义立即提问，不假设。

**Step 2 提取关键信息**：识别涉及模块和外部交互，阅读对应规范文档：
- 新增 API → 读 `.harness/guides/architecture.md` + `.harness/guides/api-conventions.md`
- 数据库操作 → 读 `.harness/guides/db-patterns.md`
- 对接大模型 → 读 `.harness/guides/llm-integration.md`
- 支付模块 → 读 `.harness/guides/payment.md`
- 写扩展包 → 读 `.harness/guides/pkg-design.md`
- 所有代码任务 → `.harness/guides/architecture.md` 始终生效

**Step 3 按结构组织**：严格按分层架构和模板编写，不自创模式。

**Step 4 检查合规**：运行传感器 + 自审 + 交叉验证（见下文）。

## 外科式修改（Surgical Changes）

每一行 diff 必须能追溯到用户的本次请求。

- **不顺手改**：相邻无关代码、注释、格式、命名、import 顺序一律不动
- **不重构未坏的代码**：你偏好的写法不是改动理由，匹配既有风格
- **只清自己的孤儿**：本次改动产生的未引用 import / 变量 / 函数必须清理；既有死代码发现了**提一下，别删**
- **边界测试**：提交前对着 diff 逐行问"这一行为什么存在？"——答不上来就删

## 可验证目标（Goal-Driven Execution）

动手前把模糊任务转成可验证目标，再编码。

**转换模板：**

| 模糊指令 | 可验证目标 |
|---------|----------|
| "加个校验" | 写非法输入 table-driven 测试 → 让它通过 |
| "修这个 bug" | 写复现用例测试 → 让它通过 |
| "重构 X" | 确认改前测试全绿 → 改后测试仍全绿 |
| "让它能跑" | 不可验证，退回用户澄清成功标准 |

**多步任务先列计划：**

    1. [步骤] → verify: [可观察的检查]
    2. [步骤] → verify: [可观察的检查]

强目标让你独立闭环；弱目标会把你和用户都拖进反复澄清循环。

## 分层架构（不可逾越）

```
handler（绑定参数 + 校验 + 调 service + 返回响应）
   ↓
service（业务编排 + 调 repo + 调外部服务）
   ↓
repository（GORM 数据访问，一表一 repo）
```

**禁止：**
- handler 导入 `gorm.io/gorm` 或 repository
- service 导入 `github.com/gin-gonic/gin`
- repository 导入 gin
- `pkg/` 导入 `internal/`

## 编码基线

- context.Context 全链路透传
- 错误用 `fmt.Errorf("xxx: %w", err)` 包装，用 `errors.Is`/`errors.As` 判断
- JSON 编解码统一使用 `github.com/gtkit/json` 或 `github.com/gtkit/json/v2`
- 所有外部调用设超时
- 敏感信息禁止硬编码
- 命名：mixedCaps、包名小写、接口 -er 结尾
- 优先使用 slices、maps、cmp 标准库新包

## 提交前必须运行的检查

```bash
golangci-lint run ./...
go vet ./...
go test -race -count=1 -timeout=5m ./...
```

所有检查通过后才能提交。lint 或测试失败时自行修复。

## 架构边界检查

提交前确认：
- handler 没有 import gorm ✓
- service 没有 import gin ✓
- pkg/ 没有 import internal/ ✓
- 无硬编码密钥 ✓

## 测试标准（企业生产级）

- 单元测试覆盖率 ≥ 80%
- 每个测试函数必须 table-driven：`[]struct{ name; input; want; wantErr }`
- 必须覆盖 success + error + edge case 三类
- mock 通过接口注入
- 有共享状态的代码加 `-race` 测试

## 交叉验证（每次交付前）

1. **代码 ↔ 需求**：逐条核对，不多不少
2. **代码 ↔ 测试**：每个公开方法有对应测试
3. **代码 ↔ 文档**：GoDoc 注释与行为一致
4. **新代码 ↔ 存量代码**：不破坏已有测试

## 隐患排查

- 资源泄漏：resp.Body/事务/goroutine/文件句柄 是否正确关闭
- 数据一致性：跨表操作是否在事务中、缓存一致性策略
- 稳定性：panic recovery、外部依赖降级、限流
- 安全：输入长度限制、文件上传校验、权限最小化

## 合规摘要

每次交付代码时附上：

```
## 合规检查摘要
- [x] Go 1.26 现代特性
- [x] 分层架构
- [x] 错误处理
- [x] 并发安全
- [x] 超时控制
- [x] 无硬编码敏感信息
- [x] 资源泄漏检查
- [x] 测试覆盖
- [x] 交叉验证
- [x] 无编造内容
```

## 错误记忆

如果项目中存在 `.harness/error-journal.md`，每次任务开始前先读取，避免重蹈覆辙。
当用户纠正你的输出时，将错误追加到 `.harness/error-journal.md`，格式：

```markdown
## YYYY-MM-DD: [错误类别]
**错误描述**：...
**根因分析**：...
**正确做法**：...
**受影响范围**：...
```

## 详细规范文档位置

各专项 Guide 在 `.harness/guides/` 目录下，按需读取：

| 文件 | 覆盖范围 |
|-----|---------|
| architecture.md | 分层、依赖方向、注入 |
| api-conventions.md | 响应格式、Handler 流程、错误码 |
| db-patterns.md | Repository、GORM、事务 |
| llm-integration.md | Provider 接口、SSE、重试降级 |
| payment.md | 幂等、验签、对账 |
| pkg-design.md | Functional Options、GoDoc |
| review-checklist.md | 12 维度自审清单 |

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

## 敏感信息与 .gitignore 安全基线

### 禁止入库（零容忍）

- 环境变量文件：`.env`、`.env.local`、`.env.production` 等
- 密钥文件：`*.pem`、`*.key`、`id_rsa`、`secrets.*`、`credentials.*`
- 带真实密钥的配置文件（`config.*.yml`、`application.properties` 含密钥版本等）
- 云服务凭据：AWS / 阿里云 / 腾讯云 AccessKey、Service Account JSON
- 系统 / IDE 产物：`.DS_Store`、`.idea/`、`.vscode/`（除非团队共享）
- 构建 / 测试产物：`dist/`、`build/`、`coverage/`、`*.log`

### 代码内禁止硬编码

- API Key、密码、Token、私钥、JWT Secret、Session Secret、加密 Salt 一律从环境变量或密钥管理服务读取
- 本地开发用 `.env.example` 提供占位符，真实值放 `.env`（不入库）
- 日志禁止打印完整密钥，必要时脱敏（如 `sk-****abcd`、`Bearer ****`）
- 返回给客户端的错误信息、响应体必须过滤敏感字段
- 测试禁止使用真实密钥，用 mock / fixture 替代

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
    dist/
    build/
    coverage/
    *.log

各技术栈按需补齐（Go `bin/`、Node `node_modules/`、PHP `vendor/` 等）。

### 事故响应

- 发现敏感信息已入库：**立即吊销该密钥**，再从 Git 历史清除（`git filter-repo` / BFG）
- 已推送到远端的密钥视作"已泄露"，不可靠删除掩盖
- 事件记录到 `.harness/error-journal.md`，避免重蹈覆辙

## CHANGELOG 规范（Keep a Changelog）

根目录维护 `CHANGELOG.md`，遵循 [Keep a Changelog 1.1.0](https://keepachangelog.com/zh-CN/1.1.0/) 格式。

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
    - 新增用户导出 API（支持 CSV / Excel 格式）

    ### Fixed
    - 修复移动端登录页面显示异常

### 变更类别

- **Added** 新功能
- **Changed** 现有功能的变更
- **Deprecated** 即将移除的功能
- **Removed** 已移除的功能
- **Fixed** Bug 修复
- **Security** 安全相关修复

### 写作约束

- 语言：简体中文
- 视角：站在下游用户 / 消费者角度描述，不写实现细节
- 粒度：一条一件事，对应一个 PR 或一组强相关 commit
- 关联：条目尾部附 Issue / PR 链接，如 `（#123）`
- 禁止写入：`refactor xxx`、`bump version`、`update deps` 等内部动作

### 维护纪律

- 每个 PR 合并主干时，同步更新 `[Unreleased]` 区段
- 发版时：将 `[Unreleased]` 内容剪切到新版本区段，附日期（`YYYY-MM-DD`），Unreleased 清空
- 破坏性变更在对应版本条目顶部用 **⚠ 破坏性变更** 标注
