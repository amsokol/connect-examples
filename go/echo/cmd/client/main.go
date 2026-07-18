// Package main is a Connect client for the Echo service over HTTP/2 (h2c).
package main

import (
	"context"
	"crypto/tls"
	"log"
	"net"
	"net/http"

	"golang.org/x/net/http2"

	apiv1 "github.com/amsokol/connect-examples/go/api/v1"
)

func main() {
	httpClient := &http.Client{ //nolint:exhaustruct // optional Client fields use defaults
		Transport: &http2.Transport{ //nolint:exhaustruct // only h2c cleartext settings are required
			AllowHTTP: true,
			DialTLSContext: func(ctx context.Context, network, addr string, _ *tls.Config) (net.Conn, error) {
				//nolint:exhaustruct // Dialer zero value is fine for local h2c
				return (&net.Dialer{}).DialContext(ctx, network, addr)
			},
		},
	}
	client := apiv1.NewEchoServiceClient(httpClient, "http://localhost:8080")

	/* HTTP/1.1
	client := apiv1.NewEchoServiceClient(
		http.DefaultClient,
		"http://localhost:8080",
	)
	*/

	var req apiv1.EchoRequest

	req.SetMessage("Jane")

	res, err := client.Echo(
		context.Background(),
		&req,
	)
	if err != nil {
		log.Println(err)

		return
	}

	log.Println(res.GetMessage())
}
