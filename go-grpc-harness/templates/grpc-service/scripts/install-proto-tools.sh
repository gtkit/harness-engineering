#!/usr/bin/env bash
# 一次性安装/更新 proto 工具链:buf + buf.gen.yaml 里的四个 local 插件。
# 适用 macOS / Linux(arm64/amd64 均可):全部经 go install 从源码本机编译,不依赖 brew/apt。
# 唯一前提:已安装 Go 且能访问模块代理。可重复执行,@latest 即装即更新。
set -euo pipefail

if ! command -v go >/dev/null 2>&1; then
  echo "错误: 未找到 go,请先安装 Go (https://go.dev/dl/)" >&2
  exit 1
fi

# 工具实际安装到 $GOBIN(未设置时为 $GOPATH/bin);版本检查直接用绝对路径,
# 不依赖 PATH——新机器上 ~/go/bin 常不在 PATH 里,只在最后提示一次。
BIN_DIR="$(go env GOBIN)"
[ -z "${BIN_DIR}" ] && BIN_DIR="$(go env GOPATH)/bin"

TOOLS=(
  "github.com/bufbuild/buf/cmd/buf@latest"                                   # buf CLI
  "google.golang.org/protobuf/cmd/protoc-gen-go@latest"                      # 消息类型
  "google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest"                     # gRPC 服务桩
  "github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway@latest" # REST 网关
  "github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2@latest"    # OpenAPI 文档
)

for t in "${TOOLS[@]}"; do
  echo "==> go install ${t}"
  go install "${t}"
done

echo
echo "==> 安装结果 (${BIN_DIR}):"
"${BIN_DIR}/buf" --version | sed 's/^/    buf                     /'
"${BIN_DIR}/protoc-gen-go" --version | sed 's/^/    /'
printf "    protoc-gen-go-grpc      %s\n" "$("${BIN_DIR}/protoc-gen-go-grpc" --version | awk '{print $NF}')"
# gateway/openapiv2 无 --version 参数,从二进制构建信息读模块版本
for bin in protoc-gen-grpc-gateway protoc-gen-openapiv2; do
  ver="$(go version -m "${BIN_DIR}/${bin}" | awk '$1=="mod"{print $3; exit}')"
  printf "    %-23s %s\n" "${bin}" "${ver}"
done

# buf generate 按名字调用插件,要求安装目录在 PATH 里
case ":${PATH}:" in
  *":${BIN_DIR}:"*) ;;
  *)
    echo
    echo "注意: ${BIN_DIR} 不在 PATH 里,buf generate 会找不到插件。请在 shell 配置中加入:"
    echo "  export PATH=\"\$PATH:${BIN_DIR}\""
    ;;
esac

echo
echo "完成。若刚更新过插件,建议重新生成产物: rm -rf pb && make gen && go build ./..."
