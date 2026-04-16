---
name: laravel-fullstack-harness
description: |
  Laravel + Vue 全栈 Harness Engineering skill。后端在 backend/，前端在 frontend/，覆盖 Laravel API、Eloquent、Queue、Scheduler、Event、Notification，以及 Vue 3 + Vite + TypeScript。所有该类项目任务都应触发。
---

# Laravel Fullstack Harness Skill

## 行为纪律

1. **禁止编造**：不确定的 Laravel / PHP / Vue / Vite / TypeScript API、命令、配置项不写。
2. **禁止猜测**：版本、目录结构、构建方式必须以项目事实为准。
3. **严格按结构输出**：只输出用户要求的内容，不跨边界乱扩展。
4. **前后端不混**：后端问题不自动补前端，前端问题不自动补后端。
5. **执行清理**：发现 `.idea/`、`.DS_Store` 或误写的 `.Ds_Store`，必须删除。

## 目录基线

- 后端在 `backend/`
- 前端在 `frontend/`
- 后端可选支持 `nwidart/laravel-modules`

## Logic 四步

### Step 1：理解需求

- 判断属于后端、前端还是联调
- 确认 `backend/` 与 `frontend/` 是否存在

### Step 2：提取关键信息

| 任务 | Guide |
| --- | --- |
| 后端结构 | `.harness/guides/architecture.md` |
| 后端 HTTP / API | `.harness/guides/http-and-api.md` |
| 后端数据层 | `.harness/guides/data-and-eloquent.md` |
| Queue / Scheduler / Event | `.harness/guides/queues-events-scheduling.md` |
| Notification / Mail | `.harness/guides/notifications-and-mail.md` |
| 后端验证 | `.harness/guides/testing-and-validation.md` |
| Modules | `.harness/guides/laravel-modules.md` |
| 前端结构 | `.harness/guides/frontend-architecture.md` |
| 前端 API | `.harness/guides/frontend-api.md` |
| 前端编码 | `.harness/guides/frontend-coding.md` |
| 审查 | `.harness/guides/review-checklist.md` |

### Step 3：按结构组织

- 后端遵守 Controller / Service / Data / Async 分层
- 前端遵守 views → composables → api
- 联调时优先确认 API 契约、错误码、分页结构、字段命名

### Step 4：检查合规

后端：

```bash
cd backend && php artisan about
cd backend && php artisan test
cd backend && php artisan route:list
```

前端：

```bash
cd frontend && npx vue-tsc --noEmit
cd frontend && npx eslint src/ --ext .vue,.ts,.tsx
cd frontend && npm run build
```

## 默认审查重点

- 后端 Queue / Scheduler / Event / Notification 质量
- 前后端 Resource / API 类型 / 错误码 同步
- 模块化项目的边界与依赖方向

## 合规摘要

每次交付附上：

```text
## 合规检查摘要
- [x] backend/ 与 frontend/ 边界明确
- [x] Laravel / Vue 版本按项目事实处理
- [x] Queue / Scheduler / Event / Notification 已检查
- [x] 前后端 API 契约已对齐
- [x] 验证结果已给出
- [x] 无编造内容
```
