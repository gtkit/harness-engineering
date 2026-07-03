// Package application 是 example 模块的业务逻辑层(脚手架示例)。
//
// 依赖全部通过 port 接口注入(使用方定义接口),不 import GORM / repository / 渠道 SDK。
package application

import (
	"context"

	"example-grpc-service/internal/models"
)

// ItemFinder 按 id 查条目。未命中返回 (nil, false, nil)。
//
// 接口由使用方(application)定义,repository 实现;返回中立的 models 类型。
type ItemFinder interface {
	GetByID(ctx context.Context, id string) (*models.ExampleItem, bool, error)
}
