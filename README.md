# connect-examples

Examples of [Connect](https://connectrpc.com/) RPC in Go, Python, and Rust. The only build system is [Bazel](https://bazel.build/) ([`.bazelversion`](.bazelversion)): codegen, lint, vuln scans, tests, host and Linux cross binaries, and CI.

**Echo** is the first service: Protobuf edition 2023 + Protovalidate; Go and Rust ship server + client; Python ships a client. All speak Connect over HTTP/1.1 and HTTP/2 cleartext (h2c).

## Prerequisites

[Bazelisk](https://github.com/bazelbuild/bazelisk) (or Bazel **9.2.0**). Put `bazel` on `PATH`. Toolchains, SDKs, and plugins come from the Bazel module.

## Generate code

```bash
bazel run //api/v1:generate
```

Updates checked-in stubs:

- Go → `go/api/v1/` (`echo.pb.go` and `echo.connect.go` in the same `apiv1` package)
- Python → `python/gen/` (`api/` + `buf/`)
- Rust → `rust/api/gen/` (`buffa/` + `connect/` package files, wired by the `api` crate)

### Check stubs are up to date

```bash
bazel test //api/v1:generate_tests
```

Fails if checked-in stubs differ from a hermetic regen (same check as CI). Does not write to the source tree.

## Lint

`bazel test` never rewrites files. Format is `bazel run` only.

```bash
bazel test //api/v1:lint          # Protobuf (buf)
bazel test //go:lint              # golangci-lint
bazel test //python:lint          # ruff check + format --check
bazel test //rust:lint            # clippy
bazel test //bazel:lint           # Starlark (buildifier)
bazel test //bazel:markdown       # markdownlint-cli2
```

```bash
bazel run //api/v1:format   # buf format
bazel run //python:format   # ruff format
bazel run //bazel:format    # buildifier -mode=fix
```

## Vuln

Needs network (advisory DBs).

```bash
bazel test //go:vuln       # govulncheck on ./go/...
bazel test //python:vuln   # pip-audit on locked runtime deps from uv.lock
bazel test //rust:vuln     # cargo-audit on Cargo.lock
```

## Build

Host binaries (outputs under `.bazel/bin/`):

```bash
bazel build //rust/echo/server:server
bazel build //rust/echo/client:client
bazel build //go/echo/cmd/server:server
bazel build //go/echo/cmd/client:client
bazel build //python/echo/client:client   # host-only
```

Linux cross targets (`amd64_v3`, `arm64`):

```bash
bazel build //go/echo/cmd/server:server_amd64_v3 //go/echo/cmd/server:server_arm64
bazel build //go/echo/cmd/client:client_amd64_v3 //go/echo/cmd/client:client_arm64
bazel build //rust/echo/server:server_amd64_v3 //rust/echo/server:server_arm64
bazel build //rust/echo/client:client_amd64_v3 //rust/echo/client:client_arm64
```

`bazel build //...` builds host and cross together. Python has no cross variants.

## Test

```bash
bazel test //...
```

Includes lint, generate-check, vuln scanners, and Go unit tests (`//go/echo/cmd/server:server_test`, `//go/echo/cmd/client:client_test`).

## Run the Echo example

Servers listen on `:8080` (HTTP/1.1 + h2c). Run **one** server:

```bash
# Terminal 1
bazel run //go/echo/cmd/server:server
# or
bazel run //rust/echo/server:server
```

Then a client (Connect over h2c):

```bash
# Terminal 2
bazel run //go/echo/cmd/client:client
# or
bazel run //rust/echo/client:client
# or
bazel run //python/echo/client:client
```

Expected output:

```text
Hello, Jane!
```

Clients retry `Unavailable` / `ResourceExhausted` (and matching transport errors) with the same 5-attempt exponential backoff. Both servers reject empty `message` with `InvalidArgument` and serve `grpc.health.v1.Health` for `api.v1.EchoService`.

## Versions

Language lockfiles are the source of truth. After a bump, refresh the matching lock and `MODULE.bazel.lock` if Bazel modules changed.

| Area | Versions | Lock |
| --- | --- | --- |
| Go apps | root `go.mod` (`require`) | `go.sum` |
| golangci-lint | `bazel_utils/go/golangci.MODULE.bazel` (GitHub release) | `sha256` on each `http_archive` |
| govulncheck | `bazel_utils/go/go.mod` | `bazel_utils/go/go.sum` |
| buildifier | `bazel_utils/bazel/buildifier.MODULE.bazel` (GitHub release) | `sha256` on each `http_file` |
| markdownlint-cli2 | `bazel_utils/markdown/pnpm-workspace.yaml` | `bazel_utils/markdown/pnpm-lock.yaml` |
| ruff | `bazel_utils/python/ruff.MODULE.bazel` (GitHub release) | `sha256` on each `http_archive` |
| pip-audit | `bazel_utils/python/pyproject.toml` | `bazel_utils/python/uv.lock` |
| cargo-audit | `bazel_utils/rust/cargo_audit.MODULE.bazel` (GitHub release) | `sha256` on each `http_archive` |
| Python apps | root `pyproject.toml` | `uv.lock` |
| Remote Buf plugins | `buf.gen.go.yaml`, `buf.gen.python.yaml`, `buf.gen.rust.yaml` | BSR |
| Rust apps | root `Cargo.toml` `[workspace.dependencies]` | `Cargo.lock` |
| Buf CLI | `buf.toolchains(version)` | `bazel_utils/buf/registry.bzl` `CLI` sha256; then `bazel run @buf//:buf -- --version` |
| Local Buf plugin (`protoc-gen-protovalidate-buffa`) | `buf.plugins` + `bazel_utils/buf/plugins/<name>/<version>/Cargo.toml` | that version's `Cargo.lock` |
| Protovalidate proto module | `buf.yaml` `deps` | BSR |
| Bazel rules, LLVM, Node | `MODULE.bazel` and `*.MODULE.bazel` | `MODULE.bazel.lock` |

Go toolchain follows the `go` line in `go.mod`. Rust toolchain follows `[workspace.package].rust-version` in `Cargo.toml` (`rust.MODULE.bazel`). After codegen plugin bumps, run `bazel run //api/v1:generate` and commit stub diffs.

## CI

GitHub Actions (`.github/workflows/ci.yml`) — one Bazel job on `main` pushes and PRs. The job runs in a **Debian 13** container (same userspace as the LLVM sysroots in `rust.MODULE.bazel`) with [Bazelisk](https://github.com/bazelbuild/bazelisk) `1.29.0`. Bazel version comes from [`.bazelversion`](.bazelversion). Disk and repository caches use `actions/cache`.

1. `bazel test //api/v1:generate_tests` — hermetic proto codegen vs checked-in stubs
2. `bazel test //...` — lint, the same stub tests, vuln scanners, unit tests
3. `bazel build //...` — host Echo binaries and linux cross targets

## Notes

- Request validation: `message` is required and non-empty (`buf.validate` in the proto; `connectrpc.com/validate` on the Go server; [`protovalidate-buffa`](https://github.com/mathematic-inc/protovalidate-buffa) codegen + `#[connect_impl]` on the Rust server).
- Go Protobuf uses the **opaque** API (`features.(pb.go).api_level = API_OPAQUE`).
- Connect Go codegen uses `package_suffix=` so handlers/clients live next to the `.pb.go` types.
