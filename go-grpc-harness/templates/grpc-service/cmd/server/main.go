// Command server 启动 gRPC 服务。装配与运行编排见 internal/bootstrap.Run。
package main

import (
	"flag"

	"github.com/gtkit/logger"

	"example-grpc-service/internal/bootstrap"
)

func main() {
	cfgPath := flag.String("config", "config/env/env.yml", "配置文件路径")
	flag.Parse()

	// Run 内部第一步即初始化 logger;仅 logger 自身初始化失败的分支消息会丢失,
	// 但 zap 保证 Fatal 级仍以非零码退出。
	if err := bootstrap.Run(*cfgPath); err != nil {
		logger.Fatalf("service exit: %v", err)
	}
}
