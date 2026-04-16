# Laravel 测试与验证 Guide

## 验证入口

优先使用项目已有脚本：

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

## 测试分层

- Unit：纯逻辑、值对象、简单服务
- Feature：HTTP、授权、验证、资源返回
- Integration：事务、队列、事件、通知、数据库交互

## Laravel Fake

按需使用：

- `Queue::fake()`
- `Bus::fake()`
- `Event::fake()`
- `Notification::fake()`
- `Mail::fake()`

## 强约束覆盖

- Queue Job 至少覆盖 success + retry/fail 路径
- Scheduler 关键命令至少覆盖触发入口与副作用
- Event / Listener 至少覆盖触发与监听行为
- Notification / Mail 至少覆盖发送条件与关键载荷

## 回归要求

- 修复 bug 时优先补回归测试
- 交付前说明本次实际跑过的验证命令
- 没跑到的命令必须明确说明阻塞条件
