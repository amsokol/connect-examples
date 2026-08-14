---
name: python
description: >-
  Python conventions for this repo: code under python/, package versions in
  root pyproject.toml. Use when creating, moving, generating, or reviewing
  Python (.py) packages, modules, tests, BUILD files, uv, or pyproject.toml.
---

# Python

## Layout

All Python source lives under `python/`.

### Required

- New packages, modules, tests, and `.py` files go under `python/` (e.g. `python/echo/…`, `python/gen/…`).
- Keep `BUILD.bazel` next to the package under `python/`.
- Hatch/ruff already treat `python/` as the package tree; do not add a second import root.

### Allowed at repo root

Project manifests only: `pyproject.toml`, `uv.lock`. Do not put `.py` files there.

### Forbidden

- Python application or library source outside `python/` (repo root, `go/`, `rust/`, or a new top-level tree).

## Dependencies

All Python dependency versions live in the workspace root `pyproject.toml`. Nested manifests must not pin their own versions.

### Required

- Declare runtime packages in root `pyproject.toml` (`[project] dependencies`).
- After a change, update the root `uv.lock`.

### Forbidden

- Version pins in a nested `pyproject.toml` (`protoc-gen-connectrpc==0.11.1` and similar).
- A nested `uv.lock` as the source of truth for package versions.
