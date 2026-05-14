# Laravel Harness Design

## Goal

在当前仓库中新增两套可分发的 Laravel Harness 工程配置生成工具：

1. `laravel-harness/`
2. `laravel-fullstack-harness/`

目标是让 Laravel 项目和 `backend/` + `frontend/` 同仓库全栈项目，像现有 Go 系列 Harness 一样，具备统一的：

- 项目级 Agent 约束入口
- `.harness/` 规则与验证目录
- 错误记忆机制
- 安装脚本
- 模板仓库级 smoke test
- CI 覆盖

---

## Scope

### In Scope

- 新增 `laravel-harness/`
- 新增 `laravel-fullstack-harness/`
- 各自包含 `setup.sh`、`SKILL.md`、`CLAUDE.md`、`AGENTS.md`、`guides/`
- README 增加 Laravel 场景说明
- 新增 Laravel 模板级 smoke test
- 将 Laravel 模板 smoke test 接入当前 GitHub Actions CI

### Out Of Scope

- 不生成真实 Laravel 应用代码
- 不引入运行 Laravel 应用所需的 PHP 依赖或 Composer 环境
- 不在当前仓库内引入可执行的 Laravel demo project
- 不把 `nwidart/laravel-modules` 作为强制依赖

---

## Product Shape

### Package 1: `laravel-harness`

适用于纯 Laravel 项目，默认覆盖：

- HTTP / Controller / Form Request / API Resource
- Service / Action / Domain 编排
- Repository / Eloquent / DB 事务
- Queue Job
- Scheduler / Command
- Event / Listener
- Notification / Mail
- Testing / Validation

项目类型默认支持两类：

- API / 后端服务型 Laravel 项目
- 传统 Laravel Web 项目

但规则重心以 API / 后端服务治理为主。

### Package 2: `laravel-fullstack-harness`

适用于前后端分离但同仓库协作的项目：

- 后端在 `backend/`
- 前端在 `frontend/`
- 前端技术栈固定为 Vue 3 + Vite + TypeScript

后端规则继承 `laravel-harness`，额外增加：

- 前端分层约束
- 前后端 API 契约与类型同步约束
- 前端构建与静态检查规则

---

## Version Policy

不锁死 Laravel 大版本。

版本规则如下：

1. 如果目标项目已有 `composer.json` / `composer.lock`，必须跟随现有 Laravel / PHP 版本
2. 如果目标项目未体现明确版本信息，则在文档中使用“当前稳定版本”为默认基线
3. 所有 Agent 规则必须避免猜测具体版本能力

---

## Optional Modules Support

`nwidart/laravel-modules` 作为可选支持，而不是默认必选。

规则如下：

1. 普通 Laravel 项目仍以默认目录结构作为基线
2. 当检测到 `Modules/` 目录，或项目已安装 `nwidart/laravel-modules` 时，必须加载专门的模块化规则
3. 模块化规则单独写入 `laravel-modules.md`
4. 模块化规则覆盖：
   - 模块边界
   - 跨模块依赖方向
   - 模块内部目录组织
   - 公共共享逻辑放置约束

---

## Directory Layout

### `laravel-harness/`

```text
laravel-harness/
├── setup.sh
├── SKILL.md
├── CLAUDE.md
├── AGENTS.md
└── guides/
    ├── architecture.md
    ├── http-and-api.md
    ├── data-and-eloquent.md
    ├── queues-events-scheduling.md
    ├── notifications-and-mail.md
    ├── testing-and-validation.md
    ├── laravel-modules.md
    ├── review-checklist.md
    └── error-journal-template.md
```

### `laravel-fullstack-harness/`

```text
laravel-fullstack-harness/
├── setup.sh
├── SKILL.md
├── CLAUDE.md
├── AGENTS.md
└── guides/
    ├── architecture.md
    ├── http-and-api.md
    ├── data-and-eloquent.md
    ├── queues-events-scheduling.md
    ├── notifications-and-mail.md
    ├── testing-and-validation.md
    ├── laravel-modules.md
    ├── frontend-architecture.md
    ├── frontend-api.md
    ├── frontend-coding.md
    ├── review-checklist.md
    └── error-journal-template.md
```

---

## Guide Responsibilities

### Shared Backend Guides

- `architecture.md`
  - 默认 Laravel 结构与可选 `Modules/` 结构的边界
  - Controller / Service / Repository / Job / Listener / Notification 的职责
  - 禁止 fat controller / fat model / 跨层乱依赖

- `http-and-api.md`
  - Controller
  - Form Request
  - API Resource
  - 统一响应结构
  - 错误码与鉴权入口
  - 分页与序列化规范

- `data-and-eloquent.md`
  - Eloquent Model 边界
  - Repository 何时使用
  - 事务、锁、N+1、Scope、迁移、Seeder 约束

- `queues-events-scheduling.md`
  - Queue Job 幂等、重试、失败处理
  - Event / Listener 适用边界
  - Command / Scheduler 组织与验证

- `notifications-and-mail.md`
  - Notification、Mail、Channel 规范
  - 异步发送、模板变量、安全与审计要求

- `testing-and-validation.md`
  - PHPUnit / Pest
  - Unit / Feature / Integration
  - 队列、事件、通知、定时任务验证
  - 数据库测试与回归验证

