# 前端 Review Checklist

- 需求与 API 契约有来源，未确认字段和业务规则没有被偷偷补写。
- 组件边界、状态归属、路由守卫和 API client 分层清楚。
- 异步竞态、取消、401 刷新、卸载清理和重复提交可验证。
- 不可信 HTML/URL、token、CSP、iframe、postMessage 和依赖风险已检查。
- 关键流程的 loading/error/empty/success、键盘焦点、读屏、性能和包体有证据。
- 交付前已加载 `$frontend-acceptance`；关键未验证项已阻断或明确风险接受。
