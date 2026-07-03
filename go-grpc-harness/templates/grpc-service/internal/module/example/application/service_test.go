package application

import (
	"context"
	"errors"
	"testing"
	"time"

	"example-grpc-service/internal/models"
)

// fakeFinder 是 ItemFinder 的测试替身(port 经接口注入,application 可独立单测)。
type fakeFinder struct {
	item  *models.ExampleItem
	found bool
	err   error
}

func (f *fakeFinder) GetByID(_ context.Context, _ string) (*models.ExampleItem, bool, error) {
	return f.item, f.found, f.err
}

func TestItemService_GetItem(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		finder  *fakeFinder
		wantErr error // nil=成功
		wantID  string
	}{
		{
			name: "命中返回条目",
			finder: &fakeFinder{
				item:  &models.ExampleItem{ID: "it-1", Name: "demo", CreatedAt: time.Unix(1_750_000_000, 0)},
				found: true,
			},
			wantID: "it-1",
		},
		{
			name:    "未命中返回 ErrItemNotFound",
			finder:  &fakeFinder{found: false},
			wantErr: ErrItemNotFound,
		},
		{
			name:    "底层故障上抛",
			finder:  &fakeFinder{err: errors.New("db down")},
			wantErr: nil, // 用 err!=nil 单独断言
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			svc := NewItemService(tt.finder)
			res, err := svc.GetItem(context.Background(), "it-1")

			switch {
			case tt.finder.err != nil:
				if err == nil {
					t.Fatal("want error, got nil")
				}
			case tt.wantErr != nil:
				if !errors.Is(err, tt.wantErr) {
					t.Fatalf("want %v, got %v", tt.wantErr, err)
				}
			default:
				if err != nil {
					t.Fatalf("want nil err, got %v", err)
				}
				if res.ID != tt.wantID || res.CreatedAt == "" {
					t.Fatalf("result mismatch: %+v", res)
				}
			}
		})
	}
}
