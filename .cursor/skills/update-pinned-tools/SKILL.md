---
name: update-pinned-tools
description: >-
  Bump tool and plugin versions in Bazel modules and language lockfiles.
  Use when updating buf, ruff, pip-audit, cargo-audit, protoc-gen-*,
  protovalidate, LLVM, Node, or when the user asks to refresh pinned tools.
---

# Update pinned tools

Pins live in language lockfiles and `*.MODULE.bazel`. After a bump, refresh the matching lock and `MODULE.bazel.lock` if Bazel modules changed.

## Where versions live

| What | Pin | Lock / verify |
| --- | --- | --- |
| Go toolchain | `go` line in root `go.mod` | `go.sum`; `go_sdk.from_file` in `go.MODULE.bazel` |
| golangci-lint | `bazel_utils/go/golangci.MODULE.bazel` `_GOLANGCI` + `http_archive` sha256 | then `bazel test //go:lint` |
| govulncheck | `bazel_utils/go/go.mod` `tool` | `bazel_utils/go/go.sum`; then `bazel test //go:vuln` |
| buildifier | `bazel_utils/bazel/buildifier.MODULE.bazel` `_BUILDIFIER` + `http_file` sha256 | then `bazel test //bazel:lint` |
| markdownlint-cli2 | `bazel_utils/markdown/pnpm-workspace.yaml` catalog | `bazel_utils/markdown/pnpm-lock.yaml`; then `bazel test //bazel:markdown` |
| ruff | `bazel_utils/python/ruff.MODULE.bazel` `_RUFF` + `http_archive` sha256 | then `bazel test //python:lint` |
| pip-audit | `bazel_utils/python/pyproject.toml` | `bazel_utils/python/uv.lock`; then `bazel test //python:vuln` |
| cargo-audit | `bazel_utils/rust/cargo_audit.MODULE.bazel` `_CARGO_AUDIT` + `http_archive` sha256 | then `bazel test //rust:vuln` |
| Rust toolchain | `Cargo.toml` `[workspace.package].rust-version` | `rust.MODULE.bazel` `RUST_VERSION` (keep in sync) |
| Rust apps | root `Cargo.toml` `[workspace.dependencies]` | `Cargo.lock`; crate_universe in `rust.MODULE.bazel` |
| Python interpreter | `.python-version` + `python.toolchain(python_version)` in `python.MODULE.bazel` | `python.MODULE.bazel` uv hub |
| Python apps | root `pyproject.toml` | `uv.lock` |
| Remote Buf plugins | `buf.gen.go.yaml`, `buf.gen.python.yaml`, `buf.gen.rust.yaml` | BSR |
| Buf CLI | `buf.toolchains(version)` | `bazel_utils/buf/registry.bzl` `CLI` sha256; then `bazel run @buf//:buf -- --version` |
| Local Buf plugin (`protoc-gen-protovalidate-buffa`) | `buf.plugins(name, version)` + `bazel_utils/buf/registry.bzl` `PLUGINS` + `buf/plugins/<name>/<version>/Cargo.toml` | that version's `Cargo.lock`; crate_universe in `buf/plugins/<name>/<version>/crates.MODULE.bazel` |
| Protovalidate proto module | `buf.yaml` `deps` | BSR |
| LLVM + Debian sysroots | `rust.MODULE.bazel` | hashes in `llvm.toolchain` / `sysroot` |

## Workflow

1. Change the pin in the file from the table (latest stable; see `latest-external-deps`).
2. Refresh the matching lock (`go.sum`, `Cargo.lock`, `uv.lock`, `pnpm-lock.yaml`, `MODULE.bazel.lock`).
3. After **codegen plugin** bumps: `bazel run //api/v1:generate` and commit stub diffs.
4. Prove it: `bazel test //api/v1:generate_tests` plus the matching lint/vuln test.

### `protoc-gen-protovalidate-buffa`

Built from GitHub, not crates.io.

When bumping:

1. Add `buf/plugins/protoc-gen-protovalidate-buffa/<version>/` (Cargo.toml git tag, crate_universe). Keep runtime `protovalidate-buffa` in root `Cargo.toml` in lockstep. Point `buf.plugins(version)` / `registry.bzl` at the new package.
2. Update that version's `Cargo.lock` and `cargo-bazel-lock.json` (`CARGO_BAZEL_REPIN=1 bazel build //plugins/protoc-gen-protovalidate-buffa/<version>:protoc-gen-protovalidate-buffa` from `bazel_utils/buf` with `--override_module=bazel_utils_core=../core`). Update the consumer `Cargo.lock`, then `bazel run //api/v1:generate`.