- `laravel-modules.md`
  - `nwidart/laravel-modules` 专用规则
  - 普通项目默认不加载

- `review-checklist.md`
  - HTTP、DB、Queue、Event、Notification、Modules、Test、风险排查、自审清单

### Fullstack-Only Guides

- `frontend-architecture.md`
  - `frontend/src/views -> composables -> api`
  - 页面、组件、状态、目录结构

- `frontend-api.md`
  - 前端 API 层
  - 与 Laravel Resource / DTO / 错误码 / 分页结构对齐

- `frontend-coding.md`
  - Vue 3 + Vite + TypeScript 约束
  - 禁止 `any`
  - 组件与 composable 规范

---

## Installation Behavior

两套 Laravel Harness 的安装行为与现有 Go Harness 对齐。

### Step 1: Install Global Skill

安装到：

- `~/.claude/skills/<package-name>/SKILL.md`
- `~/.codex/skills/<package-name>/SKILL.md`

### Step 2: Install Project Files

安装：

- `CLAUDE.md`
- `AGENTS.md`
- `.harness/guides/*.md`
- `.harness/error-journal.md`

### Step 3: Update `.gitignore`

自动创建或补齐：

- `.harness/error-journal.md`
- `.idea/`
- `.DS_Store`

### Guide Overwrite Policy

- 默认只补缺失 guide，不覆盖用户已有 guide
- 使用 `HARNESS_FORCE_GUIDES=1` 时强制刷新 guide
- 已存在的 `.harness/error-journal.md` 默认保留

---

## Agent Rules

### Shared Core Rules

两套 Laravel Harness 都应写入以下强约束：

1. 禁止编造 Laravel / PHP API、包名、artisan 命令、配置项
2. 禁止猜测项目版本，优先跟随现有 `composer.json` / `composer.lock`
3. 任务开始前必须读取 `.harness/error-journal.md`
4. 发现 `.idea/` / `.DS_Store` 必须清理
5. 交付前必须完成验证，不允许“应该可用”
6. 检测到 `Modules/` 或 `nwidart/laravel-modules` 时，必须加载 `laravel-modules.md`
7. 队列 / 定时任务 / 事件 / 通知 默认纳入审查与验证范围

### Fullstack-Only Rules

`laravel-fullstack-harness` 额外要求：

1. 后端代码只在 `backend/`
2. 前端代码只在 `frontend/`
3. 后端 API 契约、Resource、错误码变更时，前端类型必须同步
4. 不走 Blade + Vue 混合页面模式作为默认结构

---

## Verification Commands

### `laravel-harness`

优先跟随项目已有统一入口：

- `composer test`
- `composer pint --test`
- `phpstan`
- `psalm`

如果项目没有统一入口，则采用 Laravel / PHP 通用命令作为基线：

```bash
php artisan about
php artisan test
php artisan route:list
```

### `laravel-fullstack-harness`

后端：

```bash
cd backend && php artisan about
cd backend && php artisan test
cd backend && php artisan route:list
```

前端：

```bash
cd frontend && npm run build
cd frontend && npx vue-tsc --noEmit
cd frontend && npx eslint src/ --ext .vue,.ts,.tsx
```

---

## README Changes

仓库根 README 需要扩展为五套 Harness：

1. `go-harness`
2. `fullstack-harness`
3. `go-pkg-harness`
4. `laravel-harness`
5. `laravel-fullstack-harness`

README 需要新增：

- 目录结构
- 两个 Laravel 场景
- 安装命令
- 项目安装后新增文件说明
- Laravel / Laravel 全栈 的差异表

---

## CI Changes

现有 CI 保持“模板仓库 smoke test”定位，不引入 Composer / PHP 运行时依赖。

新增：

- `tests/laravel_package_smoke_test.sh`

其职责：

1. 检查 `laravel-harness/` 存在
2. 检查 `laravel-fullstack-harness/` 存在
3. 检查 guide 文件齐全
4. 检查 `AGENTS.md` / `SKILL.md` 是否覆盖：
   - Queue
   - Scheduler
   - Event / Listener
   - Notification / Mail
   - `nwidart/laravel-modules` 可选支持
5. 检查全栈版是否包含 `backend/` + `frontend/` 约束
6. 检查根 README 已更新到新场景

CI workflow 新增一步：

```bash
bash tests/laravel_package_smoke_test.sh
```

---

## Risks

### Risk 1: Laravel 版本能力差异

通过“跟随目标项目已有版本”规避，不在模板中硬写高版本特性。

### Risk 2: 模块化项目与普通项目规则冲突

通过 `laravel-modules.md` 单独拆分规避，只在检测到模块化时加载。

### Risk 3: Fullstack 规则与 Laravel Blade 项目混淆

通过明确声明 `laravel-fullstack-harness` 默认是 `backend/` + `frontend/` 分离结构规避。

### Risk 4: 模板仓库 CI 引入 PHP 运行时依赖导致维护复杂化

通过只做 smoke test、不跑真实 Laravel 应用规避。

---

## Implementation Summary

推荐实现顺序：

1. 新增 `laravel-harness/`
2. 新增 `laravel-fullstack-harness/`
3. 新增 Laravel 模板 smoke test
4. 更新根 README
5. 更新 GitHub Actions CI

