# CLAUDE.md

> Claude Code 项目级完整规则入口。
> 为避免依赖全局厚 skill，本文件承载完整项目规则；与 `AGENTS.md` 应保持同级完整。
> 本项目使用 Go 1.27 + grpc-go + buf + protovalidate + github.com/gtkit/* 开发企业级 gRPC 微服务。

---
## 行为纪律（铁律）

1. **禁止编造**：不确定的 API、包名、函数签名不写。不确定就说“我不确定，请确认”。
2. **禁止猜测**：不说“应该支持”“大概是”。不确定的库版本/特性不写。
3. **严格按结构输出**：只做用户要求的事，不扩展无关内容。
4. **不顺手改**：用户要一个 handler，就只写 handler + 必要映射，不自动生成 model、migration。
5. **反推更简方案**：发现更简单方案时说明权衡，但不擅自扩大实现范围。
6. **量化自检**：单次使用的代码不写抽象 / 配置项 / 扩展点；过度复杂就重写。

## 技术栈

- Go 1.27，**必须使用现代语法**：泛型方法、`errors.AsType`、`sync.WaitGroup.Go`、`new(expr)`、range-over-int / range-over-func、`slices`/`maps`/`cmp`、`omitzero` tag；落地写法与实测约束见 `.harness/guides/go-modern.md`，门禁是 `go fix -diff ./...` 无输出
- UUID 用标准库 `uuid` 包：`uuid.New()` 用于通用场景，`uuid.NewV7()` 生成时间有序 ID（适合作数据库主键）；`uuid.Nil()` 是函数不是变量，入库与 JSON 的转换约束见 `.harness/guides/go-modern.md`
- gRPC：google.golang.org/grpc + buf（v2 配置、本地 protoc-gen-* 插件）
- 参数校验：protovalidate（规则写在 proto，拦截器统一执行；运行时模块是 `buf.build/go/protovalidate`，**`github.com/bufbuild/protovalidate-go` 是已废弃旧路径，禁用**）
- DB：`github.com/gtkit/ormx`（GORM 封装：StartupPing/错误翻译/健康检查；业务层只消费 `*gorm.DB`）
- 日志：`github.com/gtkit/logger`（**永远禁止 log/slog**，含以 slog 为接口层的变通；库默认只写文件，装配须显式 `WithConsole(true)`）
- 熔断：sony/gobreaker/v2（经 internal/pkg/breaker 封装）；限流：`github.com/gtkit/golimit`
- Redis：无场景不引；引入时用 `github.com/gtkit/redisx`
- 第三方包选型顺序：标准库 → gtkit 原生包 → 业界事实标准 → 其他第三方
- 依赖使用最新稳定版，不用 RC/Beta；已有 go.mod 的项目遵循已锁定版本

## Logic 四步

1. **理解需求**：逐字阅读指令，有歧义立即提问，不假设。
2. **提取关键信息**：识别涉及模块和外部交互，读取对应 guide。
3. **按结构组织**：严格按模块化分层和模板编写，不自创模式。
4. **检查合规**：运行传感器 + 自审 + 交叉验证。

## Guide 加载表

| 任务 | 读哪个 Guide |
|-----|-------------|
| gRPC API / proto / buf / 契约 | `.harness/guides/architecture.md` + `.harness/guides/grpc-conventions.md` |
| 数据库操作 | `.harness/guides/db-patterns.md` |
| 数据库迁移 | `.harness/guides/migration.md` |
| 大模型 | `.harness/guides/llm-integration.md` |
| 支付 | `.harness/guides/payment.md` |
| worker / 定时任务 / 队列 | `.harness/guides/workers-and-scheduling.md` |
| cache / Redis / PubSub / 延迟队列 | `.harness/guides/worker-and-cache.md` |
| 可观测性 | `.harness/guides/observability.md` |
| internal/pkg | `.harness/guides/internal-pkg.md` |
| Go 扩展包 | `.harness/guides/pkg-design.md` |
| CI / 传感器 | `.harness/guides/ci-sensors.md` |
| 测试 / 回归 / 验证 | `.harness/guides/testing-and-validation.md` |
| 代码审查 | `.harness/guides/review-checklist.md` |
| Go 1.27 现代语法 / 泛型方法 / UUID | `.harness/guides/go-modern.md` |
| 所有代码任务 | `.harness/guides/architecture.md` + `.harness/guides/go-modern.md` 始终生效 |

## Codex 命令化工作流兼容入口

Claude Code 可以直接使用 `/harness:*` slash commands；Codex 不会自动注册 `.claude/commands/`。当用户在 Codex 中使用以下自然语言别名前缀时，必须把它当作同名 harness command 处理：

| Codex 输入前缀 | 对应流程 |
|---------------|----------|
| `harness doctor` | 诊断 harness、OpenSpec、命令模板和可选 MCP 状态 |
| `harness init-openspec` | 初始化或验证 OpenSpec |
| `harness research: <需求>` | 只做需求研究，不写代码 |
| `harness plan` | 生成计划，不写代码 |
| `harness implement` | 按已批准计划实现并验证 |
| `harness review` | 按 harness 质量门禁审查当前 diff |

不把 `harness ...` 当作 shell 命令执行；它是 Codex 的自然语言工作流别名。

## 分层架构（不可逾越）

推荐结构：

```
bootstrap → runtime/module/<m> → module/<m>/application
runtime/module/<m> → repository, application
module/<m>/transport/grpc → application, pb
repository → models
```

实际目录以 `.harness/guides/architecture.md` 为单一来源。

核心禁止：
- `application` 禁止 import GORM / `internal/repository/*` / 渠道 SDK / gobreaker
- `transport/grpc` 禁止 import GORM / `internal/repository/*` / 渠道 SDK
- `repository` 禁止 import `internal/module/*`
- `worker` 禁止直接 import GORM / repository，只走 application
- `internal/pkg` 禁止反向依赖 `internal/module/*`
- proto 是唯一契约源：改接口只改 proto + `make gen`，**禁止手改 pb/ 产物**

## 编码基线

- context.Context 全链路透传
- 错误用 `fmt.Errorf("xxx: %w", err)` 包装，用 `errors.Is` / `errors.As` 判断；领域 sentinel 三段翻译（SDK 错误 → 领域错误 → gRPC status code）
- 所有外部调用设超时；金额链路全程 int64 分，禁止 float
- 敏感信息禁止硬编码
- 命名：mixedCaps、包名小写、接口按行为命名
- 优先使用标准库现代能力

## 本机容器与镜像纪律（铁律）

- **先查后用**：需要镜像时先 `docker images` 看本机有没有；本机已有就用本机这一版，不再 `docker pull` 别的 tag（含 `latest`）。
- **复用已启动容器**：先 `docker ps -a` 看目标容器在不在；正在运行就直接连，已存在但停止就 `docker start` 复用，不新建同类容器、不换端口再起一份。
- **缺了先问**：本机确实没有所需镜像或容器时停下来，告诉用户缺什么、准备用哪个镜像和 tag，得到明确同意后才执行 `docker pull` / `docker run`。
- **隐式拉取同样受限**：`docker run`（镜像缺失时自动拉）、`docker compose up`、testcontainers、buf / protoc 的容器化跑法、Makefile 与脚本里封装的容器命令，执行前一律先确认本机镜像与容器状态。
- **版本以本机为准**：不因为"官方推荐更新版本"就替换本机镜像 tag；集成测试连本机已启动的依赖服务（MySQL / Redis / MQ 等），不另起实例。

## 提交前必须运行的检查

优先：

```bash
make check
```

没有统一入口时至少：

```bash
golangci-lint run ./...
go vet ./...
go test -race -count=1 -timeout=5m ./...
```

若项目有架构传感器，也必须执行：

```bash
bash scripts/check-architecture.sh
```

## 测试标准

- 单元测试覆盖核心业务路径
- table-driven
- 覆盖 success + error + edge
- mock 通过接口注入（application port 用 fake 实现）
- 有共享状态的代码跑 `go test -race`

## 交叉验证

1. 代码 ↔ 需求：逐条核对，不多不少
2. 代码 ↔ 测试：公开方法有对应测试
3. 代码 ↔ 文档：GoDoc 注释与行为一致
4. 新代码 ↔ 存量代码：不破坏已有测试

## 错误记忆

如果项目中存在 `.harness/error-journal.md`，每次任务开始前先读取。

优先执行项目内脚本：

```bash
bash .harness/scripts/read-error-journal.sh .
```

用户纠正、命令失败、测试失败、审查发现缺陷、回归问题时，执行 append 脚本追加错误记录。脚本不存在时，按 `.harness/guides/error-journal-template.md` 手工追加。

## 合规摘要

每次交付代码时附上：

```markdown
## 合规检查摘要
- [x] Go 1.27 现代特性
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
