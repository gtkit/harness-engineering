# Laravel 审查清单 Guide

完成代码后，至少逐条检查：

## 1. HTTP

- [ ] Controller 是否保持轻量
- [ ] Form Request 是否承担校验 / 授权
- [ ] Resource 是否统一返回结构

## 2. Data / Eloquent

- [ ] 是否存在 N+1 风险
- [ ] 是否缺事务
- [ ] 是否把复杂业务写进 Model

## 2.1 代码质量

- [ ] 无无意义重复代码；重复逻辑已提取或说明保留原因
- [ ] 优先复用已有 Form Request / Resource / Service / Action / Repository / Policy / Job / helper
- [ ] 新增 Service / Action / Repository / trait / 事件有明确收益，不是为单次使用提前设计
- [ ] Controller、Service/Action、Repository/Query Object、Job、Listener 职责单一
- [ ] 依赖方向符合架构约束，没有跨层调用、循环依赖或跨模块乱依赖
- [ ] 错误路径、空值、边界输入、事务、幂等、队列重试、外部依赖失败已处理

## 3. Queue / Scheduler / Event

- [ ] Job 是否幂等
- [ ] Scheduler 是否可重复执行
- [ ] Listener 是否隐藏大段业务或 IO

## 4. Notification / Mail

- [ ] 是否有重复发送风险
- [ ] 是否泄漏敏感信息
- [ ] 是否需要异步化

## 5. Modules

- [ ] 若项目使用 `Modules/`，是否存在跨模块乱依赖
- [ ] 共享逻辑是否放在合理位置

## 6. Testing

- [ ] Feature / Unit / Integration 是否覆盖本次变更主路径
- [ ] 是否为 bug 修复新增回归测试
- [ ] 是否说明实际执行过的验证命令

## 7. 可观测性

- [ ] 错误是否带足够上下文，便于定位问题
- [ ] 外部依赖失败是否有清晰日志或可追踪信息
- [ ] 关键失败路径是否留下了足够的排障线索

## 8. 兼容性与迁移

- [ ] 公开 API / Resource / DTO / 错误码变更是否说明兼容策略
- [ ] migration / schema / 配置变更是否明确前向或回滚路径
- [ ] 破坏性变更是否已同步更新文档与测试

## 合规摘要模板

```text
## 合规检查摘要
- [x] Laravel / PHP 版本按项目事实处理
- [x] Controller / Service / Data 边界明确
- [x] Queue / Scheduler / Event / Notification 已纳入检查
- [x] Modules 可选规则已按需加载
- [x] 验证命令已执行或明确说明缺失条件
- [x] 可观测性：错误上下文与排障线索已检查
- [x] 兼容性与迁移：变更影响与策略已检查
- [x] 代码质量门禁：无明显冗余，复用合理，职责清晰，健壮性已检查
- [x] 无编造内容
```
