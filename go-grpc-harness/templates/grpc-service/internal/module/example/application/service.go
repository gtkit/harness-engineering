package application

import (
	"context"
	"strconv"
)

// ItemService 是示例业务服务:演示 port 注入、领域错误与中立 result。
type ItemService struct {
	finder ItemFinder
}

// NewItemService 构造服务。
func NewItemService(finder ItemFinder) *ItemService {
	return &ItemService{finder: finder}
}

// ItemResult 是查询出参(中立类型,不引用 pb)。
type ItemResult struct {
	ID        string
	Name      string
	CreatedAt string // Unix 秒,字符串
}

// GetItem 按 id 查询条目;未命中返回 ErrItemNotFound。
func (s *ItemService) GetItem(ctx context.Context, id string) (ItemResult, error) {
	item, found, err := s.finder.GetByID(ctx, id)
	if err != nil {
		return ItemResult{}, err
	}
	if !found {
		return ItemResult{}, ErrItemNotFound
	}
	return ItemResult{
		ID:        item.ID,
		Name:      item.Name,
		CreatedAt: strconv.FormatInt(item.CreatedAt.Unix(), 10),
	}, nil
}
