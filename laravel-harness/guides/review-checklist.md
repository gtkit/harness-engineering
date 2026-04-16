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
