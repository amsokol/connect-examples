# connect-examples

Examples of [Connect](https://connectrpc.com/) RPC services in Go, Python, and Rust.

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
Cargo.toml                     # Rust workspace root
rust/client/                   # Rust Echo client ([connect-rust](https://github.com/connectrpc/connect-rust))
requirements.in                # Python dependency pins (source)
requirements.txt               # locked Python deps (pip-compile)
requirements-dev.in            # Python dev tools (ruff, pip-audit)
requirements-dev.txt           # locked Python dev deps
ruff.toml                      # Ruff linter/formatter config
pyrightconfig.json             # basedpyright / Pyright (venv + import paths)
.vscode/settings.json          # Cursor/VS Code: Python venv, Ruff, basedpyright
buf.yaml                       # Buf lint config
buf.gen.go.yaml                # Go codegen
buf.gen.python.yaml            # Python codegen (use with --include-imports)
.golangci.yaml                 # golangci-lint v2
renovate.json                  # Renovate dependency updates (2-day quarantine)
.github/workflows/ci.yml       # CI: buf, build, lint, vulns, test
```

## Prerequisites

- Go 1.26+
- Python 3.10+
- Rust 1.88+ (for the Rust client; [connect-rust](https://github.com/connectrpc/connect-rust) MSRV)
- [Buf CLI](https://buf.build/docs/installation) (also required at `cargo build` time for Rust codegen)

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

Rust codegen runs from `rust/client/build.rs` via [`connectrpc-build`](https://crates.io/crates/connectrpc-build) (`buf build` → buffa/connect stubs into `$OUT_DIR`). No checked-in generated Rust sources.

## Run the Echo example

### Server (Go)

Terminal 1 — server (HTTP/1.1 + h2c on `:8080`):

```bash
go run ./go/echo/cmd/server
```

The server logs each unary RPC with `log/slog` (procedure, Connect/gRPC protocol, HTTP version, peer address, method, Content-Type, User-Agent, duration, and error code if any).

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

### Rust client

From the repo root (Buf CLI must be on `PATH`):

```bash
cargo run -p echo-client
```

Expected output:

```text
Hello, Jane!
```

The client uses [connect-rust](https://github.com/connectrpc/connect-rust) with `HttpClient::plaintext_http2_only()` (h2c), matching the Go client. For HTTP/1.1, switch to `HttpClient::plaintext()` in `rust/client/src/main.rs`.

`rust/client/src/retry.rs` retries `Unavailable` / `ResourceExhausted` (including dial/transport failures mapped to `Unavailable`) with the same 5-attempt exponential backoff.

## Lint, vulns, and test

```bash
buf lint
go tool golangci-lint run ./...
go tool govulncheck ./...
go test ./...
ruff check python
ruff format --check python/echo
pip-audit -r requirements.txt -r requirements-dev.txt
cargo clippy -- -D warnings
```

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs on pushes to `main` and on pull requests:

1. `buf lint`
2. `buf generate` for Go and Python templates and fail if generated code is out of date
3. `go build ./...`
4. `cargo clippy` (Rust Echo client)
5. `go tool golangci-lint run ./...`
6. `ruff check` / `ruff format --check` (Python)
7. `go tool govulncheck ./...` and `pip-audit` on `requirements.txt` / `requirements-dev.txt`
8. `go test ./...`

## Notes

- Request validation: `message` is required and non-empty (`buf.validate` in the proto; `connectrpc.com/validate` interceptor on the server).
- Go Protobuf uses the **opaque** API (`features.(pb.go).api_level = API_OPAQUE`).
- Connect Go codegen uses `package_suffix=` so handlers/clients live next to the `.pb.go` types.
- Python uses [connectrpc](https://pypi.org/project/connectrpc/) with [protobuf-py](https://protobufpy.com) (Buf `bufbuild/py` + `connectrpc/py` plugins).
- Python pins in `requirements*.in` use exact `==` versions so Renovate bumps are explicit.
- Rust uses a Cargo workspace (`Cargo.toml` at the repo root); crate pins live in `[workspace.dependencies]`. Codegen is via `rust/client/build.rs` + Buf (not checked-in stubs).

## Dependency updates (Renovate)

[Renovate](https://docs.renovatebot.com/) is configured in `renovate.json`:

- **2-day** `minimumReleaseAge` quarantine for new releases
- Security updates skip the quarantine
- Covers Go modules, Cargo crates, pip-compile lockfiles, and GitHub Actions
- Python: tracks pins in `requirements*.in`; regenerates `requirements*.txt` via pip-compile (does not bump lockfile-only transitive deps)
- Rust: `buffa` is capped at `<0.9.0` until `connectrpc` supports it; `connectrpc*` + `buffa*` update as one **connect-rust** group

Install the [Renovate GitHub App](https://github.com/apps/renovate) on this repository to enable it.
