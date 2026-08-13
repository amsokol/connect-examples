---
name: golang
description: >-
  Go conventions for this repo: code under go/, module versions in root go.mod.
  Use when creating, moving, generating, or reviewing Go (.go) packages,
  binaries, tests, BUILD files, go.mod, or go.sum.
---

# Go

## Layout

All Go source lives under `go/`.

### Required

- New packages, binaries, tests, and `.go` files go under `go/` (e.g. `go/echo/…`, `go/api/…`).
- Keep `BUILD.bazel` next to the package under `go/`.

### Allowed at repo root

Module manifests only: `go.mod`, `go.sum`. Do not put `.go` files there.

### Forbidden

- Go application or library source outside `go/` (repo root, `rust/`, `python/`, or a new top-level tree).

## Dependencies

All Go module versions live in the workspace root `go.mod`. Nested manifests must not pin their own versions.

### Required

- Declare every Go module in root `go.mod` (`require` and `tool`).
- After a change, update the root `go.sum`.

### Forbidden

- A nested `go.mod` / `go.sum`.
- `require` / `tool` entries outside the root `go.mod`.
