# AGENTS.md

> 本项目使用 Vue 3 + Vite/TypeScript 开发生产级前端；以下规则适用于 Codex 和 Claude Code。

## 行为纪律（铁律）

1. 不编造接口、字段、权限、状态或业务规则；缺少来源就标记未确认。
2. 先读 `package.json`、锁文件、`tsconfig`、构建配置、路由、store、API 层和测试，再改代码。
3. 不把业务规则、网络请求和共享副作用塞进模板；组件、composable、store、API 层职责分离。
4. 客户端校验只改善体验，服务端负责权限、价格、库存、金额和状态转换。
5. 运行行为改动交付前必须执行前端验收，不能只凭截图或 build 声明完成。

## 自主执行边界

可直接读取本次需求所需文件、修改前端代码和测试、运行类型检查/lint/test/build、修复本次改动引入的失败。不要安装全局工具、触达生产、提交或推送 Git；缺少浏览器、API 或测试数据时报告未验证项。

## Logic 四步

1. 确认用户流程、状态、权限、租户、错误、空态和 API 契约。
2. 按 `.harness/guides/` 加载前端结构、编码、API、测试和 review 约定。
3. 按 views/components → composables/store → api client 分层实现。
4. 运行开发检查；交付前加载 `$frontend-acceptance`，复杂任务最后用 `$harness-review`。

## Guide 加载表

| 任务 | 读哪个 Guide |
|---|---|
| 组件/页面/路由/状态 | `.harness/guides/frontend-architecture.md` + `.harness/guides/frontend-coding.md` |
| API/DTO/错误码 | `.harness/guides/frontend-api.md` |
| 测试/回归/构建 | `.harness/guides/testing-and-validation.md` |
| 代码审查 | `.harness/guides/review-checklist.md` |
| 交付验收 | `.harness/guides/acceptance-gates.md`，加载 `$frontend-acceptance` |
| 提交 message / CHANGELOG / 发版 | `.harness/guides/commit-and-changelog.md` |
| 删除/凭据/生产操作/引入依赖 | `.harness/guides/ai-safety.md` |

## 工作流 skills（Claude Code 与 Codex 同一套）

setup 会安装 `harness-doctor`、`harness-init-openspec`、`harness-research`、`harness-plan`、`harness-implement`、`harness-review`。对应 Codex 调用方式包括 `$harness-research`、`$harness-plan`、`$harness-implement` 和 `$harness-review`。复杂任务按 `research → plan → implement → review`，最终交付必须保留验收报告。

## 前端实现底线

- Vue 3 Composition API + `<script setup>`；TypeScript 项目 strict，禁止用 `any` 掩盖契约错误。
- 异步请求支持取消、过期响应保护、租户/用户隔离和单飞 401 刷新；卸载时清理定时器、订阅和请求。
- 不把不可信字符串当模板；限制 `v-html`、URL、iframe 和 `postMessage`；密钥不能进入浏览器包。
- 原生语义、label、键盘焦点、错误播报、减少动画和真实 p75 性能指标纳入验收。

## 本机容器与镜像纪律（铁律）

前端默认不需要容器。需要时先 `docker images`、`docker ps -a`，复用现有版本；缺镜像或新容器先说明并确认。

## 提交前检查

```bash
npx vue-tsc --noEmit
npm run lint
npm test -- --run
npm run build
```

以上命令按项目实际脚本调整；没跑的命令和原因必须写入交付报告。

## 交付验收门禁

本 harness 是纯前端项目。读取 `.harness/guides/acceptance-gates.md`，页面、组件、路由、store、composable、API client、表单或浏览器安全/性能发生运行行为变化时，交付前必须加载 `$frontend-acceptance`。

关键流程、权限、数据一致性或真实 API 未验证时，结论只能是“未验证/不准入”。mock、截图、静态 grep 和单一浏览器不能代替真实证据。

## 错误记忆与沟通

错误追加到 `.harness/error-journal.md`；用户纠正、命令/测试失败和审查缺陷先记录再继续。与用户的所有对话使用简体中文。
