package application

import "errors"

// 领域错误:transport 层据此翻译 gRPC status code(errors.Is 匹配)。
var (
	// ErrItemNotFound 表示按 id 找不到条目。
	ErrItemNotFound = errors.New("example: item not found")
)
