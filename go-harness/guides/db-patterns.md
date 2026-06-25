# 数据库操作规范 Guide

> 分层和事务边界以 `architecture.md` 为准；本文只约束 repository / GORM / 迁移实践。

## Repository 模式

接口定义在使用方 application 层，实现在 repository 层：

```go
type UserRepository interface {
    Create(ctx context.Context, user *models.User) error
    GetByID(ctx context.Context, id int64) (*models.User, bool, error)
    Update(ctx context.Context, userID int64, fields map[string]any) error
    List(ctx context.Context, q UserListQuery) ([]*models.User, int64, error)
}
```

规则：
- 入参用 repo 自己的 query/options 类型，或 application port 的中立输入类型。
- 禁止用带 `binding/form` tag 的 HTTP 请求体当 repo 查询条件。
- Redis / MQ 等外部介质 repo 不适用 GORM 规则，但依赖方向相同。

## GORM 使用规则

### 数据访问统一经 `mdbCtx(ctx)`

推荐 context-tx：

```go
func (r *Repository) mdbCtx(ctx context.Context) *gorm.DB {
    return dbtx.DB(ctx, r.db)
}
```

所有 GORM 访问走 `r.mdbCtx(ctx)`，禁止绕过事务上下文直接用 `r.db`。

### 必须遵守

1. 数据访问走 `mdbCtx(ctx)` 或项目等价的 context-aware DB helper。
2. 禁止全局 DB 变量，通过构造函数注入 `*gorm.DB`。
3. 列表、大表、跨关联查询、对外响应只需部分字段时显式 `.Select(...)` / `.Omit(...)`；简单按主键读取完整聚合可不强制 Select。
4. 批量操作分批，单批默认不超过 500。
5. 软删除使用 `gorm.DeletedAt` 或项目统一约定。
6. 列表查询必须有 LIMIT，默认最大 100。

### 部分更新

部分更新不要用 `Updates(struct)` 承载“只改显式字段”的语义；它会忽略零值。使用 map：

```go
func (r *Repository) UpdateProfile(ctx context.Context, userID int64, fields map[string]any) error {
    if len(fields) == 0 {
        return nil
    }
    return r.mdbCtx(ctx).Model(&models.User{}).
        Where("id = ?", userID).
        Updates(fields).Error
}
```

由 application 根据请求指针字段决定纳入哪些列。

## 事务

单 repo / 聚合内部的多语句原子写可在 repo 内事务：

```go
func (r *OrderRepository) CreateWithItems(ctx context.Context, order *models.Order, items []*models.OrderItem) error {
    return r.mdbCtx(ctx).Transaction(func(tx *gorm.DB) error {
        if err := tx.Create(order).Error; err != nil {
            return fmt.Errorf("create order: %w", err)
        }
        for _, item := range items {
            item.OrderID = order.ID
        }
        if err := tx.CreateInBatches(items, 100).Error; err != nil {
            return fmt.Errorf("create order items: %w", err)
        }
        return nil
    })
}
```

跨多个 repo 的事务由 application `TxManager.Do` 编排，`*gorm.DB` 不出 repository 侧。

## 错误处理

不要把 `gorm.ErrRecordNotFound` 泄漏到 application。单一找不到场景优先 comma-ok：

```go
func (r *ChannelRepository) GetByCode(ctx context.Context, code string) (models.Channel, bool, error) {
    var channel models.Channel
    err := r.mdbCtx(ctx).Where("code = ?", code).First(&channel).Error
    if errors.Is(err, gorm.ErrRecordNotFound) {
        return models.Channel{}, false, nil
    }
    if err != nil {
        return models.Channel{}, false, fmt.Errorf("get channel by code: %w", err)
    }
    return channel, true, nil
}
```

真正跨模块复用的通用语义可创建 `internal/apperror`；没有真实需要时不要提前建空包。

## Redis-only / 外部介质仓储

- 不实现 `mdbCtx`，直接注入 Redis / MQ client。
- 不参与 GORM 事务；需要原子性时用 Lua、SetNX、原子计数等介质自身能力。
- 按职责/聚合组织，不强套“一表一 repo”。

## 防御性查询

- WHERE 用户输入必须参数化，禁止字符串拼接。
- 动态字段名必须白名单。
- Preload/Joins 注意 N+1。
- 大表查询加索引或 explain 验证。
- offset 过大考虑游标分页。

## 连接池配置

```go
sqlDB, err := db.DB()
if err != nil {
    return fmt.Errorf("get sql db: %w", err)
}
sqlDB.SetMaxOpenConns(100)
sqlDB.SetMaxIdleConns(10)
sqlDB.SetConnMaxLifetime(time.Hour)
sqlDB.SetConnMaxIdleTime(10 * time.Minute)
```

## 迁移

- GORM AutoMigrate 仅限本地临时验证，生产禁止依赖它自动改表。
- 若项目尚未统一 migration runtime，脚手架生成的 SQL 只能视为草稿，必须人工审核。
- 生产迁移工具（golang-migrate / goose / 内部平台）必须先在 `migration.md` 写清工具版本、命令、目录、命名和回滚策略。
- 迁移必须可审计：up/down 或等价回滚方案、索引、唯一约束、默认值、comment、数据修复步骤。
