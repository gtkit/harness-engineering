# 前端 API 请求层规范 Guide（对接 Laravel）

## 契约来源

前端 API 层对齐 Laravel 后端：Form Request 输入结构、API Resource 输出结构、统一错误返回、标准分页。错误以 **HTTP 状态码**为准（Laravel 习惯），不是 Go 那套 `code !== 0`。

## Axios 实例

```typescript
// frontend/src/api/client.ts
import axios from 'axios'
import type { ApiErrorBody } from '@/types/api'

const client = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
  timeout: 15000,
  headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
})

// 请求拦截器：注入 token
client.interceptors.request.use((config) => {
  const token = localStorage.getItem('token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// 响应拦截器：按 HTTP 状态码统一错误处理
client.interceptors.response.use(
  (response) => response,
  (error) => {
    const status = error.response?.status
    const body = error.response?.data as ApiErrorBody | undefined
    if (status === 401) {
      localStorage.removeItem('token')
      window.location.href = '/login'
    }
    // 422：校验错误，errors 按字段；其余按 message
    return Promise.reject(new ApiError(status ?? 0, body?.message ?? '请求失败', body?.errors))
  },
)

export default client
```

## 接口文件规范

每个 Laravel Controller 对应一个文件，函数名与 Controller 方法（index/show/store/update/destroy）对应：

```typescript
// frontend/src/api/user.ts
import client from './client'
import type { ApiResource, PagedResource } from '@/types/api'
import type { User, CreateUserReq, UpdateUserReq, ListReq } from './types'

export function getUserList(params?: ListReq) {
  return client.get<PagedResource<User>>('/api/v1/users', { params })
}

export function getUser(id: number) {
  return client.get<ApiResource<User>>(`/api/v1/users/${id}`)
}

export function createUser(data: CreateUserReq) {
  return client.post<ApiResource<User>>('/api/v1/users', data)
}

export function updateUser(id: number, data: UpdateUserReq) {
  return client.put<ApiResource<User>>(`/api/v1/users/${id}`, data)
}

export function deleteUser(id: number) {
  return client.delete<void>(`/api/v1/users/${id}`)
}
```

## 类型定义

```typescript
// frontend/src/api/types.ts — 与 Laravel Resource 对齐
export interface User {
  id: number
  name: string
  email: string
  role: string
  created_at: string
}

export interface CreateUserReq {
  name: string
  email: string
  password: string
  role: 'admin' | 'user' | 'moderator'
}

export interface UpdateUserReq {
  name?: string
  email?: string
  role?: 'admin' | 'user' | 'moderator'
}

export interface ListReq {
  page?: number
  per_page?: number
  sort?: string
  search?: string
}
```

## 请求取消与竞态

- 搜索、分页、路由切换等会发起新请求覆盖旧请求的场景，必须用 `AbortController` 取消在途请求，丢弃过期响应
- 组件卸载（`onUnmounted`）时取消未完成请求
- 被取消的请求不当作错误提示

```typescript
const controller = new AbortController()
const res = await client.get('/api/v1/users', { params, signal: controller.signal })
// 参数变化或卸载时：controller.abort()
```

## 必须遵守的规则

1. **所有请求通过 `api/` 层**，views 和 components 禁止直接 import axios
2. **请求和响应必须有类型**，禁止 `any`
3. **错误处理在调用方**，api 层只负责请求与错误归一，不负责 UI 提示
4. **后端 URL 从环境变量获取**：`import.meta.env.VITE_API_BASE_URL`
5. **前后端契约同步**：Laravel Resource / 分页 / 错误结构变了，前端 `types.ts` 与 `api.d.ts` 必须同步更新
6. **字段命名与可选性**对齐 Laravel Resource 的 nullable / optional 语义

## 自定义错误类

```typescript
export class ApiError extends Error {
  status: number
  errors?: Record<string, string[]> // 422 字段级校验错误
  constructor(status: number, message: string, errors?: Record<string, string[]>) {
    super(message)
    this.status = status
    this.errors = errors
    this.name = 'ApiError'
  }
}
```
