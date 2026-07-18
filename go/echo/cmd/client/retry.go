package main

import (
	"context"
	"errors"
	"net"
	"time"

	"connectrpc.com/connect"
)

const (
	maxRetries     = 5
	initialBackoff = time.Second
)

var errRetryAborted = errors.New("retry aborted")

// newRetryInterceptor retries transient unary RPC failures with exponential backoff.
func newRetryInterceptor() connect.Interceptor { //nolint:ireturn // Connect requires Interceptor
	return connect.UnaryInterceptorFunc(func(next connect.UnaryFunc) connect.UnaryFunc {
		return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
			return retryUnary(ctx, req, next)
		}
	})
}

func retryUnary( //nolint:ireturn // Connect UnaryFunc returns AnyResponse
	ctx context.Context,
	req connect.AnyRequest,
	next connect.UnaryFunc,
) (connect.AnyResponse, error) {
	var last error

	for attempt := range maxRetries {
		res, err := next(ctx, req)
		if err == nil {
			return res, nil
		}

		last = err
		if !isRetryable(err) || attempt == maxRetries-1 {
			return nil, err
		}

		if waitErr := waitBackoff(ctx, initialBackoff<<attempt); waitErr != nil {
			return nil, errors.Join(last, waitErr)
		}
	}

	return nil, last
}

func waitBackoff(ctx context.Context, d time.Duration) error {
	timer := time.NewTimer(d)
	defer timer.Stop()

	select {
	case <-ctx.Done():
		return errors.Join(errRetryAborted, ctx.Err())
	case <-timer.C:
		return nil
	}
}

func isRetryable(err error) bool {
	if err == nil || errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
		return false
	}

	code := connect.CodeOf(err)
	if code == connect.CodeUnavailable || code == connect.CodeResourceExhausted {
		return true
	}

	// Non-Connect transport failures (e.g. dial errors) are also transient.
	if netErr, ok := errors.AsType[net.Error](err); ok && netErr.Timeout() {
		return true
	}

	opErr, isOpErr := errors.AsType[*net.OpError](err)

	return isOpErr && opErr != nil
}
