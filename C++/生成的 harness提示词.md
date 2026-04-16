## 1. 需求理解

  目标是为 C++ + Linux + AI 方向的企业级项目定义一套可直接落地的 Harness 实战模板，并同步设计一套可复用的 Skill，使 AI 在后续参与项目时能按固定流程执行。

  该模板与 Skill 需要满足以下边界：

  - 面向真实生产环境，不接受演示级、玩具级、概念级方案
  - 必须覆盖工程结构、构建系统、依赖管理、测试体系、静态检查、动态检查、性能、安全、部署、可观测性、风险控制、回归验证
  - 必须具备错误记忆能力：任务开始前读取历史错误，任务过程中记录新错误，任务结束前对照历史错误做复核
  - 必须支持全面审查：包括检查清单、测试矩阵、交叉验证机制、隐患排查表
  - 输出内容必须结构化、可直接保存为项目文件，不允许自由发挥

  当前阶段不是生成最终模板正文，而是先固化后续要生成的整体结构、文件范围与职责边界。

  ## 2. 关键信息提取

  已明确的信息：

  - 开发语言：C++
  - 主要方向：Linux、AI
  - 交付物一：企业级 Harness 实战模板
  - 交付物二：对应的可复用 Skill
  - 质量目标：企业生产级
  - 过程约束：
      - 禁止编造
      - 禁止猜测
      - 严格按结构输出
      - 不扩展无关内容
  - 机制要求：
      - 错误记忆
      - 全面审查
      - 全面测试
      - 交叉验证
      - 隐患排查

  需用户补充的信息：

  - 项目主要类型：AI 推理服务、本地模型集成工具、Linux 系统服务、边缘侧程序、高性能计算组件、CLI/Daemon 中的哪一种或哪几种
  - 构建体系偏好：CMake 是否为唯一标准，是否允许 Bazel、xmake 等
  - 目标编译器范围：是否固定为 GCC + Clang
  - C++ 标准范围：C++20、C++23 或两者都支持
  - AI 技术栈边界：是否涉及 ONNX Runtime、TensorRT、LibTorch、OpenVINO、本地 LLM 推理框架等
  - 部署形态：是否涉及 systemd、Docker、Kubernetes、裸机部署
  - 观测体系偏好：日志、指标、追踪是否有既定标准
  - 安全边界：是否涉及多租户、模型文件校验、插件加载、远程调用、鉴权
  - 测试基线：是否有指定测试框架、基准测试框架、覆盖率工具
  - Skill 安装位置：是项目内私有 Skill，还是通用全局 Skill

  以上信息若不补充，后续模板只能给出保守通用骨架，不能对具体技术选型做确定性落地描述。

  ## 3. 建议的 Harness 与 Skill 总体目录结构

  建议采用两层结构：

  第一层：项目内约束与治理文件

  - AGENTS.md
  - .harness/
  - .harness/guides/
  - .harness/checklists/
  - .harness/templates/
  - .harness/validation/
  - .harness/reviews/
  - .harness/error-journal.md

  第二层：可复用 Skill 目录

  - cpp-linux-ai-harness-skill/
  - cpp-linux-ai-harness-skill/SKILL.md
  - cpp-linux-ai-harness-skill/agents/openai.yaml
  - cpp-linux-ai-harness-skill/references/
  - cpp-linux-ai-harness-skill/scripts/
  - cpp-linux-ai-harness-skill/assets/
    仅在确有必要时保留

  职责划分建议：

  - AGENTS.md：项目级最高行为约束
  - .harness/guides/：按主题拆分的实施规范
  - .harness/checklists/：上线前、审查前、交付前检查项
  - .harness/templates/：标准化输出模板
  - .harness/validation/：测试矩阵、交叉验证规则、验证步骤
  - .harness/reviews/：审查清单、风险评估、缺陷归类规则
  - .harness/error-journal.md：历史错误与纠正记录
  - SKILL.md：Skill 的触发条件、工作流、约束、输出结构
  - references/：Skill 的扩展参考材料
  - scripts/：需要确定性执行的辅助脚本
    具体是否需要，需用户补充

  ## 4. 计划生成的文件清单与每个文件职责

  ### 项目级 Harness 文件

  - AGENTS.md
      - 定义项目级行为纪律、输出纪律、分工边界、验证要求、错误记忆要求
  - .harness/guides/architecture.md
      - 定义 C++ Linux AI 项目的总体架构分层、模块职责、边界约束、依赖方向
  - .harness/guides/cpp-coding.md
      - 定义 C++ 代码规范、语言特性使用边界、异常与错误处理、资源管理、并发规范
  - .harness/guides/linux-systems.md
      - 定义 Linux 进程模型、守护进程、信号处理、文件系统、权限、系统资源约束、排障要求
  - .harness/guides/ai-engineering.md
      - 定义 AI 模型加载、推理生命周期、资源控制、模型版本管理、异常恢复、数据输入输出边界
  - .harness/guides/build-and-toolchain.md
      - 定义构建系统、编译器矩阵、依赖管理、格式化、静态分析、编译选项、产物规范
  - .harness/guides/review-checklist.md
      - 定义代码审查、架构审查、安全审查、性能审查、上线审查的统一清单
  - .harness/checklists/pre-commit.md
      - 定义提交前检查项
  - .harness/checklists/pre-merge.md
      - 定义合并前检查项
  - .harness/checklists/pre-release.md
      - 定义发布前检查项
  - .harness/validation/test-matrix.md
      - 定义编译器、构建模式、测试类型、运行环境的验证矩阵
  - .harness/validation/cross-validation.md
      - 定义静态检查、动态检查、功能验证、性能验证之间的交叉验证方法
  - .harness/validation/regression-policy.md
      - 定义回归分类、回归阻断条件、回归修复后的复测规则
  - .harness/reviews/risk-register.md
      - 定义常见生产风险、触发条件、影响范围、缓解措施、验收标准
  - .harness/reviews/hidden-risk-checklist.md
      - 定义隐性风险排查项，包括内存、并发、死锁、资源泄漏、部署缺陷、模型异常
  - .harness/templates/task-output-template.md
      - 定义 AI 每次任务输出时必须遵循的固定结构
  - .harness/templates/review-report-template.md
      - 定义代码审查与风险审查报告结构
  - .harness/templates/test-report-template.md
      - 定义测试报告结构
  - .harness/error-journal.md
      - 记录历史错误、失败命令、误判、用户纠正、缺陷、回归与修复策略
      - 作为每次 Skill 触发前必读文件

  ### Skill 文件

  - cpp-linux-ai-harness-skill/SKILL.md
      - 定义 Skill 的触发条件、适用范围、强制工作流、禁止事项、输出结构、错误记忆流程
  - cpp-linux-ai-harness-skill/agents/openai.yaml
      - 定义 Skill 的显示名称、简述、默认触发提示
  - cpp-linux-ai-harness-skill/references/project-scope.md
      - 记录适用项目范围与边界，避免 Skill 被错误触发到无关项目
  - cpp-linux-ai-harness-skill/references/workflow.md
      - 记录完整执行流程：理解需求、提取信息、按结构组织、检查合规
  - cpp-linux-ai-harness-skill/references/error-memory.md
      - 记录错误记忆机制：读取、记录、对照、规避
  - cpp-linux-ai-harness-skill/references/review-standard.md
      - 记录企业级审查标准与缺陷判断口径
  - cpp-linux-ai-harness-skill/references/validation-standard.md
      - 记录测试与交叉验证标准
  - cpp-linux-ai-harness-skill/references/output-contract.md
      - 记录输出格式契约，确保严格结构化输出
  - cpp-linux-ai-harness-skill/scripts/ 下的辅助脚本
      - 需用户补充
      - 是否需要脚本、脚本用什么语言、脚本是否允许依赖外部工具，目前未明确
  - cpp-linux-ai-harness-skill/assets/
      - 当前不建议默认生成
      - 如需模板资产或固定输出骨架，再由用户明确指定

