---
name: rust-workspace-deps
description: >-
  All Rust crate versions live in the root Cargo.toml workspace.dependencies;
  member Cargo.toml files only refer to them. Use when adding, bumping, or
  reviewing Rust dependencies, Cargo.toml, or crates.
---

# Rust deps in the root Cargo.toml

All Rust dependency versions live in the workspace root `Cargo.toml` under `[workspace.dependencies]`. Member `Cargo.toml` files only refer to them.

## Required

- Declare every crate (version, git, path, default-features, features that are shared) in root `[workspace.dependencies]`.
- In member manifests (`rust/*/Cargo.toml`) use `{ workspace = true }` (extra per-crate `features` are allowed).
- Inherit package metadata with `version.workspace = true`, `edition.workspace = true`, `rust-version.workspace = true`, `publish.workspace = true`.

## Forbidden

- Version pins, git tags, or path sources in a member `Cargo.toml` (`buffa-codegen = "=0.8.1"`, `{ git = "…", tag = "…" }`, and similar).
- A member `[dependencies]` entry that is not defined in root `[workspace.dependencies]`.
