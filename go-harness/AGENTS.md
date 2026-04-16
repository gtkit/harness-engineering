# AGENTS.md

> 本项目使用 Go 1.26.2 + Gin + GORM + github.com/gtkit/* 开发企业级 Web 服务。
> 以下规则适用于所有 Codex 任务，不可跳过。

---

## 行为纪律（铁律）

1. **禁止编造**：不确定的 API、包名、函数签名不写。不确定就说"我不确定，请确认"。
2. **禁止猜测**：不说"应该支持"、"大概是"。不确定的库版本/特性不写。
3. **严格按结构输出**：只做用户要求的事，不附加"你可能还需要"等扩展内容。
4. **不扩展无关内容**：用户要一个 handler，就只写 handler + 必要 DTO，不自动生成 model、migration。
5. **清理杂物**：发现项目中有 `.idea/`、`.DS_Store` 或误写的 `.Ds_Store`，必须删除并保持工作区干净。

## 技术栈

- Go 1.26.2（使用所有现代特性：range-over-func、slices/maps/cmp、iterator 等）
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
- [x] Go 1.26.2 现代特性
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
