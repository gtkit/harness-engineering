# MCP Streamable HTTP

## 先选协议版本

Streamable HTTP 不是旧的 HTTP+SSE 双端点方案，也不是把 REST 返回值包成流。使用已核实支持目标版本的 SDK，由 SDK 负责 JSON-RPC 编码与传输。

以下用于定位版本差异，不替代完整规范；2026-10-30 核对：

| 边界 | [2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports) | [2026-07-28](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http) |
|---|---|---|
| 协议状态 | initialize 握手；可选 MCP-Session-Id | 逐请求元数据；无协议级会话 |
| 流与方法 | POST；GET 可提供独立 SSE，或返回 405；会话终止按该版本处理 | POST 的 JSON 或请求对应 SSE；独立 GET 流及会话 DELETE 不再是该版本能力 |
| 取消/恢复 | 网络断开不等于取消；可选基于 Last-Event-ID 恢复 | 关闭请求的 SSE 流表示取消；不提供 Last-Event-ID 恢复 |

新版还约束请求头与请求体元数据的一致性；旧客户端兼容走相应版本规范。不要把会话 ID、GET 流、初始化或断连行为写成适用于所有版本的硬编码规则。SDK 接口相同也不代表语义相同。

## 网络入口与身份

- 规范要求校验 Origin；出现非法 Origin 应拒绝。本地服务优先仅监听 loopback；远程部署明确地址、TLS 终止、可信代理和授权策略。[端点安全要求](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http#security--endpoint)
- Origin 缺失按所选规范及受信客户端策略处理，不能把缺失当作已认证。Host、转发头与客户端地址只信任明确配置的代理，不能用于绕过权限。
- 受保护资源每次请求都认证并绑定主体，工具执行再次校验资源范围。会话、连接、请求 ID 和客户端声明的 capabilities 不是身份凭据。
- 使用 MCP HTTP 授权时按所选版本实现资源服务器发现、令牌验证与 scope 错误；对应 401/403 及 WWW-Authenticate 由认证层返回。token 不进入 URL 查询串，不能只在握手时验证。[授权规范](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization)
- 本机单用户、受控内网与公网多用户分别写明信任模型；不能因为协议授权功能可选，就将有写权限的服务默认匿名公开。需要浏览器调用时单独配置 CORS，CORS 不代替 Origin 校验与认证。

## HTTP 与流的运行约束

1. 挂载单一、明确的 MCP 路径；方法、Accept、Content-Type、版本头、错误体与通知响应遵循所选协议。不要重定向到登录 HTML，也不要加业务 REST envelope。
2. 在接收完整请求前限制 body/header 与消息大小；对单次工具执行、在途请求、队列、流数量、输出量分别设预算。耗尽时明确拒绝，不无限堆 goroutine。
3. SSE 及时 flush；middleware 不得吞掉流式能力。反向代理、压缩、缓冲、心跳和 idle timeout 一并验证。项目使用 Nginx/OpenResty 时读取对应网关技能。
4. 将请求总超时与流空闲超时分开。不能照搬普通短 REST 的写超时截断长流，也不能为了长流关闭所有时间/资源上限。
5. SDK、HTTP Server 与业务 context 的取消链要按协议版本测试；旧版流恢复不能因原始 HTTP 连接断开而误杀本应继续的工作。新版取消也不保证外部写入已回滚。
6. 慢客户端和写失败必须停止继续生产无用输出并释放资源。优雅关闭需主动停止/取消长流并设置收尾预算，不能假定 Shutdown 自动结束所有流。
7. readiness、健康检查和指标如需暴露，使用单独权限和最小信息；不泄露工具数据、授权根、token 或依赖连接串。

## 多客户端、多副本

每次请求独立持有主体与权限。若目标版本使用会话/事件恢复，将状态绑定主体、限制数量和 TTL；重新认证、登出与权限变更有失效策略。新版不引入虚构的 MCP 协议会话。

多副本下明确哪些状态可留在内存、哪些需要路由亲和或共享存储；流恢复和共享存储只在确需且协议支持时实现。进程重启、滚动发布、授权变更、状态缺失都必须有确定响应；不得用无效会话触发写工具重放。

验收需穿过实际代理链验证普通响应、流、断连与关闭，并做两个不同权限主体的隔离测试。配置和测试矩阵见 `.harness/guides/architecture.md`、`.harness/guides/testing-and-validation.md`。
