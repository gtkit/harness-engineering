# grpc-service 模板

> 由 go-grpc-harness 的 `scaffold.sh` 实例化。模板 module 名为 `example-grpc-service`，
> scaffold 会替换为你的 module 名。模板自身可 build/test（防腐化：改模板后在本目录跑 `make check`）。

## 生成后 TODO（按序）

1. **换业务域**：把 `proto/example/v1/example.proto` 换成你的域（目录/package/服务名同步），`make gen` 重新生成；
   删除/改造 `internal/{models,repository/exampleitem,module/example,runtime/module/example}` 示例链路。
2. **配置**：`cp config/env/env.yml.example config/env/env.yml` 并填真实值（严格解析：未知键启动失败）。
3. **建表**：示例表 `example_items(id varchar 主键, name varchar, created_at datetime)`；换成你的业务表。
4. **工具链**：`bash scripts/install-proto-tools.sh`（buf + 四个 protoc 插件）。
5. **验收**：`make check` 全绿后再开始业务开发；开发流程按项目根 `CLAUDE.md` 与 `.harness/guides/`。

## 模板已带的机制

- 分层骨架（bootstrap/runtime/module/repository/models/platform/pkg）+ 架构传感器（`scripts/check-architecture.sh`，纳入 `make check`；含 pb/transport 隔离、models 禁 \*gorm.DB、application 禁 grpc status/codes）
- gRPC 拦截器链（**unary/stream 同链**）：recovery → request_id → 限流（golimit，配置可关）→ protovalidate（stream 逐消息校验）
- **grpc.health.v1 健康探针**（默认注册；优雅关闭先置 NOT_SERVING 摘流量）
- **request_id**：透传调用方 `x-request-id` 或自动生成，回写响应头；`logger.XxxwCtx(ctx, ...)` 自动携带 request_id 字段
- 配置严格解析（KnownFields，fail-fast）+ gtkit/logger 两段式初始化（显式 WithConsole）
- ormx MySQL（StartupPing fail-fast / TranslateError / 池默认）+ defer 优雅关池
- `internal/pkg/breaker`（gobreaker/v2 封装，接出站渠道时在 runtime 层装配）
- 优雅关闭（SIGTERM → NOT_SERVING → GracefulStop，**超时兜底强制 Stop**，`grpc.shutdowntimeoutseconds` 可配）
- `make proto-check`：proto/pb 一致性门禁（CI 必跑，防手改 pb 或忘记 make gen）

## 模板未带（按需自加，guides 有对应规范）

鉴权/mTLS（模板默认内网明文）、metrics、Dockerfile、Redis（引入时用 gtkit/redisx）、grpc-gateway 接线（pb.gw.go 已生成未接）。

## 规则文件策略

`AGENTS.md`/`CLAUDE.md`/`.harness/` 由 harness setup.sh **本地生成、不入库**（.gitignore 已忽略）——
**每次 clone 本项目后先跑一次 `bash /path/to/go-grpc-harness/setup.sh`**。
