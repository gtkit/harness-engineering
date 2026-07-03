// Package models 持久化模型 + 跨层共享值类型。
package models

import "time"

// ExampleItem 映射 example_items 表(脚手架示例,换成你的业务表)。
type ExampleItem struct {
	ID        string    `gorm:"column:id;primaryKey"`
	Name      string    `gorm:"column:name"`
	CreatedAt time.Time `gorm:"column:created_at"`
}

// TableName 指定表名。
func (ExampleItem) TableName() string { return "example_items" }
