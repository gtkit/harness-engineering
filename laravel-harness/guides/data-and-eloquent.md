# Laravel 数据层与 Eloquent Guide

## Model 边界

- Model 保持聚焦：关系、cast、简单 domain helper
- 不把复杂业务流程塞进 Model
- 不把跨聚合的查询与事务写成 fat model

## Repository 何时使用

以下情况推荐显式引入 Repository / Query Object：

- 多表聚合查询
- 复用复杂过滤 / 排序 / 搜索逻辑
- 需要隔离 Eloquent 细节给上层

简单 CRUD 不强制 Repository。

## 事务

- 跨多次写操作时显式使用 `DB::transaction()`
- 需要防重 / 库存扣减 / 状态切换时评估锁粒度
- 不要在事务内做可外提的远程调用

## Eager Load 与 N+1

- 列表与资源序列化前检查关系加载
- 默认对热点路径审查 N+1
- 复杂资源返回优先显式 `with()` / `loadMissing()`

## 迁移与 Seeder

- 迁移保持幂等与可回滚
- Seeder 只做受控测试 / 初始化数据
- 不把临时脚本长期留在生产迁移路径
