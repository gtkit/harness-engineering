// Package example 是 example 模块的装配层:把 db 翻译成 repo,再注入 application 组件。
//
// 渠道 SDK、熔断器(internal/pkg/breaker)只允许出现在 runtime 层;
// 外部 client 若有全局唯一性约束(如 token 互斥),必须在此单点供给。
package example

import (
	"gorm.io/gorm"

	"example-grpc-service/internal/module/example/application"
	"example-grpc-service/internal/repository/exampleitem"
)

// Build 装配 example 模块:db → repository → ItemService。
func Build(db *gorm.DB) *application.ItemService {
	return application.NewItemService(exampleitem.NewRepository(db))
}
