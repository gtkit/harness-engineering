# 全栈 Code Review Checklist（推理型传感器）

完成代码后逐条自审。不通过则修复，不适用标注 N/A。

---

## 后端（Go）

### 1. 正确性
- [ ] 业务逻辑覆盖所有分支和边界条件
- [ ] 并发安全（共享变量加锁、channel 正确）
- [ ] 所有 error 已处理（无 `_ = err`）
- [ ] nil 指针检查充分
- [ ] 类型断言用 comma-ok

### 2. 安全性
- [ ] 用户输入已校验 + sanitize + 长度限制
- [ ] SQL 参数化（无拼接）
- [ ] 敏感信息从配置/环境变量获取
- [ ] 接口走了 auth 中间件
- [ ] 日志不打印敏感信息

### 3. 性能
- [ ] 无 N+1 查询、列表有 LIMIT
- [ ] 无 goroutine 泄漏
- [ ] 批量操作分批（≤ 500）
- [ ] 外部调用有超时

### 4. 可维护性
- [ ] 分层架构正确（handler 无 gorm，service 无 gin）
- [ ] 命名清晰、Go 1.26 现代写法
- [ ] 错误消息有上下文

### 5. 资源泄漏
- [ ] resp.Body / 事务 / goroutine / 文件句柄 正确关闭
- [ ] context cancel 已 defer

### 6. 大模型（如涉及）
- [ ] 超时 + 重试降级 + Token 限额 + Prompt 模板化

### 7. 支付（如涉及）
- [ ] 金额 int64 + 幂等 + 验签 + 先落库再调网关

---

## 前端（Vue + TS）

### 8. 类型安全
- [ ] 无 `any` 类型
- [ ] Props 和 Emits 用 TypeScript 类型声明
- [ ] API 请求/响应有明确类型
- [ ] `vue-tsc --noEmit` 零错误

### 9. 架构分层
- [ ] views/components 没有直接 import axios
- [ ] components 没有直接调用 api/（只接收 props + emit）
- [ ] 业务逻辑在 composables 中，不在 template 或 component 里
- [ ] 没有硬编码后端 URL

### 10. 组件规范
- [ ] 使用 `<script setup lang="ts">`（禁止 Options API）
- [ ] 组件文件名 PascalCase
- [ ] import 顺序：vue → router → pinia → 第三方 → 项目内
- [ ] Scoped style

### 11. 前端安全
- [ ] 用户输入前端也有基本校验（不仅依赖后端）
- [ ] 不在前端存储敏感信息（密码、支付密钥）
- [ ] XSS 防护：不使用 v-html 渲染用户输入

### 12. 前端性能
- [ ] 大列表有虚拟滚动或分页
- [ ] 图片有懒加载
- [ ] 路由有懒加载（`() => import(...)`）
- [ ] 无不必要的 watch 或 computed（避免无限循环）

---

## 前后端联调

### 13. 类型同步
- [ ] 后端 DTO struct ↔ 前端 `frontend/src/api/types.ts` interface 字段一致
- [ ] 后端 json tag ↔ 前端字段名一致
- [ ] 后端可选字段（指针）↔ 前端可选字段（?）
- [ ] 后端错误码 ↔ 前端错误处理映射一致

---

## 通用

### 14. 测试
- [ ] 后端核心逻辑单元测试（table-driven、≥ 80%）
- [ ] 前端核心组件/composable 有测试
- [ ] 前端 `vue-tsc` + `vite build` 通过

### 15. 交叉验证
- [ ] 代码 ↔ 需求：功能点逐条对照
- [ ] 代码 ↔ 测试：公开方法有对应测试
- [ ] 新代码 ↔ 存量代码：不破坏已有测试

### 16. 反编造
- [ ] 所有包名/函数名/组件名真实存在
- [ ] 不确定的已标注"需确认"

---

## 合规摘要模板

```
## 合规检查摘要
- [x] Go 1.26 / Vue 3 + TS strict
- [x] 后端分层 + 前端分层
- [x] 前后端类型同步
- [x] 错误处理完整
- [x] 无硬编码
- [x] 资源泄漏检查
- [x] 测试覆盖
- [x] 交叉验证
- [x] 无编造内容
```
