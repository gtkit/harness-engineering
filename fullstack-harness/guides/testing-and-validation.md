# 全栈测试与验证 Guide

本 guide 约束 Go + Vue 全栈项目的测试、验证和前后端契约回归。后端、前端、联调任务都要按影响范围读取本文件；只改一侧时不顺手扩张另一侧，但必须检查契约是否受影响。

## 验证入口

优先使用项目已有统一入口（如 `make test`、`pnpm test`、CI 脚本）。没有统一入口时至少执行：

```bash
# 后端
cd backend && golangci-lint run ./...
cd backend && go vet ./...
cd backend && go test -race -count=1 -timeout=5m ./...

# 前端
cd frontend && npx vue-tsc --noEmit
cd frontend && npx eslint src/ --ext .vue,.ts,.tsx
cd frontend && npx vite build
```

按改动类型追加：

```bash
# 后端覆盖率 / 性能敏感路径
cd backend && go test -coverprofile=coverage.out ./...
cd backend && go test -bench=. -benchmem -count=3 ./...

# 前端单测（按项目实际测试框架）
cd frontend && npm test -- --run
```

## 后端测试

- service、领域规则、校验逻辑使用 table-driven 单元测试，覆盖 success / error / edge。
- handler 使用 `httptest` 覆盖参数绑定、鉴权上下文、错误映射、统一响应结构。
- repository / 事务 / 迁移使用集成测试或项目既有测试数据库策略，不写死个人本地数据库。
- 外部依赖用接口注入和 fake provider；HTTP 依赖用 `httptest.Server`，禁止请求真实第三方。
- 并发安全、幂等、支付回调、状态流转必须在 `go test -race` 下覆盖重复请求或重复回调。

## 前端测试

- composable、状态流转、表单校验和权限守卫优先写单元测试。
- 页面 / 组件测试覆盖 loading、error、empty、success 四类状态。
- API 请求层测试覆盖成功响应、业务错误、网络错误、取消请求和字段级校验错误映射。
- 不使用 `any` 逃避类型错误；`vue-tsc --noEmit` 必须作为契约检查的一部分。
- 对用户关键路径（登录、提交订单、支付、核心表单）优先补组件测试或端到端验证。

## 前后端契约

- 后端 DTO / Resource / 错误码 / 分页结构变更时，必须同步前端 `src/api/` 类型与调用方。
- 契约断言至少覆盖字段名、可选字段、错误结构、分页 `meta` 和空数据结构。
- 前端 mock 数据必须来自真实契约，不允许临时编造字段让页面通过。
- 联调修复要同时验证后端 Feature/handler 测试与前端 api/composable 测试，避免一侧绿另一侧坏。

## 回归与验证纪律

- 修 bug 先补复现测试或最小复现步骤，再修到通过。
- 单点修复后重跑受影响侧的相关全量检查；涉及契约时两侧都跑。
- 测试失败不能只改 mock 或断言凑绿；必须确认真实行为与契约一致。
- 交付时说明实际跑过的命令；没跑的命令必须说明缺失工具、依赖或环境原因。
