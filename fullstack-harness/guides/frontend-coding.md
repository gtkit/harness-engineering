# 前端编码规范 Guide

## TypeScript 严格模式

tsconfig.json 必须开启：
```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true
  }
}
```

**禁止 `any`**。实在无法定义类型时用 `unknown` + 类型守卫。

## Vue 组件规范

- 必须使用 `<script setup lang="ts">`，禁止 Options API
- 组件文件名 PascalCase：`UserList.vue`、`PaymentForm.vue`
- 页面组件放 `views/`，以 `View` 后缀命名：`UserListView.vue`
- 可复用组件放 `components/`
- 单文件组件顺序：`<script>` → `<template>` → `<style>`

## Props 和 Emits

```typescript
// 必须用 TypeScript 类型声明
const props = defineProps<{
  userId: number
  editable?: boolean
}>()

// 带默认值
const props = withDefaults(defineProps<{
  pageSize?: number
}>(), {
  pageSize: 20,
})

// Emits 必须声明类型
const emit = defineEmits<{
  update: [value: string]
  delete: [id: number]
}>()
```

## Composables（组合式函数）

- 文件名以 `use` 开头：`useAuth.ts`、`usePagination.ts`
- 返回值用对象解构，不用数组
- 内部管理响应式状态和副作用，对外暴露干净的接口

```typescript
// composables/usePagination.ts
export function usePagination(fetchFn: (params: ListReq) => Promise<PagedResponse>) {
  const page = ref(1)
  const perPage = ref(20)
  const total = ref(0)
  const loading = ref(false)
  const data = ref<unknown[]>([])

  async function load() {
    loading.value = true
    try {
      const res = await fetchFn({ page: page.value, per_page: perPage.value })
      data.value = res.data.data
      total.value = res.data.meta.total
    } finally {
      loading.value = false
    }
  }

  function goTo(p: number) {
    page.value = p
    load()
  }

  return { page, perPage, total, loading, data, load, goTo }
}
```

## 命名规范

| 类型 | 规范 | 示例 |
|-----|------|------|
| 组件文件 | PascalCase | `UserCard.vue` |
| 组合式函数 | camelCase + use 前缀 | `useAuth.ts` |
| API 函数 | camelCase + 动词开头 | `getUserList` |
| 类型/接口 | PascalCase | `CreateUserReq` |
| 常量 | UPPER_SNAKE_CASE | `MAX_PAGE_SIZE` |
| CSS class | kebab-case | `user-card__title` |

## 环境变量

- 前端环境变量必须以 `VITE_` 开头
- 定义在 `env/.env.development` 和 `env/.env.production`
- 类型声明在 `src/types/env.d.ts`

```typescript
// src/types/env.d.ts
/// <reference types="vite/client" />
interface ImportMetaEnv {
  readonly VITE_API_BASE_URL: string
  readonly VITE_APP_TITLE: string
}
```

## 异步数据三态

- 任何异步数据视图必须显式处理三态：**loading / error / empty**
- 错误态保留可重试入口（重试按钮 / 下拉刷新），不静默吞异常
- 空态与加载态区分，不要用空列表冒充"加载中"

## 表单校验

- 客户端做即时校验（必填、格式、长度），提交前拦截明显非法输入
- 提交后端返回的字段级校验错误要映射回对应表单项展示，不只弹一个全局错误
- 校验规则与后端保持语义一致，不松于后端

## 性能与可访问性

- 路由组件用动态 `import()` 懒加载；超长列表用虚拟滚动；重组件 / 第三方库按需引入
- 表单控件关联 `label`，图标按钮提供 `aria-label`，交互元素键盘可达

## 样式规范

- Scoped style 为默认：`<style scoped>`
- 全局样式只放 `styles/` 目录
- 不使用内联 style 对象（除动态计算值外）
- 颜色、间距等使用 CSS 变量或设计系统 token

## 检查命令

```bash
# 类型检查
npx vue-tsc --noEmit

# ESLint
npx eslint src/ --ext .vue,.ts,.tsx

# 构建
npx vite build
```
