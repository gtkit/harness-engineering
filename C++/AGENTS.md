# AGENTS.md

> 企业级 C++20/23 + Linux + AI 项目 Harness

## 行为纪律

1. 禁止编造：不确定的事实、接口、路径、命令、依赖、部署方式，统一标记为“需用户补充”。
2. 禁止猜测：不使用“应该”“大概”“可能”“通常支持”等措辞替代事实。
3. 严格按结构输出：只输出用户要求的结构，不自由发挥，不追加无关建议。
4. 不扩展无关内容：只处理 C++、Linux、AI、构建、测试、审查、部署、观测、安全相关内容。
5. 任务开始前必须读取 `.harness/error-journal.md`。
6. 命令失败、测试失败、误判、用户纠正、审查发现缺陷、回归问题，必须追加到 `.harness/error-journal.md`。
7. 任务结束前必须执行一次“历史错误对照检查”。
8. 如信息不足，先输出“缺失信息清单”，不得直接生成实现或结论。

## 适用范围

- C++20/23 服务端程序
- Linux 守护进程、CLI、系统工具
- AI 模型推理服务、本地模型集成、推理网关、资源受限推理程序
- 高性能系统模块、并发模块、资源敏感模块

## Logic 四步

1. 理解需求
   - 判断任务类型：架构、编码、构建、测试、审查、部署、AI 运行时、安全、性能、故障排查
2. 提取关键信息
   - 提取已知事实、缺失信息、受影响模块、验证范围、上线风险
3. 按结构组织内容
   - 使用固定输出结构，不混写、不跨层、不跳步骤
4. 检查合规性
   - 对照 Harness、错误日志、验证矩阵、审查清单逐项检查

## Guide 加载表

| 任务 | 必读文件 |
| --- | --- |
| 架构设计 / 模块划分 | `.harness/guides/architecture.md` |
| C++ 编码 / 重构 / 代码风格 | `.harness/guides/cpp-coding.md` |
| Linux 进程 / 守护进程 / 系统交互 | `.harness/guides/linux-systems.md` |
| AI 模型接入 / 推理 / 资源控制 | `.harness/guides/ai-engineering.md` |
| 构建 / 编译 / Toolchain / CI | `.harness/guides/build-and-toolchain.md` |
| 测试 / 回归 / Sanitizer / Benchmark | `.harness/guides/testing-and-validation.md` |
| 代码审查 / 风险审查 / 上线检查 | `.harness/guides/review-checklist.md` |
| 交付前统一检查 | `.harness/checklists/*` + `.harness/validation/*` + `.harness/reviews/*` |

## 输出纪律

1. 信息不足时：
   - 只输出“缺失信息清单”
2. 实施类任务：
   - 需求理解
   - 关键信息
   - 变更内容
   - 验证结果
   - 合规检查摘要
3. 审查类任务：
   - Findings
   - Open Questions
   - 风险摘要
   - 合规检查摘要
4. 模板类任务：
   - 需求理解
   - 关键信息
   - 目录树
   - 文件正文
   - 验证矩阵
   - 合规检查摘要

## 工程纪律

1. 不绕过构建系统直接手工拼接产物。
2. 不绕过测试矩阵直接宣称“可上线”。
3. 不绕过审查清单直接宣称“无风险”。
4. 不允许跨层直接依赖未授权模块。
5. 不允许在核心库中混入 Linux 进程控制或 AI 运行时强耦合逻辑。
6. 不允许在生产路径保留调试打印、临时开关、未清理实验代码。
7. 不允许把“性能猜测”当作性能结论。
8. 不允许把“样例通过”当作“生产可用”。

## 交付前检查

1. 读取 `.harness/error-journal.md`
2. 对照 `.harness/validation/test-matrix.md` 选择必须执行的验证
3. 对照 `.harness/guides/review-checklist.md` 做审查
4. 对照 `.harness/reviews/hidden-risk-checklist.md` 排查隐患
5. 对照 `.harness/validation/regression-policy.md` 检查是否引入回归
6. 输出合规检查摘要

## 合规检查摘要模板

- [x] C++20/23 / Linux 生产环境
- [x] 严格按结构输出
- [x] 已读取错误日志
- [x] 已执行对应 Guide
- [x] 已完成验证与交叉验证
- [x] 已完成隐患排查
- [x] 无编造内容
- [x] 无猜测内容

## 沟通与提交规范

### 沟通语言

**与用户的所有对话必须使用简体中文**，包括解释、确认、进度汇报、错误说明。

### Commit 规范（强制）

