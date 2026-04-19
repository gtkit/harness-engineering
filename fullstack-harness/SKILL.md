---
name: fullstack-harness
description: |
  Go + Vue 全栈项目的 Harness Engineering skill。后端 Go 1.26 + Gin + GORM + gtkit，前端 Vue 3 + Vite + TypeScript + Pinia，前后端代码在同一项目目录下。将架构约束、编码规范、AI 行为纪律、全面测试与交叉验证自动注入 Agent 工作流。触发场景：Go 后端开发（handler/service/repository/LLM/支付/扩展包）、Vue 前端开发（组件/页面/composable/api 层/store）、前后端联调（类型同步/接口对接）、代码审查、架构设计。关键词：Go、Gin、GORM、gtkit、Vue、Vite、TypeScript、Pinia、Axios、handler、service、composable、component、api、前后端、全栈。即使用户没有明确提到"harness"，只要涉及本项目的任何开发任务都应触发。
---

# Fullstack Harness Engineering Skill

> Go 后端 + Vue 前端，同一项目，统一约束。

---

## 第零章：AI 行为纪律（铁律）

1. **禁止编造**：不确定的 API、包名、函数签名、Vue 组件 props 不写，问用户。
2. **禁止猜测**：不说"应该支持"、"大概是"。不确定的库版本/特性不写。
3. **严格按结构输出**：只做用户要求的事，不附加扩展内容。
4. **不扩展无关内容**：用户要前端组件就只写前端，不自动补后端；反之亦然。
5. **前后端边界清晰**：后端代码不出现前端逻辑，前端代码不出现 SQL 或 Go 语法。
6. **执行操作**：一定要删除项目中所有的 `.idea/` 目录、`.DS_Store` 和误写的 `.Ds_Store`

---

## 第一章：项目结构与技术栈

### 项目目录

```
project-root/
├── CLAUDE.md
├── AGENTS.md
├── .harness/
│   ├── error-journal.md
│   └── guides/                 ← 所有规范文档（唯一来源）
│
├── backend/                      # Go 后端
│   ├── main.go                   # 入口
│   ├── go.mod / go.work          # 模块管理
│   ├── Makefile / migrate.mk     # 构建 & 迁移脚本
│   ├── cmd/                      # CLI 命令（server/migrate/seed/jwt 等）
│   ├── config/                   # 配置加载 + 环境文件 (dev/test/pro)
│   │   ├── env/                  # yml 配置
│   │   └── pem/                  # JWT & 支付密钥
│   ├── database/migrations/      # GORM 数据库迁移（20+ 张表）
│   ├── internal/
│   │   ├── dto/                  # 请求/响应 DTO
│   │   ├── handler/              # Gin HTTP Handler
│   │   ├── service/              # 业务逻辑层
│   │   ├── repository/           # 数据访问层
│   │   ├── models/               # GORM 模型（banner/article/audio/user/push/popup/统计 等）
│   │   ├── middleware/            # 中间件（header 等）
│   │   ├── router/               # 路由注册
│   │   ├── scaffold/             # 脚手架/模块配置
│   │   └── pkg/                  # 内部工具包
│   │      
│   ├── public/                   # 静态资源 & 上传目录
│   └── logs/                     # 运行日志
│
├── frontend/                     # Vue 3 前端
│   ├── package.json              # pnpm 管理
│   ├── vite.config.ts            # Vite 构建配置
│   └── src/
│       ├── main.ts / App.vue     # 入口
│       ├── router/               # Vue Router
│       ├── store/                # Pinia 状态 (user)
│       ├── api/                  # API 请求模块
│       │   ├── auth.ts / user.ts / banner.ts / article.ts
│       │   ├── audio.ts / menu.ts / push.ts / popup.ts
│       │   ├── dashboard.ts / statistics.ts / feedback.ts
│       │   └── channel.ts / upload.ts / system.ts / appversion.ts
│       ├── views/                # 页面
│       │   ├── login/            # 登录
│       │   ├── dashboard/        # 仪表盘
│       │   ├── content/          # 内容管理（banner/article/audio/menu）
│       │   ├── operation/        # 运营（push/popup）
│       │   ├── statistics/       # 统计（conversion/revenue）
│       │   ├── user/             # 用户管理
│       │   ├── feedback/         # 反馈管理
│       │   └── system/           # 系统（settings/channel/app-version）
│       ├── layout/               # 布局组件
│       ├── components/           # 通用组件
│       ├── utils/                # 工具（request.ts 等）
│       └── style/                # 全局样式
│
└── Makefile                    ← 统一构建入口

```

### 技术栈锁定

