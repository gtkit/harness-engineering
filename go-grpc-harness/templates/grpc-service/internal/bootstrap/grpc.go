// Package bootstrap 做进程级编排:装配 gRPC server、拦截器、注册服务,承载 Run 全流程。
package bootstrap

import (
	"context"

	"github.com/gtkit/golimit"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/proto"

	examplev1 "example-grpc-service/pb/example/v1"
)

// NewGRPCServer 组装 gRPC server:恢复 + request_id + 限流 + 参数校验拦截器(unary/stream 同链),
// 注册业务服务、grpc.health.v1 健康探针与反射。
//
// validate 由调用方注入(protovalidate 的 Validate),便于测试替换。
// rateLimitQPS 为全局 QPS 限流值,<=0 表示关闭(不注册限流拦截器)。
// 返回的 *health.Server 供优雅关闭时先置 NOT_SERVING 摘流量。
// 拦截器顺序:recovery 最外层(兜住后续阶段 panic)→ request_id → 限流 → 校验。
func NewGRPCServer(exampleSvc examplev1.ExampleServiceServer, validate func(proto.Message) error, rateLimitQPS int) (*grpc.Server, *health.Server) {
	unary := []grpc.UnaryServerInterceptor{recoveryUnaryInterceptor(), requestIDUnaryInterceptor()}
	stream := []grpc.StreamServerInterceptor{recoveryStreamInterceptor(), requestIDStreamInterceptor()}
	if rateLimitQPS > 0 {
		limiter := golimit.NewLimiter("grpc:global", rateLimitQPS)
		unary = append(unary, rateLimitUnaryInterceptor(limiter))
		stream = append(stream, rateLimitStreamInterceptor(limiter))
	}
	unary = append(unary, validationUnaryInterceptor(validate))
	stream = append(stream, validationStreamInterceptor(validate))

	srv := grpc.NewServer(
		grpc.ChainUnaryInterceptor(unary...),
		grpc.ChainStreamInterceptor(stream...),
	)
	examplev1.RegisterExampleServiceServer(srv, exampleSvc)

	// grpc.health.v1:探活标准协议(grpc-health-probe / k8s / LB 可直接用)。
	hs := health.NewServer()
	healthpb.RegisterHealthServer(srv, hs)
	hs.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)

	reflection.Register(srv) // 便于 grpcurl / buf curl 免 proto 调试
	return srv, hs
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

// recoveryStreamInterceptor 是 recovery 的 stream 版本。
func recoveryStreamInterceptor() grpc.StreamServerInterceptor {
	return func(srv any, ss grpc.ServerStream, _ *grpc.StreamServerInfo, handler grpc.StreamHandler) (err error) {
		defer func() {
			if r := recover(); r != nil {
				err = status.Error(codes.Internal, "internal server error")
			}
		}()
		return handler(srv, ss)
	}
}

// rateLimitUnaryInterceptor 全局 QPS 限流(gtkit/golimit 令牌桶,初始 burst=qps)。
// 超限立即返回 ResourceExhausted,不进入校验与业务。
func rateLimitUnaryInterceptor(limiter *golimit.Limiter) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req any, _ *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		if !limiter.Allow() {
			return nil, status.Error(codes.ResourceExhausted, "rate limit exceeded, retry later")
		}
		return handler(ctx, req)
	}
}

// rateLimitStreamInterceptor 是限流的 stream 版本(按建流计数)。
func rateLimitStreamInterceptor(limiter *golimit.Limiter) grpc.StreamServerInterceptor {
	return func(srv any, ss grpc.ServerStream, _ *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
		if !limiter.Allow() {
			return status.Error(codes.ResourceExhausted, "rate limit exceeded, retry later")
		}
		return handler(srv, ss)
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

// validationStreamInterceptor 是校验的 stream 版本:包装 ServerStream,
// 对每条入站消息(RecvMsg)执行 protovalidate 规则。
func validationStreamInterceptor(validate func(proto.Message) error) grpc.StreamServerInterceptor {
	return func(srv any, ss grpc.ServerStream, _ *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
		return handler(srv, &validatingStream{ServerStream: ss, validate: validate})
	}
}

// validatingStream 在 RecvMsg 后校验入站消息。
type validatingStream struct {
	grpc.ServerStream
	validate func(proto.Message) error
}

func (s *validatingStream) RecvMsg(m any) error {
	if err := s.ServerStream.RecvMsg(m); err != nil {
		return err
	}
	if pm, ok := m.(proto.Message); ok {
		if err := s.validate(pm); err != nil {
			return status.Error(codes.InvalidArgument, err.Error())
		}
	}
	return nil
}
