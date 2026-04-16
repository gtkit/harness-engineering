# 前端 API 请求层规范 Guide

## Axios 实例

```typescript
// frontend/src/api/client.ts
import axios from 'axios'
import type { ApiResponse } from '@/types/api'

const client = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
  timeout: 15000,
  headers: { 'Content-Type': 'application/json' },
})

// 请求拦截器：注入 token
client.interceptors.request.use((config) => {
  const token = localStorage.getItem('token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// 响应拦截器：统一错误处理
client.interceptors.response.use(
  (response) => {
    const data = response.data as ApiResponse
    if (data.code !== 0) {
      // 业务错误，抛出让调用方处理
      return Promise.reject(new ApiError(data.code, data.message))
    }
    return response
  },
  (error) => {
    if (error.response?.status === 401) {
      // token 过期，跳转登录
      localStorage.removeItem('token')
      window.location.href = '/login'
    }
    return Promise.reject(error)
  },
)

export default client
```

## 接口文件规范

每个后端模块对应一个文件，函数名与后端 handler 对应：

```typescript
// frontend/src/api/user.ts
import client from './client'
import type { ApiResponse, PagedResponse } from '@/types/api'
import type { User, CreateUserReq, UpdateUserReq, ListReq } from './types'

export function createUser(data: CreateUserReq) {
  return client.post<ApiResponse<User>>('/api/v1/users', data)
}

export function getUserById(id: number) {
  return client.get<ApiResponse<User>>(`/api/v1/users/${id}`)
}

export function getUserList(params?: ListReq) {
  return client.get<PagedResponse<User>>('/api/v1/users', { params })
}

export function updateUser(id: number, data: UpdateUserReq) {
  return client.put<ApiResponse<User>>(`/api/v1/users/${id}`, data)
}

export function deleteUser(id: number) {
  return client.delete<ApiResponse<null>>(`/api/v1/users/${id}`)
}
```

## 类型定义

```typescript
// frontend/src/api/types.ts — 与后端 DTO 对齐
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
  order?: 'asc' | 'desc'
  search?: string
}
```

## 必须遵守的规则

1. **所有请求通过 `api/` 层**，views 和 components 禁止直接 import axios
2. **请求和响应必须有类型**，禁止 `any`
3. **错误处理在调用方**，api 层只负责请求，不负责 UI 提示
4. **后端 URL 从环境变量获取**：`import.meta.env.VITE_API_BASE_URL`
5. **前后端类型同步**：后端 DTO 变了，前端 `frontend/src/api/types.ts` 必须同步更新

## 自定义错误类

```typescript
export class ApiError extends Error {
  code: number
  constructor(code: number, message: string) {
    super(message)
    this.code = code
    this.name = 'ApiError'
  }
}
```
