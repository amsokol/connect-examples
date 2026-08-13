---
name: rust-no-unsafe
description: >-
  Do not use unsafe in Rust. Use when writing, editing, reviewing, or generating
  Rust (.rs) code, FFI, allocators, or dependencies. Forbids unsafe blocks,
  functions, traits, impls, and APIs that require unsafe to call.
---

# Do not use unsafe

Never write or generate `unsafe` Rust in this repo.

## Forbidden

- `unsafe { ... }` blocks
- `unsafe fn`, `unsafe trait`, `unsafe impl`
- `#[deny(unsafe_code)]` exceptions (`allow(unsafe_code)`, crate-level `unsafe`)
- Raw pointers (`*const`, `*mut`) used to alias or dereference
- `std::mem::transmute`, `MaybeUninit` without a safe wrapper you do not write
- `extern "C"` / FFI that needs `unsafe` to call
- Adding a dependency whose documented use requires `unsafe` in this crate

## Required

- Stay in safe Rust. If an API is only reachable via `unsafe`, pick a different API or crate.
- Existing `unsafe` (if any) must not be copied or expanded. Prefer deleting it over wrapping it.

## Allocators and crates

Workspace crates such as `mimalloc` may use `unsafe` internally. Do not add `unsafe` in *this* repo to configure or call them; use only their safe public API.
