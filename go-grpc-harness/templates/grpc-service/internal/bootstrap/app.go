package bootstrap

import (
	"context"
	"fmt"
	"net"
	"os/signal"
	"syscall"
	"time"

	"buf.build/go/protovalidate"
	"github.com/gtkit/logger"
	"github.com/gtkit/ormx"
	"google.golang.org/grpc"
	"google.golang.org/protobuf/proto"

	examplegrpc "example-grpc-service/internal/module/example/transport/grpc"
	"example-grpc-service/internal/platform/config"
	"example-grpc-service/internal/platform/data"
	examplert "example-grpc-service/internal/runtime/module/example"
)

// mysqlConnectTimeout 是建连(含 StartupPing)的兜底超时。
const mysqlConnectTimeout = 15 * time.Second

// Run 装配并运行服务,阻塞至收到 SIGINT/SIGTERM 后优雅退出;装配失败返回 error。
//
// 流程:日志兜底初始化 → 配置 → 日志按配置重初始化 → MySQL(fail-fast) →
// 模块装配 → gRPC 服务 → 信号触发优雅关闭 → 关连接池。
func Run(cfgPath string) error {
	// 日志兜底初始化:gtkit/logger 默认只写文件,须显式开 console;保证后续装配失败的日志可见。
	if err := logger.New(logger.WithConsole(true), logger.WithFile(false)); err != nil {
		return fmt.Errorf("init logger: %w", err)
	}

	cfg, err := config.Load(cfgPath)
	if err != nil {
		return fmt.Errorf("load config: %w", err)
	}
	if err := applyLogConfig(cfg.Log); err != nil {
		return fmt.Errorf("reinit logger: %w", err)
	}

	dbClient, err := openMySQL(cfg.MySQL)
	if err != nil {
		return fmt.Errorf("connect mysql: %w", err)
	}
	// defer 保证错误路径也关池;正常路径上晚于 GracefulStop 执行(在途请求 drain 完才关)。
	defer func() {
		if err := dbClient.Close(); err != nil {
			logger.Warnw("close mysql", "error", err)
		}
	}()

	srv, err := buildGRPCServer(dbClient, cfg.GRPC.RateLimitQPS)
	if err != nil {
		return err
	}

	return serveUntilSignal(srv, cfg.GRPC.Addr)
}

// applyLogConfig 按配置重新初始化日志(logger.New 幂等,官方注明可重复调用)。
func applyLogConfig(cfg config.LogConfig) error {
	return logger.New(
		logger.WithConsole(true),
		logger.WithFile(false),
		logger.WithLevel(cfg.Level),
		logger.WithOutJSON(cfg.JSON),
	)
}

// openMySQL 建立 MySQL 连接;ormx 默认开 StartupPing,DB 不可达立即失败(fail-fast)。
func openMySQL(cfg config.MySQLConfig) (*ormx.Client, error) {
	ctx, cancel := context.WithTimeout(context.Background(), mysqlConnectTimeout)
	defer cancel()
	return data.NewMySQL(ctx, cfg)
}

// buildGRPCServer 装配业务模块与 gRPC server(新增模块在此接线)。
func buildGRPCServer(dbClient *ormx.Client, rateLimitQPS int) (*grpc.Server, error) {
	exampleHandler := examplegrpc.NewHandler(examplert.Build(dbClient.DB()))

	validator, err := protovalidate.New()
	if err != nil {
		return nil, fmt.Errorf("new protovalidate: %w", err)
	}
	validate := func(m proto.Message) error { return validator.Validate(m) }

	return NewGRPCServer(exampleHandler, validate, rateLimitQPS), nil
}

// serveUntilSignal 启动 gRPC 监听并阻塞:收到退出信号则优雅关闭(等在途请求结束),
// 监听自身出错则如实返回(不在 goroutine 里 Fatal,保证调用方清理逻辑可达)。
func serveUntilSignal(srv *grpc.Server, addr string) error {
	lis, err := net.Listen("tcp", addr)
	if err != nil {
		return fmt.Errorf("listen %s: %w", addr, err)
	}

	serveErr := make(chan error, 1)
	go func() {
		logger.Infow("gRPC server listening", "addr", addr)
		serveErr <- srv.Serve(lis)
	}()

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	select {
	case <-ctx.Done():
		logger.Infof("shutting down grpc server...")
		srv.GracefulStop()
		return nil
	case err := <-serveErr:
		return fmt.Errorf("serve grpc: %w", err)
	}
}
