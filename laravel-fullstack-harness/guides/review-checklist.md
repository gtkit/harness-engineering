# Laravel 全栈审查清单 Guide

## 1. 后端

- [ ] Controller 是否轻量
- [ ] Form Request / Resource 是否职责明确
- [ ] Eloquent 是否存在 N+1、事务缺失、锁错误
- [ ] Queue / Scheduler / Event / Notification 是否已检查
- [ ] 无无意义重复代码；重复逻辑已提取或说明保留原因
- [ ] 优先复用已有 Form Request / Resource / Service / Action / Repository / Policy / Job / helper
- [ ] 新增 Service / Action / Repository / trait / 事件有明确收益，不是为单次使用提前设计
- [ ] 错误路径、空值、边界输入、事务、幂等、队列重试、外部依赖失败已处理

## 2. 前端

- [ ] 是否遵守 views → composables → api
- [ ] 是否存在 `any`
- [ ] 是否存在组件直接请求后端
- [ ] 构建、类型检查、eslint 是否覆盖
- [ ] 优先复用已有 composable / store / api client / 组件 / helper
- [ ] 新增通用组件、composable、store 有明确复用或隔离复杂度收益
- [ ] 页面、组件、composable、api 层职责单一，没有混合展示、流程、请求逻辑

## 3. 联调

- [ ] Laravel Resource 与前端类型是否一致
- [ ] 错误码映射是否一致
- [ ] 分页和列表结构是否一致
- [ ] 若后端使用 `Modules/`，是否未把模块边界泄漏到前端耦合里

## 4. 可观测性

- [ ] 错误是否带足够上下文，便于定位问题
- [ ] 外部依赖失败是否有清晰日志或可追踪信息
- [ ] 关键失败路径是否留下了足够的排障线索

## 5. 兼容性与迁移

- [ ] 公开 API / Resource / DTO / 错误码变更是否说明兼容策略
- [ ] migration / schema / 配置变更是否明确前向或回滚路径
- [ ] 破坏性变更是否已同步更新文档与测试

## 合规摘要模板

```text
## 合规检查摘要
- [x] 后端在 backend/，前端在 frontend/
- [x] Laravel / Vue 版本按项目事实处理
- [x] Queue / Scheduler / Event / Notification 已检查
- [x] 前后端 API 契约已对齐
- [x] 验证命令已执行或明确说明缺失条件
- [x] 可观测性：错误上下文与排障线索已检查
- [x] 兼容性与迁移：变更影响与策略已检查
- [x] 代码质量门禁：无明显冗余，复用合理，职责清晰，健壮性已检查
- [x] 无编造内容
```
