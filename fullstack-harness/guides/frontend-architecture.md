# 前端架构规范 Guide

## 技术栈

- Vue 3（Composition API + `<script setup>`，禁止 Options API）
- Vite（最新稳定版）
- TypeScript（严格模式）
- Vue Router
- Pinia（状态管理）
- Axios（HTTP 请求）

## 目录结构

```
frontend/
├── index.html
├── vite.config.ts
├── tsconfig.json
├── package.json
├── src/
│   ├── main.ts                  # 入口
│   ├── App.vue
│   ├── router/                  # 路由
│   │   └── index.ts
│   ├── views/                   # 页面级组件（对应路由）
│   │   ├── HomeView.vue
│   │   └── UserListView.vue
│   ├── components/              # 可复用 UI 组件
│   │   ├── common/              # 通用组件（Button、Modal、Table）
│   │   └── business/            # 业务组件
│   ├── composables/             # 组合式函数（useXxx）
│   │   ├── useAuth.ts
│   │   └── usePagination.ts
│   ├── api/                     # 接口请求层（对应后端 API）
│   │   ├── client.ts            # Axios 实例 + 拦截器
│   │   ├── types.ts             # 接口请求/响应类型
│   │   ├── user.ts              # /api/v1/users
│   │   └── order.ts             # /api/v1/orders
│   ├── stores/                  # Pinia stores
│   │   ├── user.ts
│   │   └── app.ts
│   ├── types/                   # 全局类型定义
│   │   ├── api.d.ts             # 后端统一响应类型
│   │   └── env.d.ts             # 环境变量类型
│   ├── utils/                   # 工具函数
│   ├── styles/                  # 全局样式
│   └── assets/                  # 静态资源
└── env/
    ├── .env.development
    └── .env.production
```

## 分层规则

```
views（页面组件，调用 composables 和 stores）
   ↓
composables（业务逻辑复用，调用 api 和 stores）
   ↓
api（HTTP 请求层，封装 Axios 调用）
   ↓
后端 API
```

**禁止：**
- views 中直接调用 Axios，必须通过 `api/` 层
- components 中调用 `api/`，组件只接收 props 和 emit 事件
- stores 中直接操作 DOM
- 任何位置硬编码后端 URL，必须走环境变量

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
- 需要隔离后端 API、浏览器能力、第三方 SDK 或跨页面状态
- 已有目录分层要求通过对应层访问

不满足准入条件时优先在当前页面内保持清晰实现，不为单次使用提前抽象。

## 路由与鉴权

- 受保护路由统一在 `router.beforeEach` 校验登录态 / 权限，未授权重定向登录页并带回跳地址（`redirect` query）
- 路由元信息声明权限要求（`meta: { requiresAuth: true, roles: [...] }`），守卫据此判断，不在每个组件里各写各的
- 登录态来源单一（如 auth store / token），守卫和 api 层 401 处理共用同一套，避免双重跳转

## 与后端的类型对齐

后端统一响应格式在前端的类型定义：

```typescript
// frontend/src/types/api.d.ts
interface ApiResponse<T = unknown> {
  code: number
  msg?: string
  message?: string
  data: T
}

interface Paging {
  page?: number
  per_page?: number
  currentPage?: number
  pageSize?: number
  total: number
  total_page?: number
  totalPage?: number
}

interface PagedData<T = unknown> {
  list: T[]
  paging: Paging
}

interface PagedResponse<T = unknown> extends ApiResponse<T[] | PagedData<T>> {
  meta?: {
    page: number
    per_page: number
    total: number
    total_page: number
  }
}
```

每个后端接口在 `frontend/src/api/` 下有对应文件，请求和响应类型必须与后端 DTO 保持同步；不要在前端临时发明后端没有的字段。

## 可观测性与兼容性

- API 错误映射要保留后端错误码、客户端文案字段（如 `msg` / `message`）和必要上下文，便于定位问题
- 关键交互失败要有明确用户反馈，不吞掉异常
- 后端 DTO / 错误码 / 分页结构变更时，前端类型、mock、错误处理必须同步
- 破坏性契约变更要说明兼容策略，必要时同时兼容新旧字段

## Composition API 规范

```vue
<script setup lang="ts">
// 1. import 顺序：vue → vue-router → pinia → 第三方 → 项目内
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { getUserList } from '@/api/user'
import type { User } from '@/api/types'

// 2. props 和 emits 用 defineProps / defineEmits 声明类型
const props = defineProps<{
  title: string
  count?: number
}>()

const emit = defineEmits<{
  confirm: [id: number]
  cancel: []
}>()

// 3. 响应式状态
const loading = ref(false)
const users = ref<User[]>([])

// 4. 计算属性
const isEmpty = computed(() => users.value.length === 0)

// 5. 方法
async function fetchUsers() {
  loading.value = true
  try {
    const res = await getUserList()
    users.value = res.data
  } finally {
    loading.value = false
  }
}

// 6. 生命周期
onMounted(() => {
  fetchUsers()
})
</script>
```
