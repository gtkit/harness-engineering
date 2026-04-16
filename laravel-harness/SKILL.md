---
name: laravel-harness
description: |
  Laravel 项目的 Harness Engineering skill。覆盖 HTTP、Eloquent、Queue、Scheduler、Event、Notification、Testing，以及可选的 nwidart/laravel-modules。所有 Laravel 任务都应触发。
---

# Laravel Harness Skill

## 行为纪律

1. **禁止编造**：不确定的 Laravel / PHP API、artisan 命令、配置项、包能力不写。
2. **禁止猜测**：项目版本、目录结构、模块方案必须以仓库事实为准。
3. **严格按结构输出**：只做用户要求的内容，不附加无关扩展。
4. **任务前读取错误日志**：如果存在 `.harness/error-journal.md`，先读后做。
5. **执行清理**：发现 `.idea/`、`.DS_Store` 或误写的 `.Ds_Store`，必须删除。

## 版本与结构策略

- Laravel / PHP 版本优先跟随项目已有 `composer.json` / `composer.lock`
- 若项目版本未知，只能标记为“默认稳定版基线”，不能伪造具体能力
- `nwidart/laravel-modules` 是**可选支持**，不是默认必选
- 检测到 `Modules/` 或包依赖时，必须加载 `laravel-modules.md`

## Logic 四步

### Step 1：理解需求

- 判断任务属于 HTTP、数据层、队列、事件、定时任务、通知、测试、模块化中的哪一类
- 确认是否存在 `Modules/` 目录

### Step 2：提取关键信息

按任务读取对应 guide：

| 任务 | Guide |
| --- | --- |
| 结构 / 分层 | `.harness/guides/architecture.md` |
| HTTP / API | `.harness/guides/http-and-api.md` |
| Eloquent / 事务 / 迁移 | `.harness/guides/data-and-eloquent.md` |
| Queue / Scheduler / Event | `.harness/guides/queues-events-scheduling.md` |
| Notification / Mail | `.harness/guides/notifications-and-mail.md` |
| Testing / Validation | `.harness/guides/testing-and-validation.md` |
| Modules 结构 | `.harness/guides/laravel-modules.md` |
| 审查 | `.harness/guides/review-checklist.md` |

### Step 3：按结构组织内容

- Controller 只做接收、授权、调用、返回
- Form Request 做校验和授权入口
- API Resource 负责序列化
- Action / Service 承担业务编排
- Repository / Query Object / Eloquent 承担数据访问
- Job / Listener / Notification 保持职责单一

### Step 4：检查合规

优先跑项目已有命令：

```bash
composer test
composer pint --test
./vendor/bin/phpstan analyse
./vendor/bin/psalm
```

没有统一入口时至少：

```bash
php artisan about
php artisan test
php artisan route:list
```

## 默认审查重点

- Queue Job 幂等、重试、失败路径
- Scheduler 可重复执行与日志可观测性
- Event / Listener 是否隐藏 IO 和递归触发
- Notification / Mail 是否异步、安全、可审计
- Eloquent 是否存在 N+1、事务缺失、锁错误
- Modules 项目是否存在跨模块乱依赖

## 合规摘要

每次交付附上：

```text
## 合规检查摘要
- [x] Laravel / PHP 版本按项目事实处理
- [x] HTTP / Data / Async 边界明确
- [x] Queue / Scheduler / Event / Notification 已检查
- [x] Modules 规则已按需加载
- [x] 验证结果已给出
- [x] 无编造内容
```
