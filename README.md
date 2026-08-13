# connect-examples

Examples of [Connect](https://connectrpc.com/) RPC in Go, Python, and Rust — hermetic [Nix](https://nixos.org/) flake for lint, codegen, builds, and CI.

**Echo** is the first service: Protobuf edition 2023 + Protovalidate; Go and Rust ship server + client; Python ships a client. All speak Connect over HTTP/1.1 and HTTP/2 cleartext (h2c).

## Prerequisites

[Nix](https://nixos.org/) with flakes enabled (`experimental-features = nix-command flakes`).

## Generate code

```bash
nix run .#generate
```

Generation updates checked-in stubs for all languages:

- Go → `go/api/v1/` (`echo.pb.go` and `echo.connect.go` in the same `apiv1` package)
- Python → `python/gen/` (`api/` + `buf/`)
- Rust → `rust/api/gen/` (`buffa/` + `connect/` package files, wired by the `api` crate)

### Check stubs are up to date

```bash
nix run .#generate-check
```

Fails if checked-in stubs differ from a hermetic regen (same check as CI).

## Lint

Hermetic (Nix sandbox):

```bash
nix run .#lint-proto    # Protobuf (buf)
nix run .#lint-go       # golangci-lint
nix run .#lint-python   # ruff check + format
nix run .#lint-rust     # clippy
nix run .#lint-md       # markdownlint-cli2
nix run .#lint-all      # all of the above
```

## Vuln

```bash
nix run .#vuln-go       # govulncheck (needs network for vuln.go.dev)
nix run .#vuln-python   # pip-audit on uv.lock runtime deps (needs network)
nix run .#vuln-rust     # cargo audit (hermetic; rustsec advisory-db flake input)
nix run .#vuln-all      # all of the above
```

Refresh the Rust advisory DB with `nix flake update advisory-db` when you want newer RustSec data.

## Build

Hermetic host binaries:

```bash
nix build .#rust-echo-server     # Rust
nix build .#rust-echo-client
nix build .#go-echo-server       # Go
nix build .#go-echo-client
nix build .#python-echo-client   # Python (host-only)
```

Artifact trees under `./result/`:

```bash
nix build .#default              # host only → result/{rust,go,python}/echo/…/default/
nix build .#all                  # + Go/Rust static linux variants
nix run .#rebuild                # force rebuild host (.#default)
nix run .#rebuild -- all         # force rebuild all variants
```

Same packages under source-mirrored paths, e.g. `nix build '.#"rust/echo/server/default"'`.

Static linux leaves (Rust: musl; Go: `CGO_ENABLED=0`): `.#rust-echo-server-x86_64-v1`, `-x86_64-v3`, `-arm64` (and the same for `rust-echo-client` / `go-echo-*`). Python has no cross/static variants.

## Test

Hermetic (Nix sandbox):

```bash
nix run .#test
```

Runs:

- Go — `go test ./...`
- Rust — `cargo test --locked --workspace`
- Python — import smoke (`python.echo.client`)

## Run the Echo example

Servers listen on `:8080` (HTTP/1.1 + h2c). Run **one** server:

```bash
# Terminal 1
nix run .#go-echo-server
# or
nix run .#rust-echo-server
```

Then a client (Connect over h2c):

```bash
# Terminal 2
nix run .#go-echo-client
# or
nix run .#rust-echo-client
# or
nix run .#python-echo-client
```

Expected output:

```text
Hello, Jane!
```

Clients retry `Unavailable` / `ResourceExhausted` (and matching transport errors) with the same 5-attempt exponential backoff. Both servers reject empty `message` with `InvalidArgument` and serve `grpc.health.v1.Health` for `api.v1.EchoService`.

### Health probe

With a server running:

```bash
nix run .#grpc-health-probe -- \
  -addr=localhost:8080 \
  -service=api.v1.EchoService
```

## Updating pinned tools (`tools.version.toml`)

All overlaid tools and plugins are pinned in [`tools.version.toml`](tools.version.toml). Bump **version and hashes together**. Nix will refuse to build if a hash does not match the downloaded content.

**General workflow (any pin with a hash field):**

1. Edit `tools.version.toml`: set the new `version` (and `url` / `crate` / `key` if that field exists for the entry).
2. Replace every content hash for that entry with a placeholder:

   ```toml
   hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
   vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="   # Go only
   cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="    # Rust crates / ruff
   npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="  # markdownlint-cli2
   ```

   (`lib.fakeHash` is the same all-`A` value.)
3. Build the corresponding package so Nix prints the real hash(es):

   | Pin                                                      | Build command                                |
   | -------------------------------------------------------- | -------------------------------------------- |
   | `buf`                                                    | `nix develop -c buf --version`               |
   | `protoc-gen-go`                                          | `nix build .#protoc-gen-go`                  |
   | `protoc-gen-connect-go`                                  | `nix build .#protoc-gen-connect-go`          |
   | `go` (workspace `vendorHash`)                            | `nix build .#go-echo-server`                 |
   | `grpc-health-probe`                                      | `nix build .#grpc-health-probe`              |
   | `golangci-lint`                                          | `nix build .#golangci-lint`                  |
   | `govulncheck`                                            | `nix build .#govulncheck`                    |
   | `cargo-audit`                                            | `nix build .#cargo-audit`                    |
   | `pip-audit`                                              | `nix build .#pip-audit`                      |
   | `ruff`                                                   | `nix build .#ruff`                           |
   | `markdownlint-cli2`                                      | `nix build .#markdownlint-cli2`              |
   | `protoc-gen-py` (+ `protobuf-py`)                        | `nix build .#protoc-gen-py`                  |
   | `protoc-gen-connectrpc` (+ `protobuf-py`)                | `nix build .#protoc-gen-connectrpc`          |
   | `protoc-gen-buffa`                                       | `nix build .#protoc-gen-buffa`               |
   | `protoc-gen-connect-rust`                                | `nix build .#protoc-gen-connect-rust`        |
   | `protoc-gen-protovalidate-buffa`                         | `nix build .#protoc-gen-protovalidate-buffa` |
   | `protovalidate`                                          | `nix build .#checks.x86_64-linux.lint-proto` |

4. Copy each `got: sha256-…` from the error into `tools.version.toml`.
5. Rebuild until it succeeds. For Go packages you usually fix `hash` first, then `vendorHash` on the next build. For Rust crates / `ruff`: `hash` first, then `cargoHash`. For `markdownlint-cli2`: `hash` then `npmDepsHash`.
6. After codegen plugin bumps, re-run `nix run .#generate` and commit stub diffs if any.

**Field meanings:**

- **Go** (`buf`, `protoc-gen-go`, `protoc-gen-connect-go`, `grpc-health-probe`, `golangci-lint`, `govulncheck`): `hash` = GitHub source archive; `vendorHash` = Go module vendor tree.
- **Rust crates** (`cargo-audit`, `protoc-gen-*`, `ruff`): `hash` = crates.io / GitHub source; `cargoHash` = vendored Cargo deps.
- **Python** (`pip-audit`, `protoc-gen-*`, `protobuf-py*`): set `url` to the PyPI wheel URL for that version, `hash` = that wheel. Look up the exact wheel on [PyPI](https://pypi.org/) (Files tab).
- **Linters (npm)** (`markdownlint-cli2`): GitHub `hash` plus `npmDepsHash`.
- **Rust plugins** (`protoc-gen-buffa`, `protoc-gen-connect-rust`, `protoc-gen-protovalidate-buffa`): `hash` = source archive; `cargoHash` = vendored Cargo deps. `protoc-gen-connect-rust` uses crate name `connectrpc-codegen` (`crate` field). `protoc-gen-protovalidate-buffa` is built from GitHub (`owner` / `repo` / `rev`) plus `nix/patches/` (crates.io rebuild needs `buffa-types` / `buffa-descriptor`).

**Rust toolchain** for apps is **not** in `tools.version.toml` — it comes from `[workspace.package].rust-version` in root `Cargo.toml` via rust-overlay. Git crate deps (e.g. `mimalloc`) are likewise only in `Cargo.lock`; crane fetches them via `builtins.fetchGit` from that lockfile.

**Go toolchain** for apps is also **not** version-pinned in `tools.version.toml` — it comes from the `go X.Y` line in root `go.mod`. The module vendor tree hash is `[go].vendorHash` in `tools.version.toml` (refresh when `go.sum` changes: set to `lib.fakeHash`, run `nix build .#go-echo-server`, paste the `got:` hash).

**Python toolchain** for apps is likewise **not** in `tools.version.toml` — interpreter comes from `.python-version` (`3.14` → `pkgs.python314`); runtime deps come from `uv.lock` via uv2nix. Refresh by editing `pyproject.toml` / running `uv lock`, then `nix build .#python-echo-client`.

**Protovalidate protos** for hermetic buf are pinned in `tools.version.toml` (`[protovalidate]`) via `fetchFromGitHub` (`bufbuild/protovalidate` tag `v${version}`). Keep the tag aligned with `buf.yaml` deps (`buf.build/bufbuild/protovalidate:v…`). Refresh `hash` like other GitHub pins when bumping.

## CI

GitHub Actions (`.github/workflows/ci.yml`) — one **Nix** job on `main` pushes and PRs, with [cache-nix-action](https://github.com/nix-community/cache-nix-action) (official GitHub Actions cache for the Nix store):

1. `nix run .#lint-all`
2. `nix run .#generate-check`
3. `nix run .#vuln-all`
4. `nix build .#default`
5. `nix build .#all --dry-run` (evaluate static/cross artifact graph)
6. `nix run .#test`

## Notes

- Request validation: `message` is required and non-empty (`buf.validate` in the proto; `connectrpc.com/validate` on the Go server; [`protovalidate-buffa`](https://github.com/mathematic-inc/protovalidate-buffa) codegen + `#[connect_impl]` on the Rust server).
- Go Protobuf uses the **opaque** API (`features.(pb.go).api_level = API_OPAQUE`).
- Connect Go codegen uses `package_suffix=` so handlers/clients live next to the `.pb.go` types.
