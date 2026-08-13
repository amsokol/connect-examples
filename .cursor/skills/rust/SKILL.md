---
name: rust
description: >-
  Rust conventions for this repo: code under rust/, crate versions in root
  Cargo.toml, no panic paths, no unsafe. Use when writing, editing, reviewing,
  or generating Rust (.rs) crates, tests, Cargo.toml, Clippy config, FFI, or
  BUILD files.
---

# Rust

## Layout

All Rust source lives under `rust/`.

### Required

- New crates, binaries, libraries, tests, and `.rs` files go under `rust/` (e.g. `rust/echo/…`, `rust/api/…`).
- Add workspace members in the root `Cargo.toml` as paths under `rust/`.
- Keep `BUILD.bazel` next to the crate under `rust/`.

### Allowed at repo root

Workspace manifests only: `Cargo.toml`, `Cargo.lock`. Do not put `.rs` files there.

### Forbidden

- Rust application or library source outside `rust/` (repo root, `go/`, `python/`, or a new top-level tree).
- New crates that are not `rust/…` workspace members.

## Dependencies

All Rust dependency versions live in the workspace root `Cargo.toml` under `[workspace.dependencies]`. Member `Cargo.toml` files only refer to them.

### Required

- Declare every crate (version, git, path, default-features, features that are shared) in root `[workspace.dependencies]`.
- In member manifests (`rust/*/Cargo.toml`) use `{ workspace = true }` (extra per-crate `features` are allowed).
- Inherit package metadata with `version.workspace = true`, `edition.workspace = true`, `rust-version.workspace = true`, `publish.workspace = true`.

### Forbidden

- Version pins, git tags, or path sources in a member `Cargo.toml` (`buffa-codegen = "=0.8.1"`, `{ git = "…", tag = "…" }`, and similar).
- A member `[dependencies]` entry that is not defined in root `[workspace.dependencies]`.

## Avoid panic always

Never introduce a panic path in Rust in this repo. Library and binary code must stay on `Result` / `Option`.

### Forbidden

- `panic!`, `todo!`, `unimplemented!`, `unreachable!`
- `unwrap`, `expect`, `unwrap_err`, `unwrap_unchecked`, `expect_err`
- `assert!`, `assert_eq!`, `assert_ne!` outside tests
- Indexing that can panic: `v[i]`, `map[key]` — use `.get()` / `.get_mut()`
- `slice[a..b]`, `first().unwrap()`, `last().unwrap()`
- `Option::unwrap_or_else(|| unreachable!())` and similar “this cannot happen” panics

### Required

- Return `Result<T, E>` or `Option<T>`; propagate with `?`
- Recover with `ok_or` / `ok_or_else`, `map_err`, `unwrap_or`, `unwrap_or_else`, `unwrap_or_default`, `if let`, `match`
- For process exit, return an error from `main` (`fn main() -> Result<...>`) or `eprintln!` + `std::process::exit` after a `match` on `Result` — do not `expect` a static invariant
- In tests only: `assert!` / `assert_eq!` / `assert_ne!` are allowed. Still do not `unwrap` / `expect` there; use `?` in `#[test]` functions that return `Result`

### When touching existing panics

Replace them. Do not add new `expect("… is valid")` comments as a substitute for handling the error.

## Do not use unsafe

Never write or generate `unsafe` Rust in this repo.

### Forbidden

- `unsafe { ... }` blocks
- `unsafe fn`, `unsafe trait`, `unsafe impl`
- `#[deny(unsafe_code)]` exceptions (`allow(unsafe_code)`, crate-level `unsafe`)
- Raw pointers (`*const`, `*mut`) used to alias or dereference
- `std::mem::transmute`, `MaybeUninit` without a safe wrapper you do not write
- `extern "C"` / FFI that needs `unsafe` to call
- Adding a dependency whose documented use requires `unsafe` in this crate

### Required

- Stay in safe Rust. If an API is only reachable via `unsafe`, pick a different API or crate.
- Existing `unsafe` (if any) must not be copied or expanded. Prefer deleting it over wrapping it.

### Allocators and crates

Workspace crates such as `mimalloc` may use `unsafe` internally. Do not add `unsafe` in *this* repo to configure or call them; use only their safe public API.
