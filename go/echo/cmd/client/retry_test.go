package main

import (
	"context"
	"errors"
	"net"
	"testing"

	"connectrpc.com/connect"
)

var (
	errBadRequest        = errors.New("bad request")
	errDown              = errors.New("down")
	errBusy              = errors.New("busy")
	errConnectionRefused = errors.New("connection refused")
)

func TestIsRetryable(t *testing.T) {
	t.Parallel()

	tests := []struct {
		err  error
		name string
		want bool
	}{
		{name: "nil", err: nil, want: false},
		{name: "canceled", err: context.Canceled, want: false},
		{name: "deadline exceeded", err: context.DeadlineExceeded, want: false},
		{
			name: "invalid argument",
			err:  connect.NewError(connect.CodeInvalidArgument, errBadRequest),
			want: false,
		},
		{
			name: "unavailable",
			err:  connect.NewError(connect.CodeUnavailable, errDown),
			want: true,
		},
		{
			name: "resource exhausted",
			err:  connect.NewError(connect.CodeResourceExhausted, errBusy),
			want: true,
		},
		{
			name: "op error",
			//nolint:exhaustruct // only Op/Err matter for AsType
			err:  &net.OpError{Op: "dial", Err: errConnectionRefused},
			want: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			if got := isRetryable(tt.err); got != tt.want {
				t.Errorf("isRetryable() = %v, want %v", got, tt.want)
			}
		})
	}
}
