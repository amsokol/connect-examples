package main

import (
	"context"
	"testing"

	apiv1 "github.com/amsokol/connect-examples/go/api/v1"
)

func TestEchoServer_Echo(t *testing.T) {
	t.Parallel()

	var req apiv1.EchoRequest

	req.SetMessage("Jane")

	res, err := (&EchoServer{}).Echo(context.Background(), &req)
	if err != nil {
		t.Fatalf("Echo() error = %v", err)
	}

	const want = "Hello, Jane!"

	if got := res.GetMessage(); got != want {
		t.Errorf("Echo() message = %q, want %q", got, want)
	}
}
