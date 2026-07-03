.PHONY: gen deps tidy build run test check proto-check proto-export

# 提交前统一检查入口(CLAUDE.md 要求优先使用)。
# proto-check 不在其中:它依赖 buf 工具链,本地按需、CI 必跑(见 guides/ci-sensors.md)。
check:
	golangci-lint run ./...
	go vet ./...
	go test -race -count=1 -timeout=5m ./...
	bash scripts/check-architecture.sh

# proto/pb 一致性门禁:proto 改了但 pb 没同步(或有人手改 pb)即失败。CI 必跑。
proto-check:
	@git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "✗ proto-check 需要在 git 仓库内运行"; exit 1; }
	buf lint
	buf generate
	@git diff --exit-code pb/ proto/ || { echo "✗ pb/ 与 proto/ 不同步:请提交 make gen 产物"; exit 1; }

# buf 依赖导出目标目录:项目内、gitignore、由 buf.lock 重生(供 GoLand 的 Protobuf 插件解析 import)
DEPS_DIR ?= .proto-deps

# 重新生成 proto 代码与 OpenAPI 文档(依赖由 buf.lock 锁定,不在此升级)
gen:
	buf lint
	buf generate

# 显式升级 buf 依赖并刷新 buf.lock(相当于 go get -u,偶发手动执行,不放进 gen)
deps:
	buf dep update

# 导出 buf 第三方依赖到本地目录(消除 GoLand import 报红)
proto-export:
	rm -rf $(DEPS_DIR)
	buf export . --output $(DEPS_DIR)
	rm -rf $(DEPS_DIR)/example

tidy:
	go mod tidy

build:
	CGO_ENABLED=0 go build -trimpath -ldflags "-s -w" -o bin/server ./cmd/server

run:
	go run ./cmd/server -config config/env/env.yml

test:
	go test ./...
