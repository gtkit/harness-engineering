# Laravel 架构约束 Guide

## 默认结构

推荐按以下职责拆分：

```text
app/
├── Http/
│   ├── Controllers/
│   ├── Requests/
│   └── Resources/
├── Actions/ 或 Services/
├── Repositories/          # 可选，复杂查询与聚合时使用
├── Models/
├── Jobs/
├── Events/
├── Listeners/
├── Notifications/
└── Console/
```

## 分层规则

- Controller 只做参数接收、授权、调用与响应
- Form Request 负责校验和授权入口
- Resource 负责输出结构
- Action / Service 负责业务编排
- Repository / Query Object 负责复杂查询和聚合
- Job 负责异步边界，不承接隐藏业务入口
- Listener 负责事件响应，不塞入大段核心业务
- Notification / Mail 独立建类

## 职责边界

- Controller 不写业务规则、事务编排、复杂查询或跨边界 IO
- Form Request 只做输入校验和授权入口，不写业务副作用
- Resource 只做输出序列化，不查询数据库、不拼业务流程
- Action / Service 承载业务流程、事务边界、领域规则和外部服务协调
- Repository / Query Object 只封装复杂查询、聚合和持久化细节
- Job / Listener / Notification 只表达异步、事件和通知边界，复杂业务下沉到 Action / Service
- Model 保持数据关系、scope、cast、简单访问器，不变成业务流程中心

## 抽象准入

只有满足以下任一条件才新增 Service、Action、Repository、helper、trait、事件或配置项：

- 已出现 2 处以上真实重复，且抽象后语义更清晰
- 某段逻辑复杂到需要隔离测试
- 需要隔离外部依赖、复杂查询、事务边界、队列重试或模块边界
- Laravel 原生能力无法清晰表达当前职责

不满足准入条件时优先使用框架原生结构，不为单次使用提前抽象。

## 不建议

- fat controller
- fat model
- 在 Listener / Job 内直接拼装复杂事务
- 在 Controller 中直接写事务和跨边界 IO
- 把通知文案、渠道逻辑、收件人决策塞在业务服务里

## 传统 Laravel Web 项目

如果项目仍使用 Blade / MVC：

- 保留 Controller → Service 的约束
- 不把模板渲染逻辑扩展成业务编排层
- 页面渲染与 API 规则分开描述

## 模块化项目

检测到 `Modules/` 或已安装 `nwidart/laravel-modules` 时：

- 继续以模块为边界组织 Controller / Service / Job / Listener / Notification
- 共享逻辑优先抽到公共层，而不是跨模块深度调用
- 详细规则见 `laravel-modules.md`

## 可观测性

- 错误要带上下文，方便定位来源、输入、业务阶段和外部依赖
- 外部依赖失败要保留可追踪信息，必要时记录 request id / job id / correlation id
- 关键路径日志应可区分校验失败、业务失败、依赖失败和系统异常

## 兼容性与迁移

- 公开 API、Resource、错误码、配置项或默认行为变更时，必须说明兼容策略
- 已合并到主干的 migration 不回改；需要调整时新建 migration
- schema 变更要考虑前向部署、回滚、数据填充和队列任务兼容
