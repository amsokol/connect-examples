---
name: rust-in-rust-folder
description: >-
  Put Rust code in the rust folder. Use when creating, moving, generating, or
  reviewing Rust (.rs) crates, binaries, libraries, tests, or BUILD files.
---

# Put Rust code in the rust folder

All Rust source lives under `rust/`.

## Required

- New crates, binaries, libraries, tests, and `.rs` files go under `rust/` (e.g. `rust/echo/…`, `rust/api/…`).
- Add workspace members in the root `Cargo.toml` as paths under `rust/`.
- Keep `BUILD.bazel` next to the crate under `rust/`.

## Allowed at repo root

Workspace manifests only: `Cargo.toml`, `Cargo.lock`. Do not put `.rs` files there.

## Forbidden

- Rust application or library source outside `rust/` (repo root, `go/`, `python/`, or a new top-level tree).
- New crates that are not `rust/…` workspace members.