## 正式生成 Harness 模板 + Skill

  输出时请优先采用“最保守、最可落地、最适合企业协作”的写法，不要为了追求炫技而牺牲可维护性与可验证性。

  基于上面的结构，现在开始正式生成“企业级 C++ Linux AI Harness 实战模板 + 对应 Skill”。

  生成目标：
  1. 输出一套完整的 Harness 实战模板
  2. 输出一套完整的 Skill 模板
  3. Skill 必须具备错误记忆能力
  4. 所有输出必须满足企业生产级要求
  5. 输出内容必须可直接保存为文件使用

  你必须继续遵守以下规则：

  [Logic]
  1. 理解需求
  2. 提取关键信息
  3. 按结构组织内容
  4. 检查合规性

  [硬性约束]
  1. 禁止编造
  2. 禁止猜测
  3. 严格按结构输出
  4. 不扩展无关内容
  5. 信息不足处必须明确标记“需用户补充”
  6. 所有模板必须服务于 C++ + Linux + AI 的企业生产场景
  7. 不允许省略关键校验、测试、审查、交叉验证、风险控制内容

  现在必须严格按以下结构输出，不允许增删章节：

  1. 需求理解
  2. 关键信息
  3. Harness 目录树
  4. Harness 各文件正文
  5. Skill 目录树
  6. Skill 各文件正文
  7. 错误记忆机制设计
  8. 全面测试与交叉验证矩阵
  9. 生产级隐患排查清单
  10. 合规检查摘要

  其中必须覆盖以下内容：

  [Harness 模板必须至少包含]
  - AGENTS.md
  - .harness/guides/architecture.md
  - .harness/guides/cpp-coding.md
  - .harness/guides/linux-systems.md
  - .harness/guides/ai-engineering.md
  - .harness/guides/build-and-toolchain.md
  - .harness/error-journal.md
  - SKILL.md
  [错误记忆机制必须满足]
  - 每次触发 Skill 前先读取 `.harness/error-journal.md`
  - 每次命令失败、测试失败、用户纠正、代码审查发现缺陷、回归问题、误判，都必须追加记录
  - 最终输出前必须执行一次“历史错误对照检查”
  [企业级验证必须覆盖]
  - CMake
  - GCC / Clang
  - Debug / Release
  - clang-format
  - clang-tidy
  - cppcheck
  - 单元测试
  - 集成测试
  - 端到端测试
  - ASan / UBSan / TSan / LSan
  - 性能基准测试
  - 并发与竞态检查
  - 内存泄漏与资源释放检查
  - Linux 部署与守护进程场景
  - 日志、监控、可观测性
  - 安全检查
  - AI 模型加载、推理、资源控制、异常恢复
  - 交叉验证与回归策略

  [输出限制]
  - 不要讲概念课
  - 不要解释你为什么这么设计
  - 不要输出无关扩展建议
  - 不要省略关键文件
  - 不要把关键内容写成“略”
  - 文件正文必须完整可用
  - 如果某些企业约束需要我补充，请明确标记“需用户补充”

  额外要求：
  - 默认面向 C++20/23
  - 默认面向 Linux 生产环境
  - 默认面向 AI 推理服务 / 本地模型集成 / 高性能系统工具链
  - 不要偏前端
  - 不要偏 Web Demo
  - 所有检查项都要贴近生产上线标准
