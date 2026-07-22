# Agent policy — connect-examples

Connect RPC examples (Go, Python, Rust) + Bazel + Buf. Shared procedures:
[`library/policy/entry.md`](library/policy/entry.md).

Overlay only: this file, [`verify.md`](verify.md), [`quarantine.md`](quarantine.md).

## Enabled ecosystems

Only listed ecosystems are in scope for deps-policy / deps-vuln. Read all topics
under each folder (`detect`, `update`, `publish-time`, `advisories`, `caution`).

- [`library/ecosystems/go-modules/detect.md`](library/ecosystems/go-modules/detect.md)
- [`library/ecosystems/cargo/detect.md`](library/ecosystems/cargo/detect.md)
- [`library/ecosystems/bazel/detect.md`](library/ecosystems/bazel/detect.md)
- [`library/ecosystems/bsr/detect.md`](library/ecosystems/bsr/detect.md)
- [`library/ecosystems/python-pip-compile/detect.md`](library/ecosystems/python-pip-compile/detect.md)
- [`library/ecosystems/github-actions/detect.md`](library/ecosystems/github-actions/detect.md)

## Hotspots

- Go: `go.mod`, `go.sum`, `go/`
- Rust: `Cargo.toml`, `Cargo.lock`, `rust/`
- Bazel: `MODULE.bazel`, `*.MODULE.bazel`, `MODULE.bazel.lock`
- Buf: `buf.yaml`, `buf.lock`, `buf.gen.*.yaml`, `api/`
- Python: `requirements.in`, `requirements-dev.in`, `requirements.txt`,
  `requirements-dev.txt`
- GitHub Actions: `.github/workflows/` (`uses:` pins, `BAZELISK_VERSION` in CI)
- Existing `agent:` holds and bundles (e.g. connect-rust / buffa train,
  `mimalloc` git tag)

## Product notes

- Gate: changed pins in `go.mod` / `go.sum`, workspace `Cargo.toml` /
  `Cargo.lock`, `MODULE.bazel` / includes / lock, `buf.yaml` / `buf.lock` /
  `buf.gen.*.yaml`, Python `.in`/locks, workflow action/tool pins
- High-impact majors need human OK or unlock: Go toolchain, connect-rust /
  buffa train, Bazel major rulesets, Buf CLI / BSR plugins that break codegen,
  `connectrpc` PyPI ↔ BSR Python plugins
- Quarantine: **2 days** (see [`quarantine.md`](quarantine.md))
- After BSR / codegen-related bumps, regenerate stubs (`buf generate` or
  `bazel run //api/v1:generate`) and commit drift; CI needs `BUF_TOKEN`
- Python: bump `.in` then `pip-compile` (Python 3.14, `--strip-extras`); keep
  Bazel runtime lock (`requirements.txt`) in sync
