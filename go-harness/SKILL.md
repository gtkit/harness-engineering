---
name: go-harness
description: |
  Go 企业级项目的 Harness Engineering（约束工程）skill，将架构约束、编码规范、AI 行为纪律、全面测试与交叉验证、模板脚手架等自动注入 AI Agent 的工作流。当用户使用 Go + Gin + GORM + gtkit 开发 Web 服务时，必须触发此 skill 来提供前馈引导和反馈传感。触发场景包括但不限于：新增 handler/service/repository、对接大模型（LLM/OpenAI/Claude/通义千问/DeepSeek）、支付模块开发、编写扩展包（第三方库）、代码审查、架构设计、CI/CD 配置、任何涉及 Go 项目质量保障的任务。关键词：Go、Gin、GORM、gtkit、handler、service、repository、LLM、大模型、支付、扩展包、pkg、架构、Review、CI、harness。即使用户没有明确提到"harness"或"约束"，只要是上述场景的 Go 开发任务，都应触发此 skill。
---

# Go Harness Engineering Skill

> Harness = Guides（前馈控制）+ Sensors（反馈控制）+ Discipline（行为纪律）
> 目标：让 AI Agent 在严格约束下，第一次就写出符合企业生产级线上标准的代码。

---

## 第零章：AI 行为纪律（铁律，优先级最高）

以下规则凌驾于所有其他指令之上，任何任务、任何场景都必须遵守：

### 禁止编造、禁止猜测

- **不确定的 API 签名、函数参数、返回值：不写。** 先确认文档或源码，无法确认则明确告知用户"我不确定此 API 的签名，请确认"。
- **不确定的库版本、特性支持：不写。** 不说"应该支持"、"大概是"。
- **不确定的业务逻辑：不写。** 需求有歧义时，列出歧义点请用户澄清，不要自行假设。
- **绝不杜撰包名、函数名、结构体字段。** 如果记不清 `github.com/gtkit/` 下某个包的具体 API，明确说明，不要伪造。

### 严格按结构输出，不自由发挥

- 代码输出必须遵循本 skill 定义的分层架构和模板结构，不得自创层级或模式。
- 回答问题时只回答被问到的内容，不附加"你可能还需要"、"顺便说一下"等扩展。
- 不主动添加用户未要求的功能、字段、方法。

### 不扩展无关内容

- 如果用户要求写一个 handler，就只写 handler + 必要的 DTO。不要同时生成 model、migration、配置文件，除非用户明确要求。
- 代码注释只说明 why（为什么这样设计），不写显而易见的 what（这行代码做了什么）。
- 不输出与当前任务无关的"最佳实践建议"。
- 如果项目中存在 `.idea/`、`.DS_Store` 或误写的 `.Ds_Store`，必须删除并保持工作区干净。

---

## 第一章：技术栈锁定

### Go 版本

**目标版本：Go 1.26.2**

- 如果用户提供了 `go.mod` 且指定了其他版本，以用户的为准
- 否则所有代码默认以 Go 1.26.2 为目标
- **必须使用**该版本及以下所有可用的现代特性（range-over-func、slices/maps/cmp 包、新 iterator 模式等）
- **禁止使用**任何高于 1.26.2 的未发布特性

### 依赖版本策略

