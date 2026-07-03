// Package grpc 是 example 模块的 gRPC 传输适配层:pb ↔ application 映射与错误翻译。
// 请求字段校验由 server 级 protovalidate 拦截器执行,此处不重复校验。
package grpc

import (
	"context"
	"errors"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"example-grpc-service/internal/module/example/application"
	examplev1 "example-grpc-service/pb/example/v1"
)

// Handler 实现 examplev1.ExampleServiceServer。
type Handler struct {
	examplev1.UnimplementedExampleServiceServer

	items *application.ItemService
}

// NewHandler 构造 gRPC handler,注入业务服务。
func NewHandler(items *application.ItemService) *Handler {
	return &Handler{items: items}
}

// GetItem 按 id 查询条目。
func (h *Handler) GetItem(ctx context.Context, req *examplev1.GetItemRequest) (*examplev1.GetItemResponse, error) {
	res, err := h.items.GetItem(ctx, req.GetId())
	if err != nil {
		return nil, toStatus(err)
	}
	return &examplev1.GetItemResponse{
		Id:        res.ID,
		Name:      res.Name,
		CreatedAt: res.CreatedAt,
	}, nil
}

// toStatus 把领域错误翻译为 gRPC status(errors.Is 匹配 sentinel;错误信息对外简洁脱敏)。
func toStatus(err error) error {
	switch {
	case errors.Is(err, application.ErrItemNotFound):
		return status.Error(codes.NotFound, "item not found")
	default:
		return status.Error(codes.Internal, "internal error")
	}
}
