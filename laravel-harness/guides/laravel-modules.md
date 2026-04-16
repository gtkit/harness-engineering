# Laravel Modules Guide

> 仅当项目存在 `Modules/` 目录，或已安装 `nwidart/laravel-modules` 时生效。

## 基本原则

- 模块是业务边界，不是随意拆目录
- 模块内部继续遵守 Controller / Service / Data / Async 的职责分离
- 模块之间禁止深度直接调用内部实现

## 推荐结构

```text
Modules/
└── Billing/
    ├── app/
    │   ├── Http/
    │   ├── Actions/ 或 Services/
    │   ├── Jobs/
    │   ├── Listeners/
    │   └── Notifications/
    ├── routes/
    ├── database/
    └── tests/
```

## 跨模块规则

- 共享协议优先通过事件、接口、公共 DTO、公共服务暴露
- 不要跨模块直接依赖对方深层内部类
- 公共逻辑若被多个模块复用，优先抽到共享层

## 审查重点

- 是否把共享逻辑硬塞进某个模块
- 是否存在循环依赖
- 是否在模块边界上泄漏内部实现细节