- 格式：`<类型>(<范围>): <标题>`，必要时附正文和页脚
- 语言：Header / Body / Footer 全部使用简体中文
- 类型：`feat` | `fix` | `docs` | `style` | `refactor` | `perf` | `test` | `chore` | `ci` | `revert`
- 标题：祈使句、现在时态（用"添加"而非"添加了"），结尾不加句号
- 范围：尽可能具体（如 `auth`、`ui`、`api`），不确定可省略括号
- 正文：仅在需要解释"为什么"时添加，说明动机而非实现
- 页脚：关联 Issue 用 `Closes #ID`；破坏性变更以 `BREAKING CHANGE:` 开头
- 输出限制：仅输出 Commit Message，不加代码块标记、不加寒暄
- 示例：
  - `fix(auth): 修复移动端登录页面显示异常`
  - `feat(cart): 添加购物车核心功能`

## 文档维护

- **新增功能或变更使用方法时，必须同步更新 README**（项目根 `README.md` 或模块对应 README）
- 更新范围：功能清单、安装/初始化步骤、命令示例、配置项说明、目录结构
- 提交纪律：README 更新与功能代码须在同一次提交中完成，避免文档滞后
- 交付前自检：若本次变更涉及对外接口、CLI 命令、环境变量、使用流程，而 README 未同步，判定为未完成

## 敏感信息与 .gitignore 安全基线

### 禁止入库（零容忍）

- 环境变量文件：`.env`、`.env.local`、`.env.production` 等
- 密钥文件：`*.pem`、`*.key`、`id_rsa`、`secrets.*`、`credentials.*`
- 带真实密钥的配置文件（`config.*.yml`、`application.properties` 含密钥版本等）
- 云服务凭据：AWS / 阿里云 / 腾讯云 AccessKey、Service Account JSON
- 系统 / IDE 产物：`.DS_Store`、`.idea/`、`.vscode/`（除非团队共享）
- 构建 / 测试产物：`build/`、`out/`、`cmake-build-*/`、`*.log`、coverage 产物

### 代码内禁止硬编码

- API Key、密码、Token、私钥、JWT Secret、Session Secret、加密 Salt 一律从环境变量或密钥管理服务读取
- 本地开发用 `.env.example` 提供占位符，真实值放 `.env`（不入库）
- 日志禁止打印完整密钥，必要时脱敏（如 `sk-****abcd`、`Bearer ****`）
- 返回给客户端的错误信息、响应体必须过滤敏感字段
- 测试禁止使用真实密钥，用 mock / fixture 替代

### .gitignore 必备条目

    .env
    .env.*
    !.env.example
    *.pem
    *.key
    secrets.*
    credentials.*
    .DS_Store
    .idea/
    build/
    out/
    cmake-build-*/
    coverage/
    *.log

各技术栈按需补齐（Node `node_modules/`、Python `__pycache__/`、Rust `target/` 等）。

### 事故响应

- 发现敏感信息已入库：**立即吊销该密钥**，再从 Git 历史清除（`git filter-repo` / BFG）
- 已推送到远端的密钥视作"已泄露"，不可靠删除掩盖
- 事件记录到 `.harness/error-journal.md`，避免重蹈覆辙

## CHANGELOG 规范（Keep a Changelog）

根目录维护 `CHANGELOG.md`，遵循 [Keep a Changelog 1.1.0](https://keepachangelog.com/zh-CN/1.1.0/) 格式。

### 区段结构（示例）

    # Changelog

    ## [Unreleased]

    ### Added
    ### Changed
    ### Deprecated
    ### Removed
    ### Fixed
    ### Security

    ## [1.2.0] - 2026-04-17

    ### Added
    - 新增用户导出 API（支持 CSV / Excel 格式）

    ### Fixed
    - 修复移动端登录页面显示异常

### 变更类别

- **Added** 新功能
- **Changed** 现有功能的变更
- **Deprecated** 即将移除的功能
- **Removed** 已移除的功能
- **Fixed** Bug 修复
- **Security** 安全相关修复

### 写作约束

- 语言：简体中文
- 视角：站在下游用户 / 消费者角度描述，不写实现细节
- 粒度：一条一件事，对应一个 PR 或一组强相关 commit
- 关联：条目尾部附 Issue / PR 链接，如 `（#123）`
- 禁止写入：`refactor xxx`、`bump version`、`update deps` 等内部动作

### 维护纪律

- 每个 PR 合并主干时，同步更新 `[Unreleased]` 区段
- 发版时：将 `[Unreleased]` 内容剪切到新版本区段，附日期（`YYYY-MM-DD`），Unreleased 清空
- 破坏性变更在对应版本条目顶部用 **⚠ 破坏性变更** 标注