**后端：**
- Go 1.26（使用所有现代特性）
- Gin + GORM + github.com/gtkit/*
- JSON 编解码必须使用 `github.com/gtkit/json` 或 `github.com/gtkit/json/v2`，禁止 `encoding/json`
- 依赖使用最新稳定版

**前端：**
- Vue 3（Composition API + `<script setup>`，禁止 Options API）
- Vite 最新稳定版
- TypeScript 严格模式（`strict: true`，禁止 `any`）
- Pinia（状态管理）
- Vue Router
- Axios

---

## 第二章：Logic 思维链（每个任务四步走完）

### Step 1：理解需求

- 判断任务属于**后端**、**前端**还是**前后端联调**
- 有歧义立即提问

### Step 2：提取关键信息 → 加载 Guide

| 任务类型 | 加载的 Guide |
|---------|-------------|
| **后端** — 新增 API | `architecture.md` + `api-conventions.md` |
| **后端** — 数据库 | `db-patterns.md` |
| **后端** — 大模型 | `llm-integration.md` |
| **后端** — 支付 | `payment.md` |
| **后端** — 扩展包 | `pkg-design.md` |
| **前端** — 页面/组件 | `frontend-architecture.md` + `frontend-coding.md` |
| **前端** — API 对接 | `frontend-api.md` |
| **前后端联调** | `api-conventions.md` + `frontend-api.md`（类型同步） |
| **代码审查** | `review-checklist.md` |
| **所有后端代码** | `architecture.md` 始终生效 |
| **所有前端代码** | `frontend-architecture.md` 始终生效 |

### Step 3：按结构组织内容

- 后端代码严格按 handler → service → repository 分层
- 前端代码严格按 views → composables → api 分层
- 前后端联调时，先确认接口契约（URL + 请求/响应类型），再分别编写

### Step 4：检查合规性

**4a. 后端计算型传感器：**
```bash
cd backend && golangci-lint run ./...
cd backend && go vet ./...
cd backend && go test -race -count=1 -timeout=5m ./...
```

**4b. 前端计算型传感器：**
```bash
cd frontend && npx vue-tsc --noEmit
cd frontend && npx eslint src/ --ext .vue,.ts,.tsx
cd frontend && npx vite build
```

**4c. 架构边界检查：**

后端：
- handler 没有 import gorm ✓
- service 没有 import gin ✓
- pkg/ 没有 import internal/ ✓

前端：
- views/components 没有直接 import axios ✓
- components 没有直接调用 api/ ✓
- 没有硬编码后端 URL ✓
- 没有使用 `any` 类型 ✓

**4d. 前后端类型同步检查（联调时）：**
- 后端 DTO 与前端 `frontend/src/api/types.ts` 字段一致 ✓
- 后端错误码与前端错误处理映射一致 ✓

**4e. 推理型自审**（按 `review-checklist.md` 逐条核对）

**4f. 合规摘要：**
```
## 合规检查摘要
- [x] Go 1.26 / Vue 3 + TS strict
- [x] 后端分层架构
- [x] 前端分层架构
- [x] 前后端类型同步
- [x] 错误处理完整
- [x] 无硬编码敏感信息/URL
- [x] 测试覆盖
- [x] 无编造内容
```

---

## 第三章：测试标准

### 后端测试

与 Go 版 Harness 一致：单元测试 ≥ 80%、table-driven、-race、交叉验证。

### 前端测试

| 层级 | 工具 | 最低要求 |
|-----|------|---------|
| 组件测试 | Vitest + @vue/test-utils | 核心业务组件有测试 |
| Composable 测试 | Vitest | 每个 composable 有独立测试 |
| 类型检查 | vue-tsc --noEmit | 零类型错误 |
| 构建验证 | vite build | 构建无报错 |

### 前后端联调验证

- 后端接口改了 → 前端 `frontend/src/api/types.ts` 必须同步 → `vue-tsc` 通过
- 前端需要新字段 → 后端 DTO 先加 → 前端再用

---

## 第四章：前后端联调规范

### 接口契约

新增接口时，先确定契约再分别开发：

1. **URL**：`POST /api/v1/orders`
2. **请求体**：Go 的 `dto.CreateOrderReq` = TS 的 `CreateOrderReq`
3. **响应体**：Go 的 `response.OK(c, order)` = TS 的 `ApiResponse<Order>`
4. **错误码**：Go 的 `apperror.ErrBadRequest` = TS 的 `ApiError(2001, ...)`

### 类型同步清单

当后端修改了 DTO 时，必须同步检查：

- [ ] Go `dto/` 的 struct → TS `frontend/src/api/types.ts` 的 interface
- [ ] Go json tag（字段名）→ TS interface 字段名一致
- [ ] Go 可选字段（指针）→ TS 可选字段（`?`）
- [ ] Go 枚举值（`oneof`）→ TS union type
- [ ] 运行 `vue-tsc --noEmit` 确认无类型错误

---

## 第五章：Makefile 统一入口

```makefile
.PHONY: dev build test lint

# 后端
dev-server:
	cd backend && go run ./cmd/server

# 前端
dev-web:
	cd frontend && npm run dev

# 全量测试
test:
	cd backend && go test -race -count=1 ./...
	cd frontend && npx vue-tsc --noEmit

# 全量 lint
lint:
	cd backend && golangci-lint run ./...
	cd backend && go vet ./...
	cd frontend && npx eslint src/ --ext .vue,.ts,.tsx

# 构建
build:
	mkdir -p bin
	cd backend && go build -o ../bin/server ./cmd/server
	cd frontend && npx vite build
```

---

## 第六章：错误记忆（同 Go 版）

项目根目录 `.harness/error-journal.md`，Agent 犯错时追加，下次读取规避。

---

## Guides 目录说明

所有规范在 `.harness/guides/`，后端和前端共用。

| 文件 | 覆盖范围 |
|-----|---------|
| `architecture.md` | 后端分层、依赖方向、注入 |
| `api-conventions.md` | 后端统一响应、错误码、路由 |
| `db-patterns.md` | GORM、Repository、事务 |
| `llm-integration.md` | 大模型对接 |
| `payment.md` | 支付模块 |
| `pkg-design.md` | Go 扩展包设计 |
| `frontend-architecture.md` | 前端目录结构、分层规则、Composition API |
| `frontend-api.md` | Axios 封装、接口文件规范、类型对齐 |
| `frontend-coding.md` | TS 严格模式、组件规范、命名、环境变量 |
| `review-checklist.md` | 后端 + 前端 全维度自审 |
