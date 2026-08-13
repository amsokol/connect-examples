---
name: go-in-go-folder
description: >-
  Put Go code in the go folder. Use when creating, moving, generating, or
  reviewing Go (.go) packages, binaries, tests, or BUILD files.
---

# Put Go code in the go folder

All Go source lives under `go/`.

## Required

- New packages, binaries, tests, and `.go` files go under `go/` (e.g. `go/echo/…`, `go/api/…`).
- Keep `BUILD.bazel` next to the package under `go/`.

## Allowed at repo root

Module manifests only: `go.mod`, `go.sum`. Do not put `.go` files there.

## Forbidden

- Go application or library source outside `go/` (repo root, `rust/`, `python/`, or a new top-level tree).
