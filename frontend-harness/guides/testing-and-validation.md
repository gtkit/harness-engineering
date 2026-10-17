# 前端测试与验证 Guide

## 验证入口

优先使用项目已有入口。没有统一入口时至少执行：

```bash
npx vue-tsc --noEmit
npm run lint
npm test -- --run
npm run build
```

## 测试分层

- composable、store、表单和权限守卫：Vitest 单元/行为测试。
- 页面和组件：Testing Library 覆盖 loading、empty、error、success、键盘交互。
- 关键用户路径：Playwright 等真实浏览器 E2E；网络用契约 fixture 或 MSW，但标明 mock 局限。
- API client：成功、字段错误、401 单飞刷新、取消、超时、409、重试和过期响应。

## 回归要求

- 修 bug 先补复现步骤或失败测试，再修到通过。
- 异步请求覆盖乱序、清空、租户切换、卸载和重复提交。
- 交付说明实际执行的命令；浏览器、真实 API、权限、性能或可访问性未执行时必须标记未验证。

## 交付验收

运行行为交付前读取 `.harness/guides/acceptance-gates.md` 并加载 `$frontend-acceptance`。构建、截图和单测只证明局部，不能替代需求追踪、真实交互、权限、数据一致性、安全、性能和可访问性证据。
