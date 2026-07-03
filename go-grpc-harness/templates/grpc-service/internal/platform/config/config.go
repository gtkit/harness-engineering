// Package config 从外置 YAML 文件加载并校验运行配置(进程启动时一次性读取,fail-fast)。
package config

import (
	"bytes"
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

// Config 是进程级配置。敏感项(如 mysql.password)只从外置文件注入,不入库、不编译进二进制。
type Config struct {
	Env   string      `yaml:"env"` // dev/test/prod,决定环境,不依赖文件名
	Log   LogConfig   `yaml:"log"`
	GRPC  GRPCConfig  `yaml:"grpc"`
	MySQL MySQLConfig `yaml:"mysql"`
}

// LogConfig 是日志配置(gtkit/logger)。
type LogConfig struct {
	Level string `yaml:"level"` // debug/info/warn/error,默认 info
	JSON  bool   `yaml:"json"`  // true 输出 JSON 格式;显式开关,不按 env 推导
}

// GRPCConfig 是 gRPC 服务监听配置。
type GRPCConfig struct {
	Addr         string `yaml:"addr"`         // 监听地址,如 ":9090"
	RateLimitQPS int    `yaml:"ratelimitqps"` // 全局 QPS 限流;0/缺省=关闭(显式启用,不做隐式默认限流)
	// 优雅关闭等待上限(秒):超时后强制 Stop,防长请求让进程无限等。缺省 30。
	ShutdownTimeoutSeconds int `yaml:"shutdowntimeoutseconds"`
}

// MySQLConfig 是 MySQL 连接配置。
// DSN 由 ormx 内部构建;charset/parseTime/loc 不再配置(ormx 默认 ParseTime 开、
// 时区 Local,go-sql-driver 默认字符集 utf8mb4,与原固定参数完全等价)。
type MySQLConfig struct {
	Host           string `yaml:"host"`
	Port           string `yaml:"port"` // 字符串,兼容配置里带引号的写法
	User           string `yaml:"user"`
	Password       string `yaml:"password"`
	DBName         string `yaml:"dbname"`
	MaxIdleConn    int    `yaml:"maxidleconn"`    // 空闲连接数,须 <= MaxOpenConn
	MaxOpenConn    int    `yaml:"maxopenconn"`    // 最大打开连接数
	MaxLifeSeconds int    `yaml:"maxlifeseconds"` // 连接最大存活秒数
}

// Load 读取并校验配置文件;找不到、缺关键项或含未知键直接返回 error(fail-fast)。
//
// 严格解析(KnownFields):拼错的键、已废弃的键都会在启动时报错定位,
// 杜绝"配置写了但静默失效"——对支付服务这比向前兼容更重要。
func Load(path string) (*Config, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read config %q: %w", path, err)
	}
	dec := yaml.NewDecoder(bytes.NewReader(b))
	dec.KnownFields(true)
	var c Config
	if err := dec.Decode(&c); err != nil {
		return nil, fmt.Errorf("parse config %q: %w", path, err)
	}
	if c.Log.Level == "" {
		c.Log.Level = "info"
	}
	if c.GRPC.Addr == "" {
		c.GRPC.Addr = ":9090"
	}
	if c.GRPC.ShutdownTimeoutSeconds <= 0 {
		c.GRPC.ShutdownTimeoutSeconds = 30
	}
	if c.MySQL.Host == "" || c.MySQL.DBName == "" {
		return nil, fmt.Errorf("config %q: mysql.host 与 mysql.dbname 必填", path)
	}
	return &c, nil
}
