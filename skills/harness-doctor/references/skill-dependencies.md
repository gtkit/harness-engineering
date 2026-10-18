# Harness 技术 skill 依赖

这是 harness 对通用 skill 的依赖与路由清单；知识正文由 my-skills 仓库维护。本文件随 harness-doctor 的 Markdown 资源安装，不复制任何技术 skill。

## 按 harness 与阶段读取

下表仅适用于代码/运行行为任务；纯问答、文档或只读诊断不自动进入代码门禁。验收还需按实际变更面选择，不能因同仓存在前端就要求无关前端验收。

| Harness | 实现/质量所需 | 运行行为交付所需 |
|---|---|---|
| go-harness | use-modern-go、go-enterprise-quality | backend-acceptance |
| go-grpc-harness | use-modern-go、go-enterprise-quality；gRPC实现读go-microservice | backend-acceptance |
| fullstack-harness | 后端：use-modern-go、go-enterprise-quality；前端：vue-frontend-engineer | 按变更面：backend-acceptance、frontend-acceptance；跨端契约两者 |
| go-pkg-harness | use-modern-go、go-enterprise-quality；审查读go-review；发布读go-engineering-governance | 包专属 review/API兼容/测试；无业务入口时不强制业务验收 |
| laravel-harness | senior-php-engineer、use-modern-php、php-enterprise-quality | backend-acceptance |
| laravel-fullstack-harness | PHP：senior-php-engineer、use-modern-php、php-enterprise-quality；前端：vue-frontend-engineer | 按变更面：backend-acceptance、frontend-acceptance；跨端契约两者 |
| frontend-harness | vue-frontend-engineer | frontend-acceptance |
| openresty-harness | openresty-patterns；架构读senior-openresty-engineer；纯Lua语义读senior-lua-engineer | backend-acceptance |

“所需”表示该阶段适用时不可静默跳过；doctor 不会因为缺 skill 自动安装或执行业务门禁。可以依据现有项目规则继续已授权且可独立完成的研究、准备和实现，明确缺失参考带来的限制；缺少证据的质量/验收阶段不能声明通过，不把缺 skill 泛化为整项任务停工。

## 按任务触发的跨栈 SOP

| 任务 | 条件依赖 | 缺失影响 |
|---|---|---|
| HTTP或proto/gateway与客户端的契约演进 | cross-stack-api-contract | 契约验证未验证 |
| 多组件发布、灰度、迁移或回滚 | polyglot-release-engineering | 联合发布验证未验证 |
| PHP质量门禁 | php-enterprise-quality | PHP门禁未验证 |
| 生产事故分段定位与止损 | incident-response | 响应流程未验证，不据此执行生产写入 |
| 跨网关、PHP、Go、浏览器关联观测 | cross-stack-observability | 跨跳关联未验证 |
| OpenResty配置、证书、流量和reload | openresty-gateway-operations | 网关运行验证未验证 |
| 多生态依赖、SBOM、secret、CVE、镜像 | polyglot-security-supply-chain | 供应链检查未验证 |
| 跨栈测试层次、故障注入和flaky策略 | polyglot-test-engineering | 测试策略覆盖未验证 |
| 运行时/依赖版本升级 | runtime-upgrade-migration | 升级兼容与恢复未验证 |
| 跨层性能与容量 | fullstack-performance | 端到端性能未验证 |
| 跨语言事件、重投、DLQ、回放 | async-job-contracts | 事件兼容与恢复未验证 |

普通单组件小改不加载全部条件依赖。Go的数据库、并发、缓存、MQ等继续按项目skills-index读取专项。缺少某个工具或skill不能被“不适用”掩盖，必须说明当前任务是否确实依赖它。

## 三种证据分开报告

- 存在：实际读到 SKILL.md，给出路径；同名多份记录当前使用者。
- 可发现：当前运行时技能清单包含该项；同步文件不会证明本会话立即刷新清单。
- 已执行：本次任务实际加载该skill、执行对应检查，并有命令/行为证据。只读完文件不表示门禁通过。

推荐输出：`harness / 当前任务与阶段 / skill / required或conditional / 路径 / 存在 / 可发现 / 已执行 / 缺口与补测条件`。
