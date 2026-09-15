# Laravel 数据层与 Eloquent Guide

## Model 边界

- Model 保持聚焦：关系、cast、简单 domain helper
- 不把复杂业务流程塞进 Model
- 不把跨聚合的查询与事务写成 fat model

## 安全（mass assignment / 原始 SQL）

- 显式定义 `$fillable`（白名单）或 `$guarded`；**禁止用请求数组直接 `Model::create($request->all())`**，防 mass assignment 越权写字段
- 原始 SQL（`whereRaw` / `DB::raw` / `selectRaw`）必须用参数绑定（`whereRaw('x = ?', [$v])`），**禁止字符串拼接**用户输入
- 用户可控的排序字段 / 列名需白名单校验，不能直接拼进 SQL

## Repository 何时使用

以下情况推荐显式引入 Repository / Query Object：

- 多表聚合查询
- 复用复杂过滤 / 排序 / 搜索逻辑
- 需要隔离 Eloquent 细节给上层

简单 CRUD 不强制 Repository。

## 事务与锁

- 跨多次写操作时显式使用 `DB::transaction()`
- **并发写**（库存扣减 / 余额 / 状态切换）：事务内用 `lockForUpdate()` 悲观锁，或用版本号字段做乐观锁（`where version = ?` + 影响行数判断）
- **死锁重试**：`DB::transaction($callback, $attempts)` 第二个参数设重试次数应对死锁
- 事务闭包内**不要 `try/catch` 吞异常**（会破坏自动回滚）；也不要做可外提的远程调用（HTTP / 队列 dispatch 用 `afterCommit`）

## Eager Load 与 N+1

- 列表与资源序列化前检查关系加载
- 默认对热点路径审查 N+1；开发 / 测试环境开 `Model::preventLazyLoading()` 主动暴露懒加载
- 复杂资源返回优先显式 `with()` / `loadMissing()`
- 大数据集遍历用 `cursor()` / `chunkById()`，避免一次性 `get()` 撑爆内存

## 迁移与 Seeder

- 迁移保持幂等与可回滚
- Seeder 只做受控测试 / 初始化数据
- 不把临时脚本长期留在生产迁移路径
