# 文档规范 Guide

## GoDoc 注释

### 包级文档（doc.go）

```go
// Package signutil provides utilities for cryptographic signing and verification.
//
// It supports HMAC-SHA256, RSA, and Ed25519 algorithms with a unified interface.
//
// Basic usage:
//
//	signer := signutil.New(signutil.WithAlgorithm(signutil.HMACSHA256))
//	signature, err := signer.Sign(ctx, payload, key)
package signutil
```

### 类型文档

```go
// Client is the main entry point for signing operations.
// It is safe for concurrent use by multiple goroutines.
type Client struct { ... }
```

### 函数文档

```go
// New creates a Client with the given options.
// If no options are provided, it uses HMAC-SHA256 with default settings.
func New(opts ...Option) *Client { ... }

// Sign generates a signature for the given payload.
// It returns ErrInvalidKey if the key is empty or malformed.
func (c *Client) Sign(ctx context.Context, payload, key []byte) ([]byte, error) { ... }
```

### 规则

- 每个导出的 type / func / const / var 都必须有注释
- 注释第一个词是被注释的名称：`// Client is ...`、`// New creates ...`
- 说明返回的错误类型：`returns ErrTimeout if ...`
- 并发安全性必须标注：`safe for concurrent use` 或 `NOT safe for concurrent use`

## README.md

```markdown
# pkgname

简短一句话描述这个包做什么。

## 安装

go get github.com/yourorg/pkgname

## 快速上手

（最简单的用法，3-5 行代码）

## API 概览

| 函数/方法 | 说明 |
|----------|------|
| `New(opts...)` | 创建实例 |
| `client.Do(ctx, req)` | 执行操作 |

## Options

| Option | 默认值 | 说明 |
|--------|-------|------|
| `WithTimeout(d)` | 10s | 超时时间 |
| `WithRetries(n)` | 3 | 重试次数 |

## 错误处理

（列出 sentinel error 和使用方式）

## License

MIT / Apache-2.0
```

## CHANGELOG.md

```markdown
# Changelog

遵循 [Semantic Versioning](https://semver.org/)。

## [Unreleased]

## [1.2.0] - 2026-04-13

### Added
- 新增 `WithConcurrency` option

### Changed
- `Encode` 方法性能提升 30%

### Fixed
- 修复并发场景下的 data race (#42)

## [1.1.0] - 2026-03-20

### Added
- 新增 Ed25519 算法支持

## [1.0.0] - 2026-03-01

### Added
- 初始发布：HMAC-SHA256、RSA 签名与验签
```

### 版本规则

- `v0.x.y`：开发阶段，API 可能变
- `v1.0.0`：首个稳定版，API 承诺兼容
- patch（`v1.0.1`）：bug 修复
- minor（`v1.1.0`）：新增功能，向后兼容
- major（`v2.0.0`）：破坏性变更，module path 加 `/v2`

## LICENSE

- 开源库推荐 MIT 或 Apache-2.0
- 文件放在仓库根目录
