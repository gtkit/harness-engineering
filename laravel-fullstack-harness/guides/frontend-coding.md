# 前端编码规范 Guide

## 技术基线

- Vue 3
- Vite
- TypeScript
- Composition API

## 基本规则

- 禁止 `any`
- 优先 `<script setup lang="ts">`
- 组件职责单一
- composable 命名统一为 `useXxx`
- 不在页面里直接拼装复杂请求逻辑

## 验证命令

```bash
npx vue-tsc --noEmit
npx eslint src/ --ext .vue,.ts,.tsx
npm run build
```