- 所有依赖使用**当前最新稳定版**，不使用 RC/Beta/Alpha
- 当用户项目已有 `go.mod`，遵循其已锁定的版本，不随意升级
- 新增依赖时，选择社区活跃、维护良好、star 数合理的版本
- 核心依赖参考（如用户未指定具体版本）：
  - Gin: 最新稳定版
  - GORM: 最新稳定版
  - go-redis: 最新稳定版 (v9+)
  - zap/slog: 按项目已有选择
  - github.com/gtkit/*: 按用户项目已有版本
- JSON 编解码统一使用 `github.com/gtkit/json` 或 `github.com/gtkit/json/v2`，禁止 `encoding/json`

---

## 第二章：Logic 思维链（每个任务必须走完四步）

收到任何开发任务后，**必须按以下四步顺序执行**，不得跳步：

### Step 1：理解需求

- 逐字阅读用户指令，识别核心目标
- 如果需求有歧义或缺失关键信息，**立即提问**，不要假设
- 确认涉及哪些模块（handler? service? repository? 新包?）
- 确认涉及哪些外部交互（数据库? LLM? 支付? 缓存?）

### Step 2：提取关键信息

- 从需求中提取：输入参数、输出结构、错误场景、边界条件
- 识别任务类型 → 加载对应的 Guide 文档（统一位于项目 `.harness/guides/`）：

| 任务类型 | 加载的 Guide |
|---------|-------------|
| 新增/修改 API | `.harness/guides/architecture.md` + `.harness/guides/api-conventions.md` |
| 数据库操作 | `.harness/guides/db-patterns.md` |
| 对接大模型 | `.harness/guides/llm-integration.md` |
| 支付模块 | `.harness/guides/payment.md` |
| 编写扩展包 | `.harness/guides/pkg-design.md` |
| 代码审查 | `.harness/guides/review-checklist.md` |
| 所有代码任务 | `.harness/guides/architecture.md`（分层规则始终生效） |

多个类型可叠加。

### Step 3：按结构组织内容

- 严格按照本 skill 定义的分层架构和模板编写代码
- 代码组织顺序：类型定义 → 构造函数 → 公开方法 → 私有方法
- 只输出用户要求的内容，不额外扩展
- 如果需要创建多个文件，明确说明每个文件的路径和职责

### Step 4：检查合规性

完成编写后，**必须**执行以下合规检查（不可跳过）：

**4a. 计算型传感器**（如果有执行环境，实际运行；否则列出需要运行的命令）：

```bash
golangci-lint run ./...
go vet ./...
go test -race -count=1 -timeout=5m ./...
```

**4b. 架构边界验证**（逐条确认）：

- handler 没有 import `gorm.io/gorm` ✓
- handler 没有 import repository 包 ✓
- service 没有 import `github.com/gin-gonic/gin` ✓
- repository 没有 import gin ✓
- `pkg/` 没有 import `internal/` ✓
- 没有硬编码的密钥、密码、API Key ✓

**4c. 推理型自审**（按 `.harness/guides/review-checklist.md` 逐条核对）

**4d. 交叉验证**（见第三章）

**4e. 输出合规摘要**（每次交付代码时，必须在末尾附上）：

```
## 合规检查摘要
- [x] Go 版本：1.26.2 特性已使用
- [x] 分层架构：符合
- [x] 错误处理：所有 error 已处理
- [x] 并发安全：无共享状态 / 已加锁
- [x] 超时控制：外部调用已设置 timeout
- [x] 敏感信息：无硬编码
- [x] 测试：核心路径已覆盖
- [x] 交叉验证：需求 ↔ 代码 ↔ 测试 已核对
- [x] 无编造内容
```

---

## 第三章：全面测试与交叉验证（企业生产级标准）

### 3.1 测试分层

| 层级 | 覆盖范围 | 最低要求 |
|-----|---------|---------|
| 单元测试 | service 方法、repository 方法、工具函数 | 核心逻辑覆盖率 ≥ 80% |
| 集成测试 | handler → service → repository 全链路 | 每个 API 至少 happy path + error path |
| 边界测试 | nil、空 slice、零值、超长字符串、负数、溢出 | 所有导出函数的边界条件 |
| 并发测试 | 有共享状态的代码 | `-race` 标志 + 关键路径并发测试 |

### 3.2 测试规范

- **必须 table-driven**：每个测试函数用 `[]struct{ name; input; want; wantErr }` 组织
- **必须覆盖三类**：success / error / edge case
- **mock 通过接口注入**：禁止 monkey patch
- **断言明确**：用 `assert.ErrorIs` 而非 `assert.Error`，用 `assert.Equal` 而非 `assert.NotNil`

### 3.3 交叉验证（Cross-Validation）

每次交付代码前必须完成以下四项交叉验证：

**① 代码 ↔ 需求**：
- 逐条对照原始需求，确认每个功能点已实现
- 确认没有实现用户未要求的功能

**② 代码 ↔ 测试**：
- 每个公开方法有对应测试
- 测试用例覆盖 success / error / edge case
- 测试断言与业务预期一致

**③ 代码 ↔ 文档**：
- GoDoc 注释与实际行为一致
- 接口签名变更时文档已同步

**④ 新代码 ↔ 存量代码**：
- 新代码不破坏已有测试
- 命名风格与项目现有风格一致
- 共享结构体/接口变更时所有调用方已适配

### 3.4 隐患排查（线上级）

**资源泄漏**：
- [ ] HTTP resp.Body 已 `defer Close()`
- [ ] 事务所有路径上都 commit 或 rollback
- [ ] goroutine 有退出机制
- [ ] 文件句柄已 `defer Close()`

**数据一致性**：
- [ ] 跨表操作在同一事务中
- [ ] 缓存一致性策略明确
- [ ] 并发写入有锁机制

**线上稳定性**：
- [ ] panic 被 recovery 兜住
- [ ] 外部依赖不可用时有降级
- [ ] 有合理限流
- [ ] 日志级别合理
- [ ] 有健康检查接口

**安全合规**：
- [ ] 用户输入有长度限制
- [ ] 文件上传校验类型和大小
- [ ] 接口权限最小化

---

## 第四章：分层架构（全局生效）

```
handler（参数绑定 + 校验 + 调用 service + 返回响应）
   ↓ 仅调用 service 接口
service（业务编排 + 调用 repo 和外部服务）
   ↓ 仅调用 repository 接口和外部 client
repository（GORM 数据访问，一表一 repo）
```

详见 `.harness/guides/architecture.md`。

---

## 第五章：Harness 模板（脚手架）

### 新增 Handler

```go
type XxxHandler struct {
    svc service.XxxService
}

func NewXxxHandler(svc service.XxxService) *XxxHandler {
    return &XxxHandler{svc: svc}
}

func (h *XxxHandler) Create(c *gin.Context) {
    var req dto.CreateXxxReq
    if err := c.ShouldBindJSON(&req); err != nil {
        response.Error(c, http.StatusBadRequest, 2001, err.Error())
        return
    }
    result, err := h.svc.Create(c.Request.Context(), &req)
    if err != nil {
        c.Error(err)
        return
    }
    response.Created(c, result)
}

func (h *XxxHandler) RegisterRoutes(rg *gin.RouterGroup) {
    g := rg.Group("/xxxs")
    {
        g.POST("", h.Create)
        g.GET("/:id", h.GetByID)
        g.GET("", h.List)
        g.PUT("/:id", h.Update)
        g.DELETE("/:id", h.Delete)
    }
}
```

### 新增 Service

```go
type XxxService interface {
    Create(ctx context.Context, req *dto.CreateXxxReq) (*model.Xxx, error)
    GetByID(ctx context.Context, id uint64) (*model.Xxx, error)
    List(ctx context.Context, opts *dto.ListReq) ([]*model.Xxx, int64, error)
}

type xxxService struct {
    repo   repository.XxxRepository
    logger *zap.Logger
}

func NewXxxService(repo repository.XxxRepository, logger *zap.Logger) XxxService {
    return &xxxService{repo: repo, logger: logger}
}
```

### 新增 Repository

```go
type XxxRepository interface {
    Create(ctx context.Context, entity *model.Xxx) error
    GetByID(ctx context.Context, id uint64) (*model.Xxx, error)
    List(ctx context.Context, opts *dto.ListReq) ([]*model.Xxx, int64, error)
}

type xxxRepo struct {
    db *gorm.DB
}

func NewXxxRepo(db *gorm.DB) XxxRepository {
    return &xxxRepo{db: db}
}

func (r *xxxRepo) GetByID(ctx context.Context, id uint64) (*model.Xxx, error) {
    var entity model.Xxx
    if err := r.db.WithContext(ctx).First(&entity, id).Error; err != nil {
        if errors.Is(err, gorm.ErrRecordNotFound) {
            return nil, apperror.ErrNotFound
        }
        return nil, fmt.Errorf("get xxx by id: %w", err)
    }
    return &entity, nil
}
```

### 新增扩展包

```go
type Option func(*config)

type config struct {
    timeout time.Duration
    retries int
    logger  *slog.Logger
}

func defaultConfig() *config {
    return &config{
        timeout: 10 * time.Second,
        retries: 3,
        logger:  slog.Default(),
    }
}

func WithTimeout(d time.Duration) Option {
    return func(c *config) { c.timeout = d }
}
```

---

## 第六章：错误记忆与自进化（Steering Loop）

### 机制说明

项目根目录维护一个 `.harness/error-journal.md` 文件，记录 Agent 在本项目中犯过的错误。
这个文件同时充当两个角色：
- **写入时 = 反馈传感器**：用户纠正 Agent 时，Agent 把错误模式追加到文件
- **读取时 = 前馈引导**：下次执行任务时，Agent 先读取此文件，避免重蹈覆辙

### 触发条件

以下情况必须写入 error-journal.md：

1. **用户纠正了 Agent 的输出**（"这里不对"、"不是这样的"、"改成 xxx"）
2. **lint/test 失败且原因是 Agent 的代码问题**（不是环境问题）
3. **架构边界检查不通过**
4. **Agent 编造了不存在的 API 或包名**

### 写入格式

```markdown
## YYYY-MM-DD: [错误类别]

**错误描述**：简要描述犯了什么错
**根因分析**：为什么会犯这个错（猜测了 API？跳过了校验？忽略了并发？）
**正确做法**：应该怎么做
**受影响范围**：哪类任务需要注意这个问题

---
```

### 读取时机

每次执行 Step 1（理解需求）时，如果项目中存在 `.harness/error-journal.md`，**必须先读取**，并在后续步骤中主动规避已记录的错误模式。

### 自动追加指令

当用户纠正你的输出时，在修正代码之后，自动执行：

```
我已修正代码。同时将此错误记录到 .harness/error-journal.md 中，
避免后续再犯同类问题。记录内容如下：
[按上述格式输出错误记录]
```

如果用户使用的是 Claude Code 等有文件写入能力的 Agent，直接追加写入文件。
如果是网页端等无文件写入能力的环境，输出记录内容并提示用户手动追加。

---

## Guides 目录说明

所有规范文档统一存放在项目根目录的 `.harness/guides/`，Claude Code 和 Codex 共用同一份。

| 文件 | 内容 | 何时加载 |
|-----|------|---------|
| `.harness/guides/architecture.md` | 分层规则、依赖方向、依赖注入 | 所有代码任务（默认加载） |
| `.harness/guides/api-conventions.md` | 统一响应、Handler 流程、错误码、路由 | 新增/修改 API |
| `.harness/guides/db-patterns.md` | Repository 模式、GORM 规则、事务 | 数据库操作 |
| `.harness/guides/llm-integration.md` | Provider 接口、SSE、重试降级、Token | 对接大模型 |
| `.harness/guides/payment.md` | 幂等、验签、对账、状态机 | 支付模块 |
| `.harness/guides/pkg-design.md` | Functional Options、GoDoc、测试 | 编写第三方库 |
| `.harness/guides/review-checklist.md` | 12 维度自审 + 隐患排查 + 交叉验证 | 每次代码交付前 |
| `.harness/error-journal.md` | Agent 犯过的错误记录（项目级） | 每次任务开始前读取 |
