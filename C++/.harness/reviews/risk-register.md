# Risk Register

| Risk | Trigger | Impact | Mitigation | Evidence | Owner |
| --- | --- | --- | --- | --- | --- |
| 模块边界漂移 | 业务逻辑混入平台层 | 难测、难改、易回归 | 强制分层审查 | architecture review | 需用户补充 |
| 所有权不清 | 裸资源或隐式共享 | 泄漏、UAF、崩溃 | RAII、所有权审查 | ASan/LSan + review | 需用户补充 |
| 数据竞争 | 多线程共享状态无同步 | 随机故障、结果错误 | TSan + 并发设计审查 | TSan + stress | 需用户补充 |
| 关闭不收敛 | 线程 / 队列 / FD 悬挂 | 发布失败、资源泄漏 | 统一 shutdown 协议 | signal shutdown test | 需用户补充 |
| 配置漂移 | 环境差异或硬编码 | 启动失败、行为不一致 | 配置集中管理 | startup/config tests | 需用户补充 |
| 模型制品不一致 | 版本 / checksum 不匹配 | 推理失败或错误结果 | 制品校验 | artifact validation | 需用户补充 |
| 资源失控 | 队列无限增长或显存失控 | OOM、延迟雪崩 | 预算 + 拒绝策略 | load/soak tests | 需用户补充 |
| 性能回退 | 无基线或错误优化 | SLA 失守 | benchmark gate | perf reports | 需用户补充 |
| 观测缺失 | 无日志 / 指标 / 版本信息 | 无法排障 | 观测清单 | release checklist | 需用户补充 |
| 依赖风险 | 第三方版本漂移或漏洞 | 安全与稳定风险 | 固定版本与审查 | dependency report | 需用户补充 |
