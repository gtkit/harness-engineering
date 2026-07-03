package breaker_test

import (
	"fmt"

	"example-grpc-service/internal/pkg/breaker"
)

func ExampleBreaker() {
	// 面向低 QPS 外部渠道(如 360 支付)的熔断器:
	// 默认连续 5 次故障打开、30s 后半开放行 1 个探测;
	// 业务类错误通过 WithIsSuccessful 分类为成功,不触发熔断。
	b := breaker.New[string]("channel:demo-app")

	result, err := b.Execute(func() (string, error) {
		// 这里放真正的外部调用
		return "header-tid-123", nil
	})

	fmt.Println(result, err)
	// Output: header-tid-123 <nil>
}
