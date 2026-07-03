// Package bootstrap 做进程级编排:装配 gRPC server、拦截器、注册服务,承载 Run 全流程。
package bootstrap

import (
	"context"

	"github.com/gtkit/golimit"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/reflection"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/proto"

	examplev1 "example-grpc-service/pb/example/v1"
)

// NewGRPCServer 组装 gRPC server:恢复 + 限流 + 参数校验拦截器,注册服务与反射。
//
// validate 由调用方注入(protovalidate 的 Validate),便于测试替换。
// rateLimitQPS 为全局 QPS 限流值,<=0 表示关闭(不注册限流拦截器)。
// 拦截器顺序:recovery 最外层(兜住后续阶段 panic)→ 限流(先限流再校验,省 CPU)→ 校验。
func NewGRPCServer(exampleSvc examplev1.ExampleServiceServer, validate func(proto.Message) error, rateLimitQPS int) *grpc.Server {
	ints := []grpc.UnaryServerInterceptor{recoveryUnaryInterceptor()}
	if rateLimitQPS > 0 {
		ints = append(ints, rateLimitUnaryInterceptor(rateLimitQPS))
	}
	ints = append(ints, validationUnaryInterceptor(validate))

	srv := grpc.NewServer(grpc.ChainUnaryInterceptor(ints...))
	examplev1.RegisterExampleServiceServer(srv, exampleSvc)
	reflection.Register(srv) // 便于 grpcurl / buf curl 免 proto 调试
	return srv
}

// recoveryUnaryInterceptor 捕获 handler panic,转成 Internal,避免单个 RPC 拖垮整个进程。
func recoveryUnaryInterceptor() grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req any, _ *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (resp any, err error) {
		defer func() {
			if r := recover(); r != nil {
				err = status.Error(codes.Internal, "internal server error")
			}
		}()
		return handler(ctx, req)
	}
}

// rateLimitUnaryInterceptor 全局 QPS 限流(gtkit/golimit 令牌桶,初始 burst=qps)。
// 超限立即返回 ResourceExhausted,不进入校验与业务。
func rateLimitUnaryInterceptor(qps int) grpc.UnaryServerInterceptor {
	limiter := golimit.NewLimiter("grpc:global", qps)
	return func(ctx context.Context, req any, _ *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		if !limiter.Allow() {
			return nil, status.Error(codes.ResourceExhausted, "rate limit exceeded, retry later")
		}
		return handler(ctx, req)
	}
}

// validationUnaryInterceptor 用注入的 validate 校验请求(protovalidate 读描述符里的规则),
// 不通过返回 InvalidArgument。非 proto.Message 请求跳过(理论上不会出现)。
func validationUnaryInterceptor(validate func(proto.Message) error) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req any, _ *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		if m, ok := req.(proto.Message); ok {
			if err := validate(m); err != nil {
				return nil, status.Error(codes.InvalidArgument, err.Error())
			}
		}
		return handler(ctx, req)
	}
}
