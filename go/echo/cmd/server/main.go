// Package main is a Connect Echo service server over HTTP/1.1 and h2c.
package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"time"

	"connectrpc.com/connect"
	"connectrpc.com/grpchealth"
	"connectrpc.com/validate"

	apiv1 "github.com/amsokol/connect-examples/go/api/v1"
)

const readHeaderTimeout = 10 * time.Second

type EchoServer struct{}

func (*EchoServer) Echo(_ context.Context, req *apiv1.EchoRequest) (*apiv1.EchoResponse, error) {
	var res apiv1.EchoResponse

	res.SetMessage(fmt.Sprintf("Hello, %s!", req.GetMessage()))

	return &res, nil
}

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stderr, nil))

	echo := &EchoServer{}
	mux := http.NewServeMux()
	path, handler := apiv1.NewEchoServiceHandler(
		echo,
		// Validation via Protovalidate is almost always recommended.
		// Log interceptor is outermost so rejected requests are still logged.
		connect.WithInterceptors(newLogInterceptor(logger), validate.NewInterceptor()),
	)
	mux.Handle(path, withHTTPProto(handler))

	// grpc.health.v1 for Kubernetes gRPC probes / grpc_health_probe.
	checker := grpchealth.NewStaticChecker(apiv1.EchoServiceName)
	mux.Handle(grpchealth.NewHandler(checker))

	var protocols http.Protocols

	protocols.SetHTTP1(true)
	// Use h2c so we can serve HTTP/2 without TLS.
	protocols.SetUnencryptedHTTP2(true)

	s := http.Server{ //nolint:exhaustruct // optional Server fields use defaults
		Addr:              "localhost:8080",
		Handler:           mux,
		Protocols:         &protocols,
		ReadHeaderTimeout: readHeaderTimeout,
	}

	if err := s.ListenAndServe(); err != nil {
		logger.ErrorContext(context.Background(), "server failed", "err", err)
		os.Exit(1)
	}
}
