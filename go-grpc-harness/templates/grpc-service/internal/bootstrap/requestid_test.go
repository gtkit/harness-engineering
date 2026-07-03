package bootstrap

import (
	"context"
	"errors"
	"io"
	"testing"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/emptypb"
)

func TestRequestIDUnaryInterceptor(t *testing.T) {
	t.Parallel()
	ic := requestIDUnaryInterceptor()

	t.Run("透传调用方传入的 x-request-id", func(t *testing.T) {
		t.Parallel()
		ctx := metadata.NewIncomingContext(context.Background(), metadata.Pairs(requestIDHeader, "rid-from-caller"))
		var got string
		_, err := ic(ctx, nil, &grpc.UnaryServerInfo{}, func(ctx context.Context, _ any) (any, error) {
			got = requestIDFromContext(ctx)
			return nil, nil
		})
		if err != nil {
			t.Fatal(err)
		}
		if got != "rid-from-caller" {
			t.Fatalf("want rid-from-caller, got %q", got)
		}
	})

	t.Run("缺失时生成非空标识", func(t *testing.T) {
		t.Parallel()
		var got string
		_, err := ic(context.Background(), nil, &grpc.UnaryServerInfo{}, func(ctx context.Context, _ any) (any, error) {
			got = requestIDFromContext(ctx)
			return nil, nil
		})
		if err != nil {
			t.Fatal(err)
		}
		if got == "" {
			t.Fatal("want generated request id, got empty")
		}
	})
}

func TestLoggerContextFields(t *testing.T) {
	t.Parallel()
	if fields := loggerContextFields(context.Background()); fields != nil {
		t.Fatalf("want nil fields without request id, got %v", fields)
	}
	ctx := context.WithValue(context.Background(), requestIDKey{}, "rid-1")
	if fields := loggerContextFields(ctx); len(fields) != 1 {
		t.Fatalf("want 1 field, got %v", fields)
	}
}

// fakeServerStream 是 grpc.ServerStream 的最小测试替身。
type fakeServerStream struct {
	grpc.ServerStream
	msgs []proto.Message
}

func (f *fakeServerStream) Context() context.Context { return context.Background() }
func (f *fakeServerStream) RecvMsg(m any) error {
	if len(f.msgs) == 0 {
		return io.EOF
	}
	f.msgs = f.msgs[:len(f.msgs)-1]
	return nil
}

func TestValidatingStream_RecvMsg(t *testing.T) {
	t.Parallel()

	t.Run("校验失败翻译为 InvalidArgument", func(t *testing.T) {
		t.Parallel()
		vs := &validatingStream{
			ServerStream: &fakeServerStream{msgs: []proto.Message{&emptypb.Empty{}}},
			validate:     func(proto.Message) error { return errors.New("bad field") },
		}
		err := vs.RecvMsg(&emptypb.Empty{})
		if status.Code(err) != codes.InvalidArgument {
			t.Fatalf("want InvalidArgument, got %v", err)
		}
	})

	t.Run("校验通过原样返回", func(t *testing.T) {
		t.Parallel()
		vs := &validatingStream{
			ServerStream: &fakeServerStream{msgs: []proto.Message{&emptypb.Empty{}}},
			validate:     func(proto.Message) error { return nil },
		}
		if err := vs.RecvMsg(&emptypb.Empty{}); err != nil {
			t.Fatalf("want nil, got %v", err)
		}
	})

	t.Run("底层 EOF 不经校验直接透传", func(t *testing.T) {
		t.Parallel()
		vs := &validatingStream{
			ServerStream: &fakeServerStream{},
			validate:     func(proto.Message) error { return errors.New("must not be called") },
		}
		if err := vs.RecvMsg(&emptypb.Empty{}); !errors.Is(err, io.EOF) {
			t.Fatalf("want io.EOF, got %v", err)
		}
	})
}
