# connect-examples

Examples of [Connect](https://connectrpc.com/) RPC services in Go and Python.

The first example is a small **Echo** service: Protobuf edition 2024, Protovalidate, opaque Go APIs, and clients/servers that speak the Connect protocol over HTTP/1.1 and HTTP/2 cleartext (h2c).

## Layout

```text
api/v1/echo.proto              # service definition
go/api/v1/                     # generated Go Protobuf + Connect code
go/echo/cmd/server/            # Echo server (+ unit test)
go/echo/cmd/client/            # Go Echo client (h2c + retry interceptor)
python/api/v1/                 # generated Python Protobuf + Connect code
python/buf/validate/           # generated Protovalidate stubs (via --include-imports)
python/echo/client/            # Python Echo client (retry interceptor)
requirements.in                # Python dependency pins (source)
requirements.txt               # locked Python deps (pip-compile)
requirements-dev.in            # Python dev tools (ruff, pip-audit)
requirements-dev.txt           # locked Python dev deps
ruff.toml                      # Ruff linter/formatter config
buf.yaml                       # Buf lint config
buf.gen.go.yaml                # Go codegen
buf.gen.python.yaml            # Python codegen (use with --include-imports)
.golangci.yaml                 # golangci-lint v2
.github/workflows/ci.yml       # CI: buf, build, lint, vulns, test
```

## Prerequisites

- Go 1.26+
- Python 3.10+
- [Buf CLI](https://buf.build/docs/installation)

Go tools used by this repo are declared in `go.mod` and run via `go tool`:

- `protoc-gen-go` / `protoc-gen-connect-go` — code generation
- `golangci-lint` — Go linting
- `govulncheck` — dependency vulnerability scanning

## Generate code

```bash
buf dep update
buf lint
buf generate --template buf.gen.go.yaml
buf generate --template buf.gen.python.yaml --include-imports
```

`--include-imports` is required for the Python template so Protovalidate stubs land under `python/buf/validate/`.

Generated Go files land in `go/api/v1/` (`echo.pb.go` and `echo.connect.go` in the same `apiv1` package).

Generated Python files land in `python/api/v1/` (`echo_pb.py` and `echo_connect.py`).

## Run the Echo example

### Server (Go)

Terminal 1 — server (HTTP/1.1 + h2c on `:8080`):

```bash
go run ./go/echo/cmd/server
```

### Go client

Terminal 2 — client (Connect protocol over h2c):

```bash
go run ./go/echo/cmd/client
```

Expected output:

```text
Hello, Jane!
```

The client uses the **Connect** protocol (not gRPC). Switch to HTTP/1.1 by using the commented `http.DefaultClient` block in `go/echo/cmd/client/main.go`.

### Shared HTTP/2 client

The Go client builds one shared `http.Client` with `http2.Transport` (h2c). Reusing it across goroutines multiplexes RPCs on fewer TCP connections and avoids exhausting ephemeral outbound ports under load.

### Automatic retries (Go)

`go/echo/cmd/client/retry.go` installs a Connect unary interceptor that retries transient failures:

- Retries: `Unavailable`, `ResourceExhausted`, dial/`OpError`, network timeouts
- Does not retry: caller cancel/deadline, validation / most application errors
- Up to **5** attempts with exponential backoff starting at **1s** (1s, 2s, 4s, 8s)

**Manual check:** run the client with no server — it should wait several seconds across retries before failing. Or start the client first, then start the server within a few seconds; a later attempt can succeed once the server is up.

### Python client

From the repo root:

```bash
python3 -m venv python/.venv
source python/.venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt
python -m python.echo.client
```

Expected output:

```text
Hello, Jane!
```

`python/echo/client/retry.py` retries `Unavailable` / `ResourceExhausted` and common transport failures with the same 5-attempt exponential backoff as the Go client.

To refresh locked deps after editing `requirements.in` or `requirements-dev.in` (with the venv activated):

```bash
pip install -U pip-tools
pip-compile requirements.in -o requirements.txt
pip-compile requirements-dev.in -o requirements-dev.txt
pip install -r requirements.txt -r requirements-dev.txt
```

## Lint, vulns, and test

```bash
buf lint
go tool golangci-lint run ./...
go tool govulncheck ./...
go test ./...
ruff check python
ruff format --check python/echo
pip-audit -r requirements.txt -r requirements-dev.txt
```

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs on pushes to `main` and on pull requests:

1. `buf lint`
2. `buf generate` for Go and Python templates and fail if generated code is out of date
3. `go build ./...`
4. `go tool golangci-lint run ./...`
5. `ruff check` / `ruff format --check` (Python)
6. `go tool govulncheck ./...` and `pip-audit` on `requirements.txt` / `requirements-dev.txt`
7. `go test ./...`

## Notes

- Request validation: `message` is required and non-empty (`buf.validate` in the proto; `connectrpc.com/validate` interceptor on the server).
- Go Protobuf uses the **opaque** API (`features.(pb.go).api_level = API_OPAQUE`).
- Connect Go codegen uses `package_suffix=` so handlers/clients live next to the `.pb.go` types.
- Python uses [connectrpc](https://pypi.org/project/connectrpc/) with [protobuf-py](https://protobufpy.com) (Buf `bufbuild/py` + `connectrpc/py` plugins).
