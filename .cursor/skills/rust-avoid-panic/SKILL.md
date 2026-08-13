---
name: rust-avoid-panic
description: >-
  Avoid panic always in Rust. Use when writing, editing, reviewing, or generating
  Rust (.rs) code, tests, examples, or Clippy config. Forbids panic!, unwrap,
  expect, and other panic paths; prefer Result and Option.
---

# Avoid panic always

Never introduce a panic path in Rust in this repo. Library and binary code must stay on `Result` / `Option`.

## Forbidden

- `panic!`, `todo!`, `unimplemented!`, `unreachable!`
- `unwrap`, `expect`, `unwrap_err`, `unwrap_unchecked`, `expect_err`
- `assert!`, `assert_eq!`, `assert_ne!` outside tests
- Indexing that can panic: `v[i]`, `map[key]` — use `.get()` / `.get_mut()`
- `slice[a..b]`, `first().unwrap()`, `last().unwrap()`
- `Option::unwrap_or_else(|| unreachable!())` and similar “this cannot happen” panics

## Required

- Return `Result<T, E>` or `Option<T>`; propagate with `?`
- Recover with `ok_or` / `ok_or_else`, `map_err`, `unwrap_or`, `unwrap_or_else`, `unwrap_or_default`, `if let`, `match`
- For process exit, return an error from `main` (`fn main() -> Result<...>`) or `eprintln!` + `std::process::exit` after a `match` on `Result` — do not `expect` a static invariant
- In tests only: `assert!` / `assert_eq!` / `assert_ne!` are allowed. Still do not `unwrap` / `expect` there; use `?` in `#[test]` functions that return `Result`

## When touching existing panics

Replace them. Do not add new `expect("… is valid")` comments as a substitute for handling the error.
