---
name: cpp-linux-ai-harness
description: Use when working on enterprise C++ Linux AI projects that need harness rules, structured review, validation gates, risk control, and error-memory enforcement.
---

# C++ Linux AI Harness Skill

## 适用范围

当任务涉及以下任一内容时必须使用本 Skill：

1. C++20/23 企业项目规范
2. Linux 守护进程 / CLI / 系统工具
3. AI 模型推理服务 / 本地模型集成
4. 架构治理、构建治理、测试治理、审查治理
5. 生产级风险排查、回归控制、发布门槛
6. 生成或维护 Harness 相关文件

## 硬规则

1. 禁止编造
2. 禁止猜测
3. 严格按结构输出
4. 不扩展无关内容
5. 任务开始前必须读取 `.harness/error-journal.md`
6. 任务结束前必须执行“历史错误对照检查”
7. 命令失败、测试失败、用户纠正、审查缺陷、回归问题、误判，必须追加到 `.harness/error-journal.md`
8. 信息不足时，只输出“缺失信息清单”

## 默认边界

1. 语言标准：C++20/23
2. 平台：Linux
3. 构建系统：CMake
4. 编译器：GCC / Clang
5. 场景：AI 推理服务 / 本地模型集成 / 高性能系统工具链
6. 项目特定运行时、部署、观测、测试框架：如未明确，一律标记“需用户补充”

## 触发后固定流程

### Step 1: 读取历史错误

1. 查找 `.harness/error-journal.md`
2. 若存在，先读取
3. 若不存在，创建或提示引入 Harness 模板中的标准文件
4. 从历史记录中提取：
   - 重复错误
   - 高风险区域
   - 已知失败路径
   - 已定义的预防规则

### Step 2: 判断任务类型

在以下类型中选择一项或多项：

1. architecture
2. cpp
3. linux
4. ai
5. build
6. test
7. review
8. release

### Step 3: 加载参考文件

- `references/project-scope.md`
- `references/workflow.md`
- `references/error-memory.md`
- `references/output-contract.md`

按任务附加读取：

- review 任务：`references/review-standard.md`
- build / test / release 任务：`references/validation-standard.md`

### Step 4: 按 Logic 执行

1. 理解需求
2. 提取关键信息
3. 按结构组织内容
4. 检查合规性

### Step 5: 强制验证与对照

在声称“完成”“修复”“通过”“可上线”前，必须确认：

1. 是否存在对应验证证据
2. 是否命中历史错误
3. 是否补充了新的回归验证
4. 是否需要追加错误日志

## 错误记忆流程

在以下场景追加 `.harness/error-journal.md`：

1. 命令失败
2. 测试失败
3. 用户指出回答错误
4. 审查发现缺陷
5. 回归问题
6. 同类错误再次出现

追加内容必须包含：

1. Summary
2. What Happened
3. Root Cause
4. Corrective Action
5. Prevention Rule
6. Related Files
7. Validation Added
8. Linked History

## 输出纪律

1. 信息不足时：
   - 只输出“缺失信息清单”
2. 实施类任务：
   - 需求理解
   - 关键信息
   - 变更内容
   - 验证结果
   - 历史错误对照检查
   - 合规检查摘要
3. 审查类任务：
   - Findings
   - Open Questions
   - 风险摘要
   - 历史错误对照检查
   - 合规检查摘要
4. 模板类任务：
   - 需求理解
   - 关键信息
   - 目录树
   - 文件正文
   - 验证矩阵
   - 合规检查摘要

## 禁止事项

1. 未读错误日志直接开工
2. 以经验替代事实
3. 以单次通过替代生产可用
4. 以样例通过替代边界安全
5. 以代码阅读替代自动化验证
6. 在未执行对应验证前宣称“没问题”
7. 生成与 C++ / Linux / AI 无关的内容

## 可选脚本

若环境允许，可使用：

- `scripts/read_error_journal.sh`
- `scripts/append_error_journal.sh`

脚本只作为辅助，不替代审查与判断。
