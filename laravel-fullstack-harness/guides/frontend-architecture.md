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

## 与后端协作

- 前端字段命名与后端 Resource 契约保持一致
- 分页结构、错误码、状态字段不能随意自创
