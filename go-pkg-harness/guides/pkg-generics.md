# 泛型应用 Guide

## 何时用泛型

**用：**
- 数据结构（Set、SyncMap、Ring Buffer）
- 通用算法（Filter、Map、Reduce、GroupBy）
- 类型安全的容器/池
- 避免 `any` + 类型断言的场景

**不用：**
- 只有一两个具体类型的场景——直接写具体类型
- 接口已经能解决的问题——不要泛型化接口
- 过度抽象——如果泛型让代码更难读，不用

## 类型约束

```go
// 用标准库的 constraints（Go 1.26 用 cmp 包）
import "cmp"

// 自定义约束
type Number interface {
    ~int | ~int32 | ~int64 | ~float32 | ~float64
}

type Stringer interface {
    String() string
}
```

## 常见模式

### 泛型容器

```go
// Set 是一个泛型集合
type Set[T comparable] struct {
    m map[T]struct{}
}

func NewSet[T comparable](items ...T) *Set[T] {
    s := &Set[T]{m: make(map[T]struct{}, len(items))}
    for _, item := range items {
        s.m[item] = struct{}{}
    }
    return s
}

func (s *Set[T]) Add(item T) { s.m[item] = struct{}{} }
func (s *Set[T]) Has(item T) bool { _, ok := s.m[item]; return ok }
func (s *Set[T]) Len() int { return len(s.m) }
```

### 泛型工具函数

```go
// Filter 返回满足条件的元素切片
func Filter[T any](items []T, fn func(T) bool) []T {
    result := make([]T, 0, len(items))
    for _, item := range items {
        if fn(item) {
            result = append(result, item)
        }
    }
    return result
}

// Map 将切片中每个元素转换为另一个类型
func Map[T, U any](items []T, fn func(T) U) []U {
    result := make([]U, len(items))
    for i, item := range items {
        result[i] = fn(item)
    }
    return result
}

// GroupBy 按 key 分组
func GroupBy[T any, K comparable](items []T, keyFn func(T) K) map[K][]T {
    result := make(map[K][]T)
    for _, item := range items {
        key := keyFn(item)
        result[key] = append(result[key], item)
    }
    return result
}
```

### 优先用标准库

Go 1.26 标准库已经提供了大量泛型工具，**不要重复造轮子**：

```go
import (
    "slices"
    "maps"
    "cmp"
)

// ✗ 不要自己写
func Contains[T comparable](s []T, v T) bool { ... }

// ✓ 用标准库
slices.Contains(s, v)

// ✓ 排序
slices.SortFunc(items, func(a, b Item) int {
    return cmp.Compare(a.Name, b.Name)
})

// ✓ map 操作
keys := maps.Keys(m)
maps.DeleteFunc(m, func(k string, v int) bool { return v == 0 })
```

## 规则

1. **先看标准库有没有**：slices、maps、cmp 包已覆盖大部分常见操作
2. **约束越紧越好**：能用 `comparable` 不用 `any`，能用 `cmp.Ordered` 不用自定义
3. **类型参数命名**：单字母大写 `T`、`K`、`V`、`E`；语义明确时可用短词 `Elem`、`Key`
4. **不要泛型化一切**：如果函数只被一两个类型调用，直接写具体类型
