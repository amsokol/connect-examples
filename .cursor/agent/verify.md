# Verify after fixes

After applying dependency or code fixes, run commands for surfaces **in scope**.
Which surfaces: catalog `library/maintain/verify.md` (change-scoped + Bazel ↔
language couplings). Ship only when required surfaces pass. On failure: fix
forward or roll back.

## Couplings (this product)

| Language / PM change | Bazel wiring | Also run |
| -------------------- | ------------ | -------- |
| `Cargo.toml` / `Cargo.lock` | `rust.MODULE.bazel` → `crate.from_cargo` | **Bazel** |
| `go.mod` / `go.sum` | `go.MODULE.bazel` → `go_sdk` / `go_deps` | **Bazel** |
| `requirements.txt` (runtime lock) | `python.MODULE.bazel` → `pip.parse` | **Bazel** |
| `MODULE.bazel` / `*.MODULE.bazel` / `.bazelversion` / rules pins | direct | **Bazel** |
| `buf.yaml` / `buf.lock` / `buf.gen.*.yaml` / stubs | BSR + checked-in codegen | **BSR** (+ consumers as needed) |

## Commands by surface

### Go

```bash
go mod download
go install tool
go build ./...
go tool golangci-lint run --issues-exit-code=1 ./...
go test ./...
```

Optional: `go tool govulncheck ./... || true`

### Cargo / Rust

```bash
cargo clippy --locked -- -D warnings
cargo test --locked -p echo-server
```

Optional: `cargo audit || true`

### Python (pip-compile)

```bash
python -m pip install -r requirements-dev.txt
ruff check python
ruff format --check python/echo
```

Optional: `pip-audit -r requirements.txt -r requirements-dev.txt || true`

After `.in` bumps, regenerate locks (Python **3.14**, match lock headers):

```bash
pip-compile --strip-extras -o requirements.txt requirements.in
pip-compile --strip-extras -o requirements-dev.txt requirements-dev.in
```

### Bazel

Required when Bazel pins change **or** a coupled language lock/manifest changes
(see Couplings).

```bash
bazel build //...
bazel test //...
```

Do **not** run `bazel run //api/v1:generate` as routine verify (rewrites stubs).

### BSR / codegen

Only when Buf modules, BSR plugins, or generated stubs are in scope (`BUF_TOKEN`
for remotes):

```bash
go tool buf lint --error-format=github-actions
go tool buf generate --template buf.gen.go.yaml
go tool buf generate --template buf.gen.python.yaml --include-imports
go tool buf generate --template buf.gen.rust.yaml
# commit drift under go/api, python/gen, rust/api/gen if any
```

## Rules

- Prefer existing CI steps over inventing tools.
- Do not lower quarantine or disable policy to make verify pass.
- Record commands + results **and which surfaces ran / skipped** in the fix PR body.
