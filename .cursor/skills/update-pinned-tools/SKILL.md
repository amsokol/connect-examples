---
name: update-pinned-tools
description: >-
  Bump tool and plugin versions in Bazel modules and language lockfiles.
  Use when updating buf, golangci-lint, govulncheck, ruff, pip-audit,
  cargo-audit, markdownlint-cli2, protoc-gen-*, protovalidate, LLVM,
  Node, or when the user asks to refresh pinned tools. For
  protoc-gen-protovalidate-buffa, also refresh rust/buf/plugins patches.
---

# Update pinned tools

Pins live in language lockfiles and `*.MODULE.bazel`. After a bump, refresh the matching lock and `MODULE.bazel.lock` if Bazel modules changed.

## Where versions live

| What | Pin | Lock / verify |
| --- | --- | --- |
| Go toolchain | `go` line in root `go.mod` | `go.sum`; `go_sdk.from_file` in `go.MODULE.bazel` |
| Go tools (`buildifier`, `golangci-lint`, `govulncheck`, `protoc-gen-go`, `protoc-gen-connect-go`) | root `go.mod` `tool` / `require` | `go.sum`; then `bazel test //go:lint //go:vuln` |
| Rust toolchain | `Cargo.toml` `[workspace.package].rust-version` | `rust.MODULE.bazel` `RUST_VERSION` (keep in sync) |
| Rust apps, Buf plugins, `cargo-audit` | root `Cargo.toml` `[workspace.dependencies]` | `Cargo.lock`; crate_universe in `rust.MODULE.bazel` |
| `protoc-gen-buffa` crate source | `http_archive` in `rust.MODULE.bazel` | `integrity` + `strip_prefix` |
| `protovalidate-buffa-protos` patch | `rust/buf/plugins/protovalidate-buffa-protos-buffa-types.patch` | crate_universe `patches` in `rust.MODULE.bazel` |
| Python interpreter | `.python-version` | `python.MODULE.bazel` uv hub |
| Python apps and tools (`ruff`, `pip-audit`, Buf Python plugins) | root `pyproject.toml` | `uv.lock` |
| Markdownlint | `pnpm-workspace.yaml` catalog | `pnpm-lock.yaml`; `js.MODULE.bazel` Node/pnpm versions |
| Buf CLI | `buf.MODULE.bazel` `buf.toolchains(version)` | `MODULE.bazel.lock` |
| Protovalidate `.proto` archive | `buf.MODULE.bazel` `http_archive` (`integrity`, tag in `urls`) | keep tag aligned with generate/lint |
| LLVM + Debian sysroots | `rust.MODULE.bazel` | hashes in `llvm.toolchain` / `sysroot` |

## Workflow

1. Change the pin in the file from the table (latest stable; see `latest-external-deps`).
2. Refresh the matching lock (`go.sum`, `Cargo.lock`, `uv.lock`, `pnpm-lock.yaml`, `MODULE.bazel.lock`).
3. After **codegen plugin** bumps: `bazel run //api/v1:generate` and commit stub diffs.
4. Prove it: `bazel test //api/v1:generate_tests` plus the matching lint/vuln test.

### `protoc-gen-protovalidate-buffa` (git + patch)

Built from GitHub, not crates.io — the published plugin rebuilds `protovalidate-buffa-protos` without `buffa-types` / `buffa-descriptor`, which buffa 0.8 codegen requires for WKTs.

When bumping:

1. Update the crate / git pin in root `Cargo.toml` `[workspace.dependencies]`.
2. Refresh `rust/buf/plugins/protovalidate-buffa-protos-buffa-types.patch` so `protovalidate-buffa-protos` still depends on `buffa-types` + `buffa-descriptor` and re-exports `buffa_types::google`.
3. Update `Cargo.lock` and crate_universe, then `bazel run //api/v1:generate`.
