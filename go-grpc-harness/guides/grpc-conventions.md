# gRPC / proto / buf 规范 Guide

> 本 guide 是 go-grpc-harness 专有（替代 go-harness 的 api-conventions.md）。
> 内容蒸馏自真实落地项目（pay360-service）的验证经验与 error-journal 教训。

## 契约纪律（铁律）

1. **proto 是唯一事实源**：改接口只改 `proto/`，然后 `make gen`；**禁止手改 `pb/` 产物**；文档不维护契约副本，只指向 proto 文件。
2. **包版本化**：`package <domain>.v1`，目录 `proto/<domain>/v1/`（buf STANDARD lint 要求，为 v2 并存留空间）。
3. **服务名以 Service 结尾**（SERVICE_SUFFIX lint 规则）；一个业务模块对应一个 proto service，模块边界与服务边界一一对应。
4. **go_package 明确**：`option go_package = "<module>/pb/<domain>/v1;<domain>v1";`
5. **契约变更兼容性**：proto3 字段追加向后兼容（先升服务端再升调用方）；改字段编号/类型/删字段是 BREAKING，未上线可做，已上线必须与全部调用方对齐。
6. 金额等资金字段用 `int64`（单位分），禁止 float/double。

## buf 工具链

- buf v2 配置：`buf.yaml`（modules + BSR deps + lint STANDARD + breaking FILE）+ `buf.gen.yaml`（**本地插件**，无远程执行依赖）。
- 四个本地插件：protoc-gen-go / protoc-gen-go-grpc / protoc-gen-grpc-gateway / protoc-gen-openapiv2；用 `scripts/install-proto-tools.sh` 一键安装/升级（可重复执行）。
- 常用命令：`make gen`（= buf lint + buf generate）；`make deps`（buf dep update，显式升级）；`make proto-export`（导出 BSR 依赖，消除 GoLand import 报红）。
- BSR 依赖由 `buf.lock` 锁定并入库，保证可复现。

## 参数校验：protovalidate

- 规则以 option 写在 proto 字段上，运行时由 server 级拦截器统一执行；handler **不重复校验**。
- 运行时模块是 **`buf.build/go/protovalidate`**（`New() (Validator, error)`、`Validator.Validate(msg)`）。
  ⚠️ `github.com/bufbuild/protovalidate-go` 是**已废弃的旧模块路径**，禁止使用（error-journal 实录教训）。
- 校验失败拦截器返回 `InvalidArgument`。

```proto
import "buf/validate/validate.proto";

string app_id = 1 [(buf.validate.field).string = {min_len: 1, max_len: 64}];
int64 amount = 2 [(buf.validate.field).int64.gt = 0];
```

## 拦截器链

装配在 bootstrap，推荐顺序（外 → 内）：

```
recovery（兜住后续所有 panic，转 Internal）
→ 限流（可选，golimit 令牌桶；超限 ResourceExhausted；qps<=0 不注册）
→ protovalidate 校验（失败 InvalidArgument）
→ 业务 handler
```

validate 函数由调用方注入（`func(proto.Message) error`），便于测试替换。注册 `reflection.Register(srv)` 供 grpcurl/buf curl 免 proto 调试。

## 错误码映射（领域错误 → gRPC status）

transport/grpc 层统一 `toStatus(err)`，用 `errors.Is` 匹配领域 sentinel。参考映射与调用方语义：

| 领域语义 | gRPC code | 调用方处理 |
|---|---|---|
| 参数/校验错误 | InvalidArgument | 修参数，不重试 |
| 资源/账号不存在 | NotFound | 检查入参，不重试 |
| 状态不允许操作 / 前置条件不满足 | FailedPrecondition | 按业务处理，不盲目重试 |
| 下游故障 / 熔断打开 / 下游限流 | Unavailable | 可重试（指数退避） |
| 本服务入站限流 | ResourceExhausted | 退避重试 + 检查调用频率 |
| 未实现的 RPC | Unimplemented | 禁止返回成功态假数据 |
| 未归类错误 | Internal | 记日志人工介入 |

规则：
- 错误信息对外简洁脱敏，排障细节（下游错误码/trace id）留在服务端日志或错误 message 的服务端侧。
- 未实现的公开 RPC 必须返回 `Unimplemented`，**绝不返回假成功响应**。

## grpc-gateway（REST 出口）

- 需要给 HTTP 调用方（如 PHP）时用 `google.api.http` 注解生成 REST 反向代理；未接线前 pb.gw.go 只是构建产物，文档要如实标注"未接线"。
- gRPC code → HTTP 状态码由 gateway 自动映射（NotFound→404、InvalidArgument/FailedPrecondition→400、Unavailable→503、ResourceExhausted→429）。
- **回调/webhook 类入口不进 proto**：验签需要原始请求字节，走 gateway 会先反序列化导致验签必败；用独立原始 HTTP handler。

## 客户端与超时

- 服务端每次外部调用设兜底超时（adapter 层 `context.WithTimeout`）。
- 使用文档须给出调用方超时建议：客户端整体超时 ≥ 服务端下游调用超时总和 + 余量。
- 服务无鉴权/明文时必须注明"仅限内网"，跨网暴露前加 mTLS/网关鉴权。

## 调试与验证

```bash
grpcurl -plaintext host:9090 list                     # 列服务(需 reflection)
grpcurl -plaintext host:9090 describe <svc>
grpcurl -plaintext -d '{...}' host:9090 <svc>/<method>
```

部署后验证三步：端口监听 → 反射 list → 真实参数调一个只读 RPC。

## 文档配套

服务应维护三件套：DEV_GUIDE（现状+路线+流程，现状与目标态分开标注）、DEPLOYMENT（含 fail-fast 语义与故障速查）、USAGE（面向调用方：接入方式、逐字段表、错误码表、重试纪律、超时建议）。
