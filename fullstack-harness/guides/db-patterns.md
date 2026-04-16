# 数据库操作规范 Guide

## Repository 模式

每个数据表对应一个 Repository 接口 + 实现：

```go
type UserRepository interface {
    Create(ctx context.Context, user *model.User) error
    GetByID(ctx context.Context, id uint64) (*model.User, error)
    Update(ctx context.Context, user *model.User) error
    Delete(ctx context.Context, id uint64) error
    List(ctx context.Context, opts *dto.ListReq) ([]*model.User, int64, error)
}
```

接口定义在使用方（service 层），实现在 repository 层。

## GORM 使用规则

### 必须遵守

1. **始终传递 ctx**：`db.WithContext(ctx).Find(...)`
2. **禁止全局 DB 变量**：通过构造函数注入 `*gorm.DB`
3. **查询指定字段**：禁止 `SELECT *`，使用 `.Select("id, name, email")`
4. **批量操作分批**：单次 INSERT/UPDATE 不超过 500 条，使用 `CreateInBatches`
5. **软删除使用内置**：`gorm.DeletedAt`
6. **列表查询必须有 LIMIT**：默认最大 100 条

### 事务使用显式方式

```go
func (r *orderRepo) CreateWithItems(ctx context.Context, order *model.Order, items []*model.OrderItem) error {
    return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
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

### 错误处理

```go
func (r *userRepo) GetByID(ctx context.Context, id uint64) (*model.User, error) {
    var user model.User
    if err := r.db.WithContext(ctx).First(&user, id).Error; err != nil {
        if errors.Is(err, gorm.ErrRecordNotFound) {
            return nil, apperror.ErrNotFound // 转换为业务错误
        }
        return nil, fmt.Errorf("get user by id: %w", err)
    }
    return &user, nil
}
```

## 防御性查询

- WHERE 条件中的用户输入必须使用参数化查询，禁止字符串拼接
- 关联查询使用 Preload/Joins 时注意 N+1 问题
- 大表查询加索引提示或 explain 验证
- 分页查询 offset 过大时考虑游标分页（`WHERE id > ?`）

## 连接池配置

```go
sqlDB, _ := db.DB()
sqlDB.SetMaxOpenConns(100)
sqlDB.SetMaxIdleConns(10)
sqlDB.SetConnMaxLifetime(time.Hour)
sqlDB.SetConnMaxIdleTime(10 * time.Minute)
```

## 迁移

- 使用 GORM AutoMigrate 仅限开发环境
- 生产环境使用 golang-migrate 或 goose 管理 SQL 迁移文件
- 迁移脚本必须可回滚（有 up 和 down）
