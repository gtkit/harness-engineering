# Test Matrix

## 核心构建矩阵

| Lane | Compiler | Build Type | Sanitizer | Required |
| --- | --- | --- | --- | --- |
| gcc-debug | GCC | Debug | none | build + unit + integration |
| gcc-release | GCC | Release | none | build + unit + integration + e2e smoke |
| clang-debug | Clang | Debug | none | build + unit + integration |
| clang-release | Clang | Release | none | build + unit + integration + e2e smoke |
| clang-asan-ubsan | Clang | Debug | ASan + UBSan | build + unit + integration |
| clang-tsan | Clang | Debug | TSan | build + selected concurrent tests |
| clang-lsan | Clang | Debug | LSan | build + long-run leak checks |
| static-analysis | Clang tools | n/a | n/a | clang-format + clang-tidy + cppcheck |

## Linux 运行路径矩阵

| Lane | Environment | Scope | Required |
| --- | --- | --- | --- |
| startup-smoke | Linux | 启动、读取配置、退出 | 必需 |
| healthcheck-smoke | Linux | `--health-check` | 必需 |
| signal-shutdown | Linux | SIGTERM / SIGINT | 必需 |
| permission-failure | Linux | 权限错误失败路径 | 必需 |
| install-smoke | Linux | 安装后启动 | 必需 |
| rollback-smoke | Linux | 回滚后恢复 | 视发布场景决定，未定义则需用户补充 |

## AI 运行时矩阵

| Lane | Device | Scope | Required |
| --- | --- | --- | --- |
| model-load-smoke | CPU | 加载、预热、单请求 | 必需 |
| invalid-artifact | CPU | 损坏制品 / 错误版本 | 必需 |
| timeout-path | CPU | 超时与错误返回 | 必需 |
| batch-boundary | CPU | batch 上限、拒绝路径 | 必需 |
| concurrent-infer | CPU | 并发推理安全 | 必需 |
| gpu-smoke | GPU | 加载、单请求、释放 | GPU 场景需用户补充 |
| device-fallback | CPU/GPU | 设备不可用退化 | 如存在退化策略则必需 |

## 性能矩阵

| Lane | Build | Scope | Required |
| --- | --- | --- | --- |
| benchmark-smoke | Release | 关键路径 benchmark | 必需 |
| latency-baseline | Release | P50 / P95 / P99 | 必需 |
| throughput-baseline | Release | 稳态吞吐 | 必需 |
| soak-run | Release | 长时运行 | 长运行服务必需 |

## 通过规则

1. 任何必需 Lane 失败都阻断主干或发布
2. 任何未执行 Lane 必须给出理由
3. 任何豁免必须有责任人和截止时间
