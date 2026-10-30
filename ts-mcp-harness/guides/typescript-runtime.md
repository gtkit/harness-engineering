# TypeScript 与异步运行时

## 版本、类型与模块

先读取运行时版本、`tsconfig` 继承链、构建配置、package scripts 和锁文件。保持现有 strict 设置；新增能力按目标 TS/运行时验证，不为消除错误关闭 strict 或滥用 `any`、非空断言与 `as`。

外部数据用 `unknown` 经运行时校验后收窄；`interface`、泛型和类型断言不是权限或输入校验。精确处理字段缺失、`undefined`、null、空串、0、false；跨 JSON 边界明确大整数和二进制表示。

ESM/CJS、package `type`、`exports`、导入扩展名、编译 target 和 module resolution 必须与实际执行器一致。不凭开发 loader 能解析路径别名推定生产 JS 能解析；避免双重打包生成两份全局状态。

[Node 内建类型擦除](https://nodejs.org/api/typescript.html)不执行类型检查，也不按 `tsconfig.json` 完整转译；它还限制 `node_modules` 内的 TS 处理。npm 产物不能只因源码在开发机可运行就假设安装端能运行。需要 loader/编译器时核对运行时依赖与发布文件，不静默安装。

## 取消与资源

- 从 SDK 的请求取消能力接入 `AbortSignal`，传给确实支持它的 fetch、流和子任务；在 CPU 循环/分页/分块之间显式检查取消。
- `Promise.race` 或返回超时响应不会取消底层工作。超时后停止生产、解除监听并等待/回收资源；写入是否提交单独判断。
- timer、事件监听器、订阅、异步迭代器和 Map 中的请求状态在成功、失败、取消及重复关闭时都要释放；清理校验归属，不删除后来请求的新状态。
- 限制在途 Promise、队列及输出字节；异步函数中的同步计算依旧阻塞事件循环，必要时采用已验证的有界 worker 机制，不新增 Go 服务。
- 流式写入遵守实际流接口的背压/取消语义；Node Streams 与 Web Streams 不混用生命周期假设。
- 未处理异常/拒绝不能吞掉后假装健康继续；启动错误输出到 stderr，退出和重启策略遵循进程契约。避免提前 `process.exit()` 丢失协议响应或尚未完成的收尾。

HTTP 流、断连与关闭按所选 MCP 协议测试，不将普通请求的 `close` 事件直接等同于工具取消。具体条件见 `.harness/guides/mcp-streamable-http.md`。
