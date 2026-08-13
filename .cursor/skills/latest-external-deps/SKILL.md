---
name: latest-external-deps
description: >-
  Use the latest version of external dependencies; downgrade only when it is
  mandatory. Use when adding, bumping, pinning, or reviewing crates, Go modules,
  Python packages, Bazel modules, Nix pins, or any other third-party dependency.
---

# Use latest version of external deps

Always take the **latest** released version of an external dependency. **Downgrade only when it is mandatory.**

## Required

- When adding or bumping a dep, look up the current latest stable release and use that.
- Prefer latest over an older version that “already works” or matches an example/tutorial.
- After a version change, update the matching lockfile (`Cargo.lock`, `go.sum`, `uv.lock`, `MODULE.bazel.lock`) and any Nix pin hashes (`tools.version.toml`).
- Keep the same latest version everywhere that dep is declared (workspace Cargo.toml, `go.mod`, `pyproject.toml`, Bazel/Nix pins).

## Downgrade only when mandatory

A downgrade (or staying on an older pin) is allowed only if the latest version:

- fails to compile, test, or generate in this repo, or
- is documented as incompatible with a required peer (toolchain, plugin, or another dep that cannot move yet)

Record why in the change (commit message or comment next to the pin). Do not pin old versions “to be safe.”

## Out of scope

Pre-releases: use them only if this repo already tracks that channel for that dep. Otherwise use the latest stable.
