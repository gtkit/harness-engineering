package breaker

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/sony/gobreaker/v2"
)

var (
	errRemote = errors.New("remote service unavailable")
	errBiz    = errors.New("invalid params") // 业务错误:经 WithIsSuccessful 分类为成功
)

func bizClassifier(err error) bool { return errors.Is(err, errBiz) }

func TestExecuteSuccess(t *testing.T) {
	t.Parallel()
	b := New[string]("test-success")

	result, err := b.Execute(func() (string, error) { return "ok", nil })
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result != "ok" {
		t.Fatalf("result = %q, want %q", result, "ok")
	}
	if b.State() != gobreaker.StateClosed {
		t.Fatalf("state = %v, want Closed", b.State())
	}
}

func TestExecuteFailure(t *testing.T) {
	t.Parallel()
	b := New[string]("test-failure")

	_, err := b.Execute(func() (string, error) { return "", errRemote })
	if !errors.Is(err, errRemote) {
		t.Fatalf("err = %v, want %v", err, errRemote)
	}
}

// --- 默认策略:连续失败 ---

func TestDefaultStrategyTripsOnConsecutiveFailures(t *testing.T) {
	t.Parallel()
	b := New[string]("test-consecutive")

	for range DefaultConsecutiveFailures {
		_, _ = b.Execute(func() (string, error) { return "", errRemote })
	}
	if b.State() != gobreaker.StateOpen {
		t.Fatalf("state = %v, want Open after %d consecutive failures", b.State(), DefaultConsecutiveFailures)
	}

	// 熔断打开后请求直接被拒绝,fn 不执行
	executed := false
	_, err := b.Execute(func() (string, error) {
		executed = true
		return "should-not-reach", nil
	})
	if executed {
		t.Fatal("fn should not execute when breaker is open")
	}
	if !IsRejected(err) {
		t.Fatalf("err = %v, want rejected", err)
	}
}

func TestDefaultStrategySuccessResetsStreak(t *testing.T) {
	t.Parallel()
	b := New[string]("test-streak-reset")

	// 4 失败 + 1 成功 + 4 失败:从未连续满 5,保持闭合
	for range 4 {
		_, _ = b.Execute(func() (string, error) { return "", errRemote })
	}
	_, _ = b.Execute(func() (string, error) { return "ok", nil })
	for range 4 {
		_, _ = b.Execute(func() (string, error) { return "", errRemote })
	}
	if b.State() != gobreaker.StateClosed {
		t.Fatalf("state = %v, want Closed (streak was reset)", b.State())
	}
}

func TestCallerCancelExcluded(t *testing.T) {
	t.Parallel()
	b := New[string]("test-cancel-excluded")

	// 调用方取消不计失败:连打 10 次也不熔断
	for range 10 {
		_, _ = b.Execute(func() (string, error) { return "", context.Canceled })
	}
	if b.State() != gobreaker.StateClosed {
		t.Fatalf("state = %v, want Closed (canceled excluded)", b.State())
	}
}

// --- 错误率策略 ---

func TestRatioStrategyTripsAfterThreshold(t *testing.T) {
	t.Parallel()
	b := New[string]("test-ratio-trip", WithErrorRatio(5, 60, time.Minute))

	for range 5 {
		_, _ = b.Execute(func() (string, error) { return "", errRemote })
	}
	if b.State() != gobreaker.StateOpen {
		t.Fatalf("state = %v, want Open after 5/5 failures >= 60%%", b.State())
	}
}

func TestRatioStrategyStaysClosedBelowMinRequests(t *testing.T) {
	t.Parallel()
	b := New[string]("test-below-min", WithErrorRatio(10, 50, time.Minute))

	for range 5 {
		_, _ = b.Execute(func() (string, error) { return "", errRemote })
	}
	if b.State() != gobreaker.StateClosed {
		t.Fatalf("state = %v, want Closed (below min requests)", b.State())
	}
}

func TestRatioStrategyStaysClosedBelowErrorRatio(t *testing.T) {
	t.Parallel()
	b := New[string]("test-below-ratio", WithErrorRatio(5, 60, time.Minute))

	// 2 失败 + 3 成功 = 40% 错误率,低于 60% 阈值
	for range 2 {
		_, _ = b.Execute(func() (string, error) { return "", errRemote })
	}
	for range 3 {
		_, _ = b.Execute(func() (string, error) { return "ok", nil })
	}
	if b.State() != gobreaker.StateClosed {
		t.Fatalf("state = %v, want Closed (error ratio 40%% < 60%%)", b.State())
	}
}

// --- 业务错误分类 ---

func TestBusinessErrorDoesNotTripBreaker(t *testing.T) {
	t.Parallel()
	b := New[string]("test-biz-error", WithIsSuccessful(bizClassifier))

	for range 10 {
		_, err := b.Execute(func() (string, error) { return "", errBiz })
		if !errors.Is(err, errBiz) {
			t.Fatalf("err = %v, want %v", err, errBiz)
		}
	}
	if b.State() != gobreaker.StateClosed {
		t.Fatalf("state = %v, want Closed (business errors should not trip breaker)", b.State())
	}
}

