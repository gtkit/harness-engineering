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

## 与后端的类型对齐

后端统一响应格式在前端的类型定义：

```typescript
// frontend/src/types/api.d.ts
interface ApiResponse<T = unknown> {
  code: number
  message: string
  data: T
}

interface PagedResponse<T = unknown> extends ApiResponse<T[]> {
  meta: {
    page: number
    per_page: number
    total: number
    total_page: number
  }
}
```

每个后端接口在 `frontend/src/api/` 下有对应文件，请求和响应类型必须与后端 DTO 保持同步。

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
