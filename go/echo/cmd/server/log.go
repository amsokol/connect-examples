package main

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"connectrpc.com/connect"
)

type httpProtoKey struct{}

// withHTTPProto stores r.Proto on the request context for the logging interceptor.
func withHTTPProto(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := context.WithValue(r.Context(), httpProtoKey{}, r.Proto)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func httpProtoFromContext(ctx context.Context) string {
	if proto, ok := ctx.Value(httpProtoKey{}).(string); ok {
		return proto
	}

	return ""
}

// newLogInterceptor logs unary RPC metadata to the server console.
func newLogInterceptor(logger *slog.Logger) connect.Interceptor { //nolint:ireturn // Connect requires Interceptor
	return connect.UnaryInterceptorFunc(func(next connect.UnaryFunc) connect.UnaryFunc {
		return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
			start := time.Now()
			res, err := next(ctx, req)

			peer := req.Peer()
			headers := req.Header()
			attrs := []any{
				"procedure", req.Spec().Procedure,
				"protocol", peer.Protocol,
				"http", httpProtoFromContext(ctx),
				"peer", peer.Addr,
				"method", req.HTTPMethod(),
				"content_type", headers.Get("Content-Type"),
				"user_agent", headers.Get("User-Agent"),
				"duration", time.Since(start).Round(time.Microsecond),
			}

			if err != nil {
				logger.ErrorContext(ctx, "rpc", append(attrs,
					"code", connect.CodeOf(err),
					"err", err,
				)...)
			} else {
				logger.InfoContext(ctx, "rpc", attrs...)
			}

			return res, err
		}
	})
}
