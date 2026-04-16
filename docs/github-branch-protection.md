# GitHub Branch Protection

这份文档说明如何把当前仓库的最小 CI 接到 `main` 分支保护上。

## 目标

让以下场景自动受保护：

1. 直接向 `main` 推送代码前，必须经过 CI
2. 提交到 `main` 的 Pull Request，必须等 CI 通过后才能合并

当前仓库推荐的必选检查只有一个：

- GitHub Actions workflow: `CI`

## 前置条件

在配置 branch protection 之前，先确认：

1. 仓库里已经存在 [ci.yml](/Users/xiaozhaofu/Ai/harness-engineering/.github/workflows/ci.yml)
2. 这条 workflow 至少成功运行过一次

如果 workflow 从未跑过，GitHub 的 required status checks 列表里通常不会出现对应检查项。

## 推荐配置

进入 GitHub 仓库页面：

1. `Settings`
2. `Branches`
3. `Add branch protection rule`

对 `main` 推荐如下配置：

### Branch Name Pattern

填写：

```text
main
```

### 建议开启

- `Require a pull request before merging`
- `Require approvals`
- `Require status checks to pass before merging`
- `Require branches to be up to date before merging`
- `Do not allow bypassing the above settings`

### Required Status Checks

在 `Require status checks to pass before merging` 下，选择：

- `CI / Smoke`

说明：

- workflow 名字是 `CI`
- job 名字是 `Smoke`
- GitHub 页面里常见显示形式是 `CI / Smoke`

如果你的 GitHub 页面显示的检查名称略有差异，以实际显示为准。

## 这条 CI 实际检查什么

当前 CI 只做自动检查，不做部署：

1. `bash -n go-harness/setup.sh fullstack-harness/setup.sh go-pkg-harness/setup.sh laravel-harness/setup.sh laravel-fullstack-harness/setup.sh`
2. `bash tests/setup_smoke_test.sh`
3. `bash tests/cpp_package_smoke_test.sh`
4. `bash tests/laravel_package_smoke_test.sh`

通过后，说明至少满足：

- 三个安装脚本 shell 语法有效
- 核心安装行为 smoke test 通过
- GitHub Actions workflow 本身存在且包含关键步骤

## 推荐合并策略

建议：

1. 禁止直接 push 到 `main`
2. 所有改动通过 PR 进入 `main`
3. PR 合并前必须等待 `CI / Smoke` 变绿

## 常见问题

### 为什么我看不到 `CI / Smoke`

通常是以下原因之一：

1. workflow 还没成功跑过
2. 你打开的是错误的分支保护规则
3. GitHub Actions 在该仓库还没启用

### 只开 `Require status checks to pass before merging` 够吗

不够。

如果不开 `Require a pull request before merging`，仓库管理员仍可能直接把代码推到 `main`，绕过正常 PR 流程。

### 这是不是自动部署

不是。

这套配置只保证“自动检查通过后才能合并”，不会发布版本，也不会修改线上环境。
