# 前端 API 契约 Guide

## 契约来源

前端 API 层默认对齐 Laravel 后端：

- Form Request 输入结构
- API Resource 输出结构
- 统一错误返回
- 分页返回

## 规则

- 所有请求通过 `frontend/src/api/`
- 请求和响应必须有类型
- 不允许在组件内直接构造后端 URL
- 后端 Resource / 错误码变更时，前端类型同步更新

## 审查重点

- 字段命名是否与 Laravel Resource 一致
- 可选字段是否和后端 nullable / optional 语义一致
- 分页和列表接口是否保持统一响应结构
