# TypeScript MCP Streamable HTTP

## 版本矩阵

采用已核实的 SDK 与运行时适配，不把旧 HTTP+SSE 双端点或普通 REST envelope 当作 Streamable HTTP。以下差异于 2026-10-30 核对：

| 边界 | [2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports) | [2026-07-28](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http) |
|---|---|---|
| 状态 | initialize 握手，可选 MCP-Session-Id | 逐请求元数据，无协议级会话 |
| 流/方法 | POST；GET 可提供独立 SSE 或返回 405；会话终止按旧版处理 | POST 的 JSON 或请求对应 SSE；不再提供独立 GET 流和会话 DELETE 能力 |
| 取消/恢复 | 网络断开不等于取消，可选 Last-Event-ID 恢复 | 关闭请求 SSE 流表示取消，不提供 Last-Event-ID 恢复 |

新版请求头/体元数据须一致；不同代际的 SDK 包和协议模型不可混搭。客户端是否支持必须实测，不能仅凭包名或相同函数名推断。

## 入口与身份

校验 Origin，拒绝非法来源；缺失 Origin 按协议和受信客户端策略处理，不等于认证成功。本地默认考虑 loopback，远程明确 TLS、监听范围、可信代理及授权模型。Host 和转发头不能未经验证决定权限或可信地址。

受保护请求在工具执行前认证，执行时再校验主体/资源范围；会话 ID、连接和 capabilities 都不是身份凭据。标准 MCP HTTP 授权按对应版本实现发现、token 验证、scope、401/403 和 challenge；不把 JWT helper 称为完整 OAuth。[授权规范](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization)

## 运行约束

- 挂载明确路径，正确处理方法、Accept、Content-Type、版本和通知响应。框架 middleware 不得重复消费 body、返回 HTML 或改写协议错误。
- 在完整解析前限制 header/body；分别限制单工具执行、在途请求、排队、活动流和输出，不无限创建 Promise 或缓存响应。
- Node Streams/Web Streams 按所选适配器处理背压和取消；SSE 及时 flush。实测代理缓冲、压缩、心跳与 idle timeout，不能只测试进程内 handler。
- 请求总超时、流空闲超时和停机总预算独立定义；不能为长流取消所有上限，也不能照搬短 REST 写超时。
- 旧版断连不误杀可恢复工作，新版关闭流传播取消；请求事件含义核对到当前 SDK/运行时。取消不撤销已提交副作用。
- 慢客户端、写失败、重复关闭和进程终止均停止无效输出，解除监听和 timer。有界排空长流，不能假设 server.close 自动完成所有收尾。

按主体隔离请求、缓存、游标、任务和旧协议会话；有界 TTL 与状态失效。不需要共享状态时不引入存储，多副本确需恢复时明确路由或共享方案。健康检查单独授权，避免泄露资源路径和 token。
