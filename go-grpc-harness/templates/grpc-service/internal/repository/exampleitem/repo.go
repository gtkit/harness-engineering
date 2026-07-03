// Package exampleitem 是 example_items 表的数据访问层(脚手架示例)。
package exampleitem

import (
	"context"
	"errors"
	"fmt"

	"gorm.io/gorm"

	"example-grpc-service/internal/models"
)

// Repository 读取 example_items。只读示例,无事务需求,直接用 WithContext。
type Repository struct {
	db *gorm.DB
}

// NewRepository 构造 repository。
func NewRepository(db *gorm.DB) *Repository {
	return &Repository{db: db}
}

// GetByID 按 id 查条目。未命中返回 (nil, false, nil),不泄漏 gorm.ErrRecordNotFound(comma-ok 模式)。
func (r *Repository) GetByID(ctx context.Context, id string) (*models.ExampleItem, bool, error) {
	var item models.ExampleItem
	err := r.db.WithContext(ctx).Where("id = ?", id).First(&item).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, fmt.Errorf("get example_item %q: %w", id, err)
	}
	return &item, true, nil
}
