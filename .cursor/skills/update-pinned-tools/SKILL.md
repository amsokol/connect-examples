---
name: update-pinned-tools
description: >-
  Bump Nix-pinned tool and plugin versions in tools.version.toml (hashes,
  vendorHash, cargoHash, npmDepsHash). Use when updating buf, golangci-lint,
  govulncheck, ruff, pip-audit, cargo-audit, markdownlint-cli2, grpc-health-probe,
  protoc-gen-*, protovalidate, go vendorHash, or when the user asks to refresh
  pinned tools / versions.toml / tools.version.toml hashes. For
  protoc-gen-protovalidate-buffa, also refresh nix/patches/ when bumping.
---

# Update pinned tools

Pins live in `tools.version.toml` at the repo root. Overlay wiring is in `nix/toolchains.nix` and `nix/buf-plugins.nix`.

## Workflow

1. Edit the entry in `tools.version.toml`: new `version` (and `url` / `crate` / `owner` / `repo` / `rev` if present).
2. Set every content hash for that entry to the fake placeholder:

   ```toml
   hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
   vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="   # Go
   cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="    # Rust / ruff / cargo-audit
   npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="  # markdownlint-cli2
   ```

3. Build so Nix prints `got: sha256-…` (use `--no-link`):

   | Pin | Build command |
   | --- | --- |
   | `buf` | `nix develop -c buf --version` |
   | `protoc-gen-go` | `nix build .#protoc-gen-go --no-link` |
   | `protoc-gen-connect-go` | `nix build .#protoc-gen-connect-go --no-link` |
   | `go` (`vendorHash`) | `nix build .#go-echo-server --no-link` |
   | `grpc-health-probe` | `nix build .#grpc-health-probe --no-link` |
   | `golangci-lint` | `nix build .#golangci-lint --no-link` |
   | `govulncheck` | `nix build .#govulncheck --no-link` |
   | `cargo-audit` | `nix build .#cargo-audit --no-link` |
   | `pip-audit` | `nix build .#pip-audit --no-link` |
   | `ruff` | `nix build .#ruff --no-link` |
   | `markdownlint-cli2` | `nix build .#markdownlint-cli2 --no-link` |
   | `protoc-gen-py` (+ `protobuf-py`) | `nix build .#protoc-gen-py --no-link` |
   | `protoc-gen-connectrpc` (+ `protobuf-py`) | `nix build .#protoc-gen-connectrpc --no-link` |
   | `protoc-gen-buffa` | `nix build .#protoc-gen-buffa --no-link` |
   | `protoc-gen-connect-rust` | `nix build .#protoc-gen-connect-rust --no-link` |
   | `protoc-gen-protovalidate-buffa` | `nix build .#protoc-gen-protovalidate-buffa --no-link` |
   | `protovalidate` | `nix build .#checks.x86_64-linux.lint-proto --no-link` |

4. Paste each `got:` hash into `tools.version.toml`. Rebuild until success.
5. Hash order: Go → `hash` then `vendorHash`; Rust/`ruff`/`cargo-audit` → `hash` then `cargoHash`; npm → `hash` then `npmDepsHash`.
6. After **codegen plugin** bumps: `nix run .#generate` and commit stub diffs.

### `protoc-gen-protovalidate-buffa` (git + patches)

Built from GitHub (`owner` / `repo` / `rev`), not crates.io — the published plugin rebuilds `protovalidate-buffa-protos` without `buffa-types` / `buffa-descriptor`, which buffa 0.8 codegen requires for WKTs.

When bumping:

1. Update `version` / `rev` / `hash` in `tools.version.toml`.
2. Refresh `nix/patches/protovalidate-buffa-protos-buffa-types.patch` and `nix/patches/protovalidate-buffa-v0.6.0-Cargo.lock.patch` so `protovalidate-buffa-protos` still depends on `buffa-types` + `buffa-descriptor` and re-exports `buffa_types::google`.
3. Reset `cargoHash` to the placeholder, then `nix build .#protoc-gen-protovalidate-buffa --no-link`.

## Keep in sync

- **`ruff` / `pip-audit`**: same version in `tools.version.toml` and `pyproject.toml` `[dependency-groups].dev` (`name==version`). Flake evaluation asserts this. After pyproject change: `uv lock`.
- **`protovalidate`**: keep `tools.version.toml` tag aligned with `buf.yaml` deps label.
- **Rust advisory DB** (not in `tools.version.toml`): `nix flake update advisory-db`.

## Not in `tools.version.toml`

| What | Where |
| --- | --- |
| Rust toolchain | `Cargo.toml` `[workspace.package].rust-version` |
| Go toolchain | `go.mod` `go X.Y` line (patch must be ≤ nixpkgs `go_*`) |
| Go module vendor tree | `[go].vendorHash` in `tools.version.toml` (refresh when `go.sum` changes) |
| Python interpreter | `.python-version` |
| Python app deps | `uv.lock` / `pyproject.toml` |

## Field meanings

- **Go tools**: `hash` = GitHub archive; `vendorHash` = `go mod vendor` tree.
- **Rust crates** (`fetchCrate` / GitHub): `hash` = source; `cargoHash` = vendored Cargo deps.
- **Python wheels**: set `url` to the PyPI wheel; `hash` = that wheel.
- **npm** (`markdownlint-cli2`): GitHub `hash` + `npmDepsHash`.
- **`protoc-gen-connect-rust`**: crate name is `connectrpc-codegen` (`crate` field).
- **`protoc-gen-protovalidate-buffa`**: GitHub pin + `nix/patches/` (see section above).
