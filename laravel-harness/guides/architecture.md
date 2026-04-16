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