func TestMixedBusinessAndInfraErrors(t *testing.T) {
	t.Parallel()
	// 业务错误重置连续失败计数(计成功):3 infra + 1 biz + 3 infra,连续失败从未达 5
	b := New[string]("test-mixed-errors", WithIsSuccessful(bizClassifier))

	for range 3 {
		_, _ = b.Execute(func() (string, error) { return "", errRemote })
	}
	_, _ = b.Execute(func() (string, error) { return "", errBiz })
	for range 3 {
		_, _ = b.Execute(func() (string, error) { return "", errRemote })
	}
	if b.State() != gobreaker.StateClosed {
		t.Fatalf("state = %v, want Closed (biz error resets streak)", b.State())
	}
}

// --- 半开恢复 ---

func TestBreakerRecoveryFromOpenToHalfOpenToClosed(t *testing.T) {
	t.Parallel()
	b := New[string]("test-recovery",
		WithConsecutiveFailures(3),
		WithRecoverTimeout(100*time.Millisecond), // 极短冷却用于测试
		WithMaxRequests(1),
	)

	for range 3 {
		_, _ = b.Execute(func() (string, error) { return "", errRemote })
	}
	if b.State() != gobreaker.StateOpen {
		t.Fatalf("state = %v, want Open", b.State())
	}

	time.Sleep(150 * time.Millisecond)
	if b.State() != gobreaker.StateHalfOpen {
		t.Fatalf("state = %v, want HalfOpen after recover timeout", b.State())
	}

	// 半开探测成功 → 闭合
	result, err := b.Execute(func() (string, error) { return "recovered", nil })
	if err != nil {
		t.Fatalf("unexpected error in half-open: %v", err)
	}
	if result != "recovered" {
		t.Fatalf("result = %q, want %q", result, "recovered")
	}
	if b.State() != gobreaker.StateClosed {
		t.Fatalf("state = %v, want Closed after successful probe", b.State())
	}
}

func TestBreakerHalfOpenProbeFailureReturnsToOpen(t *testing.T) {
	t.Parallel()
	b := New[string]("test-half-open-fail",
		WithConsecutiveFailures(3),
		WithRecoverTimeout(100*time.Millisecond),
		WithMaxRequests(1),
	)

	for range 3 {
		_, _ = b.Execute(func() (string, error) { return "", errRemote })
	}
	time.Sleep(150 * time.Millisecond)
	if b.State() != gobreaker.StateHalfOpen {
		t.Fatalf("state = %v, want HalfOpen", b.State())
	}

	// 半开探测失败 → 重新打开
	_, _ = b.Execute(func() (string, error) { return "", errRemote })
	if b.State() != gobreaker.StateOpen {
		t.Fatalf("state = %v, want Open after failed probe", b.State())
	}
}

// --- 并发安全 ---

func TestBreakerConcurrentSafety(t *testing.T) {
	t.Parallel()
	b := New[int]("test-concurrent")

	var wg sync.WaitGroup
	var successCount, errorCount atomic.Int64
	for range 200 {
		wg.Go(func() {
			if _, err := b.Execute(func() (int, error) { return 42, nil }); err != nil {
				errorCount.Add(1)
			} else {
				successCount.Add(1)
			}
		})
	}
	wg.Wait()

	if successCount.Load() != 200 {
		t.Fatalf("success = %d, want 200", successCount.Load())
	}
	if errorCount.Load() != 0 {
		t.Fatalf("errors = %d, want 0", errorCount.Load())
	}
	if b.State() != gobreaker.StateClosed {
		t.Fatalf("state = %v, want Closed", b.State())
	}
}

// --- 其他 ---

func TestNameReturnsConfiguredName(t *testing.T) {
	t.Parallel()
	b := New[int]("my-breaker")
	if b.Name() != "my-breaker" {
		t.Fatalf("name = %q, want %q", b.Name(), "my-breaker")
	}
}

func TestDefaultOptions(t *testing.T) {
	t.Parallel()
	cfg := defaultConfig()
	if cfg.maxRequests != DefaultMaxRequests {
		t.Fatalf("maxRequests = %d, want %d", cfg.maxRequests, DefaultMaxRequests)
	}
	if cfg.recoverTimeout != DefaultRecoverTimeout {
		t.Fatalf("recoverTimeout = %v, want %v", cfg.recoverTimeout, DefaultRecoverTimeout)
	}
	if cfg.consecutiveFailures != DefaultConsecutiveFailures {
		t.Fatalf("consecutiveFailures = %d, want %d", cfg.consecutiveFailures, DefaultConsecutiveFailures)
	}
	if cfg.ratioMinRequests != 0 {
		t.Fatalf("ratioMinRequests = %d, want 0 (ratio strategy off by default)", cfg.ratioMinRequests)
	}
}
