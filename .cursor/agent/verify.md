# Verify after fixes

After applying dependency or code fixes, run these commands. Ship a fix PR only
when they pass. On failure: fix forward or roll back.

## Commands (this product)

Native checks (prefer these for routine dep bumps):

```bash
go mod download
go install tool
go build ./...
go tool golangci-lint run --issues-exit-code=1 ./...
go test ./...
cargo clippy --locked -- -D warnings
cargo test --locked -p echo-server
python -m pip install -r requirements-dev.txt
ruff check python
ruff format --check python/echo
```

Optional advisory scan (informational unless a fix is in scope):

```bash
go tool govulncheck ./... || true
pip-audit -r requirements.txt -r requirements-dev.txt || true
cargo audit || true
```

When the change touches Buf modules, BSR plugins, or generated stubs, also:

```bash
# requires BUF_TOKEN for BSR remotes
go tool buf lint --error-format=github-actions
go tool buf generate --template buf.gen.go.yaml
go tool buf generate --template buf.gen.python.yaml --include-imports
go tool buf generate --template buf.gen.rust.yaml
# then ensure stubs are committed (no `git diff` under go/api, python/gen, rust/api/gen)
```

Optional heavy check (skip for small pin bumps unless Bazel pins changed):

```bash
bazel build //...
bazel test //...
```

## Rules

- Prefer existing CI steps (lint / build / test) over inventing tools.
- Do not lower quarantine or disable policy to make verify pass.
- Record commands + results in the fix PR body.
