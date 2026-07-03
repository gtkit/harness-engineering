package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeTemp(t *testing.T, content string) string {
	t.Helper()
	p := filepath.Join(t.TempDir(), "env.yml")
	if err := os.WriteFile(p, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	return p
}

const validYAML = `env: dev
log:
  level: "warn"
grpc:
  addr: ":9091"
  ratelimitqps: 50
mysql:
  host: "127.0.0.1"
  port: "3306"
  user: "u"
  password: "p"
  dbname: "d"
`

func TestLoad(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		yaml    string
		wantErr string // 空=成功;否则错误信息须包含该子串
		check   func(t *testing.T, c *Config)
	}{
		{
			name: "合法配置加载成功",
			yaml: validYAML,
			check: func(t *testing.T, c *Config) {
				if c.Log.Level != "warn" || c.GRPC.Addr != ":9091" || c.GRPC.RateLimitQPS != 50 {
					t.Fatalf("fields mismatch: %+v", c)
				}
			},
		},
		{
			name: "缺省值生效",
			yaml: "env: dev\nmysql:\n  host: \"127.0.0.1\"\n  dbname: \"d\"\n",
			check: func(t *testing.T, c *Config) {
				if c.Log.Level != "info" || c.GRPC.Addr != ":9090" {
					t.Fatalf("defaults mismatch: %+v", c)
				}
			},
		},
		{
			name:    "未知键 fail-fast(已废弃的 mysql.params)",
			yaml:    strings.Replace(validYAML, "  dbname: \"d\"\n", "  dbname: \"d\"\n  params: \"charset=utf8mb4\"\n", 1),
			wantErr: "params",
		},
		{
			name:    "拼错的键 fail-fast",
			yaml:    strings.Replace(validYAML, "ratelimitqps", "ratelimitqp", 1),
			wantErr: "ratelimitqp",
		},
		{
			name:    "缺必填项报错",
			yaml:    "env: dev\n",
			wantErr: "必填",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			c, err := Load(writeTemp(t, tt.yaml))
			if tt.wantErr != "" {
				if err == nil || !strings.Contains(err.Error(), tt.wantErr) {
					t.Fatalf("want error containing %q, got %v", tt.wantErr, err)
				}
				return
			}
			if err != nil {
				t.Fatalf("want nil err, got %v", err)
			}
			tt.check(t, c)
		})
	}
}

func TestLoad_FileNotFound(t *testing.T) {
	t.Parallel()
	if _, err := Load(filepath.Join(t.TempDir(), "absent.yml")); err == nil {
		t.Fatal("want error for missing file")
	}
}
