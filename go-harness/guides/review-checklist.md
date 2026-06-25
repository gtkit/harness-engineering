# AI Code Review Checklist（推理型传感器）

完成代码后逐项自审。不通过则修复，不适用标注 N/A。

## 1. 正确性

- [ ] 业务逻辑覆盖所有分支和边界条件
- [ ] 并发场景无 data race
- [ ] 错误路径都有合理处理和返回
- [ ] nil 检查充分
- [ ] 类型断言使用 comma-ok

## 2. 安全性

- [ ] 用户输入已校验、sanitize、限制长度
- [ ] SQL 使用参数化，动态字段名有白名单
- [ ] 敏感信息从配置/环境变量/密钥管理服务获取
- [ ] 接口权限最小化，业务路由走 auth / permission
- [ ] 日志不打印密码、token、完整请求体、完整 prompt、密钥

## 3. 性能

- [ ] 无 N+1、循环内无不必要查库
- [ ] 列表查询有 LIMIT
- [ ] 大批量操作分批
- [ ] 外部调用有 timeout
- [ ] goroutine 有退出机制

## 4. 架构

- [ ] application 没有 import Gin / GORM / repository
- [ ] transport/http 没有 import GORM / repository
- [ ] repository 没有 import Gin / module
- [ ] worker 没有直接 import GORM / repository
- [ ] internal/pkg 没有反向依赖 module
- [ ] DTO / application / models 没有 import 基础设施型 paginator
- [ ] runtime 只做装配、options、adapter，不承载业务规则

## 5. 可维护性

- [ ] 命名清晰
- [ ] 错误消息包含上下文
- [ ] 新增抽象有真实收益
- [ ] 没有无主 TODO / FIXME
- [ ] 优先复用已有 helper / service / repository / middleware
- [ ] Go 1.26 现代写法合理使用

## 6. 测试

- [ ] 核心业务逻辑有单元测试
- [ ] 覆盖 success + error + edge
- [ ] table-driven
- [ ] mock 通过接口注入
- [ ] 断言具体，优先 errors.Is/As

## 7. 数据一致性

- [ ] 跨表/跨 repo 操作有事务边界
- [ ] 缓存与 DB 有一致性策略
- [ ] 并发写入有 CAS / 锁 / 唯一键保护
- [ ] outbox / 异步副作用在事务提交后执行

## 8. 稳定性与可观测性

- [ ] panic 有 recovery
- [ ] 外部依赖失败有降级或清晰错误
- [ ] 有 request id / task id / trace 线索
- [ ] 关键失败路径有日志或指标
- [ ] 支持优雅关闭

## 9. LLM（如涉及）

- [ ] 调用有超时、取消、错误处理
- [ ] 流式响应处理握手失败和中途错误
- [ ] token 限额和日志脱敏
- [ ] 不臆造 provider API

## 10. 支付（如涉及）

- [ ] 金额 int64 分
- [ ] 先落库再调网关
- [ ] 回调验签且幂等
- [ ] 状态迁移符合白名单，竞态恢复有复核与 CAS
- [ ] 有超时关单、查单补偿、流水记录

## 11. 兼容性与迁移

- [ ] API / DTO / 配置变更有兼容策略
- [ ] migration 有回滚或等价方案
- [ ] 文档和测试同步

## 12. 反编造

- [ ] 包名、函数名、字段真实存在
- [ ] 不确定处已核实或标注需确认
- [ ] 没有照搬其它项目的 helper/API

## 合规摘要模板

```markdown
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
