# connect-examples

Examples of [Connect](https://connectrpc.com/) RPC services in Go.

The first example is a small **Echo** service: Protobuf edition 2024, Protovalidate, opaque Go APIs, and a client/server that speak the Connect protocol over HTTP/1.1 and HTTP/2 cleartext (h2c).

## Layout

```text
api/v1/echo.proto          # service definition
go/api/v1/                 # generated Protobuf + Connect code
go/echo/cmd/server/        # Echo server (+ unit test)
go/echo/cmd/client/        # Echo client (h2c by default)
buf.yaml / buf.gen.yaml    # Buf lint + codegen
.golangci.yaml             # golangci-lint v2
.github/workflows/ci.yml   # CI: buf, build, lint, vulns, test
```

## Prerequisites

- Go 1.26+
- [Buf CLI](https://buf.build/docs/installation)

Go tools used by this repo are declared in `go.mod` and run via `go tool`:

- `protoc-gen-go` / `protoc-gen-connect-go` — code generation
- `golangci-lint` — Go linting
- `govulncheck` — dependency vulnerability scanning

## Generate code

```bash
buf dep update
buf lint
buf generate
```

Generated files land in `go/api/v1/` (`echo.pb.go` and `echo.connect.go` in the same `apiv1` package).

## Run the Echo example

Terminal 1 — server (HTTP/1.1 + h2c on `:8080`):

```bash
go run ./go/echo/cmd/server
```

Terminal 2 — client (Connect protocol over h2c):

```bash
go run ./go/echo/cmd/client
```

Expected output:

```text
Hello, Jane!
```

The client uses the **Connect** protocol (not gRPC). Switch to HTTP/1.1 by using the commented `http.DefaultClient` block in `go/echo/cmd/client/main.go`.

## Lint, vulns, and test

```bash
buf lint
go tool golangci-lint run ./...
go tool govulncheck ./...
go test ./...
```

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs on pushes to `main` and on pull requests:

1. `buf lint`
2. `buf generate` + fail if `go/api` is out of date
3. `go build ./...`
4. `go tool golangci-lint run ./...`
5. `go tool govulncheck ./...`
6. `go test ./...`

## Notes

- Request validation: `message` is required and non-empty (`buf.validate` in the proto; `connectrpc.com/validate` interceptor on the server).
- Go Protobuf uses the **opaque** API (`features.(pb.go).api_level = API_OPAQUE`).
- Connect codegen uses `package_suffix=` so handlers/clients live next to the `.pb.go` types.
