// Package data 管理基础设施连接(DB/Redis 等),不承载业务 DAO。
package data

import (
	"context"
	"fmt"
	"time"

	"github.com/gtkit/ormx"

	"example-grpc-service/internal/platform/config"
)

// NewMySQL 经 gtkit/ormx 建立 MySQL 连接。
//
// 行为要点:
//   - TranslateError 开启:唯一键冲突翻译为 gorm.ErrDuplicatedKey;
//   - StartupPing 为 ormx 默认开启:启动即验证连通性,不可达立即报错(fail-fast);
//   - charset/parseTime/loc 不再显式配置:ormx 默认 ParseTime 开、时区 Local,
//     go-sql-driver 默认字符集即 utf8mb4,与原手拼 DSN 完全等价;
//   - 池参数在此显式设置默认(MaxOpen 50 / MaxIdle≤MaxOpen / Lifetime 1h),
//     不依赖 ormx 包内默认,避免默认漂移改变行为。
//
// 返回 *ormx.Client:调用方持有生命周期(Close/将来 HealthCheck),业务层只消费 Client.DB()。
func NewMySQL(ctx context.Context, cfg config.MySQLConfig) (*ormx.Client, error) {
	maxOpen := cfg.MaxOpenConn
	if maxOpen <= 0 {
		maxOpen = 50
	}
	maxIdle := cfg.MaxIdleConn
	if maxIdle <= 0 || maxIdle > maxOpen {
		maxIdle = maxOpen // 遵守 idle <= open 约束
	}
	lifetime := time.Duration(cfg.MaxLifeSeconds) * time.Second
	if lifetime <= 0 {
		lifetime = time.Hour
	}

	cli, err := ormx.Open(ctx,
		ormx.WithHost(cfg.Host),
		ormx.WithPort(cfg.Port),
		ormx.WithUser(cfg.User),
		ormx.WithPassword(cfg.Password),
		ormx.WithDatabase(cfg.DBName),
		ormx.WithTranslateError(true),
		ormx.WithMaxOpenConns(maxOpen),
		ormx.WithMaxIdleConns(maxIdle),
		ormx.WithConnMaxLifetime(lifetime),
	)
	if err != nil {
		return nil, fmt.Errorf("open mysql via ormx: %w", err)
	}
	return cli, nil
}
