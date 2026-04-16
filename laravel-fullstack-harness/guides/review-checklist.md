# Laravel 全栈审查清单 Guide

## 1. 后端

- [ ] Controller 是否轻量
- [ ] Form Request / Resource 是否职责明确
- [ ] Eloquent 是否存在 N+1、事务缺失、锁错误
- [ ] Queue / Scheduler / Event / Notification 是否已检查

## 2. 前端

- [ ] 是否遵守 views → composables → api
- [ ] 是否存在 `any`
- [ ] 是否存在组件直接请求后端
- [ ] 构建、类型检查、eslint 是否覆盖

## 3. 联调

- [ ] Laravel Resource 与前端类型是否一致
- [ ] 错误码映射是否一致
- [ ] 分页和列表结构是否一致
- [ ] 若后端使用 `Modules/`，是否未把模块边界泄漏到前端耦合里
