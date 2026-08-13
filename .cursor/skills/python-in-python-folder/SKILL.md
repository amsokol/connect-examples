---
name: python-in-python-folder
description: >-
  Put Python code in the python folder. Use when creating, moving, generating, or
  reviewing Python (.py) packages, modules, tests, or BUILD files.
---

# Put Python code in the python folder

All Python source lives under `python/`.

## Required

- New packages, modules, tests, and `.py` files go under `python/` (e.g. `python/echo/…`, `python/gen/…`).
- Keep `BUILD.bazel` next to the package under `python/`.
- Hatch/ruff already treat `python/` as the package tree; do not add a second import root.

## Allowed at repo root

Project manifests only: `pyproject.toml`, `uv.lock`. Do not put `.py` files there.

## Forbidden

- Python application or library source outside `python/` (repo root, `go/`, `rust/`, or a new top-level tree).
