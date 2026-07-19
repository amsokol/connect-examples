# connect-examples

Examples of [Connect](https://connectrpc.com/) RPC services in Go, Python, and Rust.

The first example is a small **Echo** service: Protobuf edition 2024, Protovalidate, opaque Go APIs, and clients/servers that speak the Connect protocol over HTTP/1.1 and HTTP/2 cleartext (h2c).

## Layout

```text
api/v1/echo.proto              # service definition
go/api/v1/                     # generated Go Protobuf + Connect code
go/echo/cmd/server/            # Echo server (+ unit test)
go/echo/cmd/client/            # Go Echo client (h2c + retry interceptor)
python/gen/                    # generated Python Protobuf + Connect + Protovalidate
python/echo/client/            # Python Echo client (retry interceptor)
Cargo.toml                     # Rust workspace root
rust/client/                   # Rust Echo client ([connect-rust](https://github.com/connectrpc/connect-rust))
rust/server/                   # Rust Echo server (HTTP/1.1 + h2c + request logging)
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

Go tools used by this repo are declared in `go.mod` and run via `go tool` (install binaries with `go install tool`):

- `buf` — Protobuf lint / generate / `buf build` (also needed on `PATH` for Rust `build.rs`)
- `protoc-gen-go` / `protoc-gen-connect-go` — code generation
- `golangci-lint` — Go linting
- `govulncheck` — dependency vulnerability scanning
- `grpc-health-probe` — local gRPC health checks against `grpc.health.v1`

## Generate code

```bash
bazel test //api/v1:lint
bazel run //api/v1:generate
```

`//api/v1:lint` runs hermetic `buf lint` (pins from `buf.lock`). Generation updates checked-in stubs for both languages:

- Go → `go/api/v1/` (`echo.pb.go` and `echo.connect.go` in the same `apiv1` package)
- Python → `python/gen/` (`api/` + `buf/`)

Details: [Bazel](#bazel).

### Rust

Rust codegen runs from each crate's `build.rs` (`rust/client`, `rust/server`) via [`connectrpc-build`](https://crates.io/crates/connectrpc-build) (`buf build` → buffa/connect stubs into `$OUT_DIR`). No checked-in generated Rust sources.

## Bazel

Requires [Bazel](https://bazel.build/) / [Bazelisk](https://github.com/bazelbuild/bazelisk) (version pinned in `.bazelversion`). Go SDK and module deps come from `go.mod` via `rules_go` (`go.MODULE.bazel`). Python toolchain and pip deps come from `requirements.txt` via `rules_python` (`python.MODULE.bazel`). Buf CLI is the prebuilt binary from `rules_buf`; Go plugins are `go_binary` tools (a PATH `go` shim satisfies `local: [go, tool, …]` in `buf.gen.go.yaml`). BSR pins stay in `buf.lock` only.

### 1. Lint

```bash
bazel test //api/v1:lint
```

Hermetic `buf lint` with `buf.yaml` + `buf.lock`.

### 2. Generation

Hermetic `buf generate` into `bazel-out`, then copy into the source tree:

```bash
bazel run //api/v1:generate
```

Builds both `buf_generate` deps (`:go` / `:python`), then one `write_source_files` updates the checked-in stubs. Go plugins come from `//bazel:protoc-gen-*` (built once). No `buf dep update`; pins stay in `buf.lock` / `go.sum`.

### 3. Build

```bash
bazel build //api/v1:go //api/v1:python
bazel build //go/echo/cmd/server:server //go/echo/cmd/client:client
bazel build //python/echo/client:client
```

Hermetic generated trees under `.bazel/bin/api/v1/{go,python}/`. Go and Python apps use checked-in stubs (`//go/api:apiv1`, `//python:gen_py`) plus module/pip deps from `go.MODULE.bazel` / `python.MODULE.bazel`.

### 4. Test

```bash
bazel test //api/v1:lint //api/v1:generate_tests //go/...
```

`generate_tests` fails if checked-in stubs are out of date. Re-run generation (step 2) and commit if needed.

## Run the Echo example

### Server (Go)

Terminal 1 — Go server (HTTP/1.1 + h2c on `:8080`):

```bash
go run ./go/echo/cmd/server
```

The server logs each unary RPC with `log/slog` (procedure, Connect/gRPC protocol, HTTP version, peer address, method, Content-Type, User-Agent, duration, and error code if any). It also serves [`grpc.health.v1.Health`](https://github.com/connectrpc/grpchealth-go) (`Serving` for `api.v1.EchoService`) for Kubernetes gRPC probes and `grpc_health_probe`:

```bash
go tool grpc-health-probe \
  -addr=localhost:8080 \
  -service=api.v1.EchoService
```

### Server (Rust)

Alternative to the Go server (same port — run only one):

```bash
cargo run -p echo-server
```

Serves Connect over HTTP/1.1 and h2c on `127.0.0.1:8080`. Logs unary RPCs with `tracing` (procedure, protocol, peer, Content-Type, User-Agent, duration). Serves [`grpc.health.v1.Health`](https://crates.io/crates/connectrpc-health) (`Serving` for `api.v1.EchoService`) for Kubernetes gRPC probes — same check as the Go server:

```bash
go tool grpc-health-probe \
  -addr=localhost:8080 \
  -service=api.v1.EchoService
```

Rejects empty `message` with `InvalidArgument` (Go uses Protovalidate for the same rule).

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

Bazel (toolchain + pip from `python.MODULE.bazel` / `requirements.txt`):

```bash
bazel run //python/echo/client
```

Or with a local venv:

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

The client uses Connect over HTTP/2 cleartext (h2c) via `pyqwest.SyncHTTPTransport(http_version=HTTPVersion.HTTP2)`, matching the Go and Rust clients. For HTTP/1.1, omit `http_version` or set `HTTPVersion.HTTP1` in `python/echo/client/__main__.py`.

To refresh locked deps after editing `requirements.in` or `requirements-dev.in` (with the venv activated):

```bash
pip install -U pip-tools
pip-compile requirements.in -o requirements.txt
pip-compile requirements-dev.in -o requirements-dev.txt
pip install -r requirements.txt -r requirements-dev.txt
```

### Rust client

From the repo root (Buf CLI must be on `PATH`; run `go install tool` once):

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
bazel test //api/v1:lint
go tool golangci-lint run ./...
go tool govulncheck ./...
go test ./...
ruff check python
ruff format --check python/echo
pip-audit -r requirements.txt -r requirements-dev.txt
cargo clippy -- -D warnings
cargo test -p echo-server
```

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs two jobs in parallel on pushes to `main` and on pull requests:

**Bazel** — runs in `eclipse-temurin:25-jdk` with Bazelisk installed as `bazel` (version from `.bazelversion`):

1. Generate — `bazel test //api/v1:lint //api/v1:generate_tests` and `bazel build //api/v1:go //api/v1:python`
2. Build — Go/Python Echo binaries
3. Test — `bazel test //go/...`

**Native** — Go / Python / Rust toolchains without Bazel:

1. `go tool buf lint`
2. `go tool buf generate` for Go and Python templates and fail if generated code is out of date
3. `go build ./...`
4. `cargo clippy` / `cargo test -p echo-server` (Rust)
5. `go tool golangci-lint run ./...`
6. `ruff check` / `ruff format --check` (Python)
7. `go tool govulncheck ./...` and `pip-audit` on `requirements.txt` / `requirements-dev.txt`
8. `go test ./...`

## Notes

- Request validation: `message` is required and non-empty (`buf.validate` in the proto; `connectrpc.com/validate` on the Go server; a matching check in the Rust server handler).
- Go Protobuf uses the **opaque** API (`features.(pb.go).api_level = API_OPAQUE`).
- Connect Go codegen uses `package_suffix=` so handlers/clients live next to the `.pb.go` types.
- Python uses [connectrpc](https://pypi.org/project/connectrpc/) with [protobuf-py](https://protobufpy.com) (Buf `bufbuild/py` + `connectrpc/py` plugins).
- Python pins in `requirements*.in` use exact `==` versions so Renovate bumps are explicit.
- Rust uses a Cargo workspace (`Cargo.toml` at the repo root); crate pins live in `[workspace.dependencies]`. Codegen is via each crate's `build.rs` + Buf (not checked-in stubs).

## Dependency updates (Renovate)

[Renovate](https://docs.renovatebot.com/) is configured in `renovate.json`:

- **2-day** `minimumReleaseAge` quarantine for new releases
- Security updates skip the quarantine
- Covers Go modules, Cargo crates, pip-compile lockfiles, GitHub Actions, the `buf.toolchains` pin in `MODULE.bazel`, and `.bazelversion`
- Python: tracks pins in `requirements*.in`; regenerates `requirements*.txt` via pip-compile (does not bump lockfile-only transitive deps)
- Rust: `buffa` is capped at `<0.9.0` until `connectrpc` supports it; `connectrpc*` + `buffa*` update as one **connect-rust** group

Install the [Renovate GitHub App](https://github.com/apps/renovate) on this repository to enable it.
