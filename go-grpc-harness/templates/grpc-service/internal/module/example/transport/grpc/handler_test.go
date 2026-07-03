package grpc

import (
	"errors"
	"fmt"
	"testing"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"example-grpc-service/internal/module/example/application"
)

func TestToStatus(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name string
		in   error
		want codes.Code
	}{
		{name: "条目不存在", in: application.ErrItemNotFound, want: codes.NotFound},
		{name: "包装后的领域错误仍可匹配", in: fmt.Errorf("wrap: %w", application.ErrItemNotFound), want: codes.NotFound},
		{name: "未知错误兜底 Internal", in: errors.New("boom"), want: codes.Internal},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			if got := status.Code(toStatus(tt.in)); got != tt.want {
				t.Fatalf("want %v, got %v", tt.want, got)
			}
		})
	}
}
