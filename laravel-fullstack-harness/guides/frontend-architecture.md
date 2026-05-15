# 前端架构规范 Guide

## 目录结构

```text
frontend/
├── index.html
├── package.json
├── vite.config.ts
├── tsconfig.json
└── src/
    ├── views/
    ├── components/
    ├── composables/
    ├── api/
    ├── stores/
    ├── router/
    ├── types/
    └── utils/
```

## 分层规则

```text
views -> composables -> api -> backend
```

- views 不直接写 axios
- components 不直接请求后端
- composables 负责复用交互逻辑
- api 层负责与 Laravel 后端接口对接
- 环境变量统一走 `VITE_` 前缀

## 职责边界

- views 只负责页面编排、路由参数读取、调用 composables/stores、组织组件
- components 只负责展示和局部交互，通过 props/emit 与外部通信
- composables 承载可复用交互流程、状态组合、请求编排和副作用控制
- stores 承载跨页面状态，不直接操作 DOM、不直接拼接后端 URL
- api 层只封装 HTTP 请求、请求/响应类型和错误映射，不承载页面流程
- utils 只放纯函数或无业务状态的通用工具，不收纳页面临时代码

## 抽象准入

只有满足以下任一条件才新增 composable、store、通用组件、helper 或配置项：

- 已出现 2 处以上真实重复，且抽象后语义更清晰
- 某段交互流程复杂到需要隔离测试
- 需要隔离 Laravel API、浏览器能力、第三方 SDK 或跨页面状态
- 已有目录分层要求通过对应层访问

不满足准入条件时优先在当前页面内保持清晰实现，不为单次使用提前抽象。

## 与后端协作

- 前端字段命名与后端 Resource 契约保持一致
- 分页结构、错误码、状态字段不能随意自创

## 可观测性与兼容性

- API 错误映射要保留后端错误码、message 和必要上下文，便于定位问题
- 关键交互失败要有明确用户反馈，不吞掉异常
- 后端 Resource / 错误码 / 分页结构变更时，前端类型、mock、错误处理必须同步
- 破坏性契约变更要说明兼容策略，必要时同时兼容新旧字段
