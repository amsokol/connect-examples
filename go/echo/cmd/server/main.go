// Package main is a Connect Echo service server over HTTP/1.1 and h2c.
package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"time"

	"connectrpc.com/connect"
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
	echo := &EchoServer{}
	mux := http.NewServeMux()
	path, handler := apiv1.NewEchoServiceHandler(
		echo,
		// Validation via Protovalidate is almost always recommended
		connect.WithInterceptors(validate.NewInterceptor()),
	)
	mux.Handle(path, handler)

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
		log.Fatal(err)
	}
}
