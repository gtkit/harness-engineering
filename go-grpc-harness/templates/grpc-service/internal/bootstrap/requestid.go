package bootstrap

import (
	"context"
	"crypto/rand"
	"encoding/hex"

	"go.uber.org/zap"
	"google.golang.org/grpc"
	"google.golang.org/grpc/metadata"
)

// requestIDHeader 是链路标识的 metadata/响应头键(与 HTTP 生态惯例一致)。
const requestIDHeader = "x-request-id"

// requestIDKey 是 context 键(自定义类型防碰撞)。
type requestIDKey struct{}

// requestIDFromContext 取出链路标识;没有返回空串。
func requestIDFromContext(ctx context.Context) string {
	id, _ := ctx.Value(requestIDKey{}).(string)
	return id
}

// loggerContextFields 供 gtkit/logger 的 WithContextFields 注入:
// 业务代码用 logger.XxxwCtx(ctx, ...) 记日志即可自动携带 request_id 字段。
func loggerContextFields(ctx context.Context) []zap.Field {
	if id := requestIDFromContext(ctx); id != "" {
		return []zap.Field{zap.String("request_id", id)}
	}
	return nil
}

// requestIDUnaryInterceptor 提取(或生成)request_id:入 ctx 供日志/透传,回写响应头供调用方关联。
func requestIDUnaryInterceptor() grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req any, _ *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		ctx, id := ensureRequestID(ctx)
		_ = grpc.SetHeader(ctx, metadata.Pairs(requestIDHeader, id)) // 响应头尽力而为
		return handler(ctx, req)
	}
}

// requestIDStreamInterceptor 是 request_id 的 stream 版本。
func requestIDStreamInterceptor() grpc.StreamServerInterceptor {
	return func(srv any, ss grpc.ServerStream, _ *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
		ctx, id := ensureRequestID(ss.Context())
		_ = ss.SetHeader(metadata.Pairs(requestIDHeader, id))
		return handler(srv, &ctxServerStream{ServerStream: ss, ctx: ctx})
	}
}

// ensureRequestID 复用调用方传入的 x-request-id(跨服务链路贯通),缺失则生成。
func ensureRequestID(ctx context.Context) (context.Context, string) {
	var id string
	if md, ok := metadata.FromIncomingContext(ctx); ok {
		if vals := md.Get(requestIDHeader); len(vals) > 0 && vals[0] != "" {
			id = vals[0]
		}
	}
	if id == "" {
		id = newRequestID()
	}
	return context.WithValue(ctx, requestIDKey{}, id), id
}

// newRequestID 生成 16 字符 hex 标识(crypto/rand,零外部依赖)。
func newRequestID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "rid-unavailable" // 理论不可达:系统熵源故障
	}
	return hex.EncodeToString(b[:])
}

// ctxServerStream 用替换过的 ctx 包装 ServerStream。
type ctxServerStream struct {
	grpc.ServerStream
	ctx context.Context
}

func (s *ctxServerStream) Context() context.Context { return s.ctx }
