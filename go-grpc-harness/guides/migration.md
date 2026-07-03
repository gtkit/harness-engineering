# 数据库迁移 Guide

> BASE: go-harness/guides/migration.md @ 2026-07-03（通用规则同源;通用改进先落 go-grpc-harness,择机回灌 go-harness）

> 不要假设项目已经接入 golang-migrate / goose / 内部平台。迁移工具、目录、命令必须以项目真实配置为准。

## 当前状态判断

开始前先查：
- 是否存在 `database/migrations/`
- 是否存在 Makefile / Taskfile / CI 中的 migrate 命令
- 是否有统一 migration runtime
- 是否有生产发布流程约束

没有统一工具时，脚手架 SQL 只能作为草稿，不能写成“可直接运行”的迁移命令。

## 脚本要求

正式迁移必须写清：
- up 逻辑
- down 逻辑或等价回滚方案
- 索引、唯一约束、默认值、comment
- 数据修复步骤与可重复执行策略
- 大表变更的锁表、回填、灰度与回滚影响

## 变更流程

1. 先改 models，并确认是否跨项目共享。
2. 生成或手写 SQL 草稿。
3. 人工补齐索引、约束、默认值、comment 与回滚。
4. 评估数据规模和上线窗口。
5. 执行项目检查；涉及共享 models 时执行共享一致性检查。

## AutoMigrate

GORM AutoMigrate 只允许本地临时验证。生产环境禁止依赖 AutoMigrate 自动改表。
