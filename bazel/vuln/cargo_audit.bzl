"""Workspace cargo-audit: audit locked crates from Cargo.lock."""

load("@bazel_skylib//lib:shell.bzl", "shell")

_SCRIPT = """\
#!/usr/bin/env bash
set -euo pipefail

_rf() {{
  local path=$1
  if [[ -n "${{RUNFILES_DIR:-}}" && -e "${{RUNFILES_DIR}}/${{path}}" ]]; then
    realpath -- "${{RUNFILES_DIR}}/${{path}}"
    return
  fi
  if [[ -e "$0.runfiles/${{path}}" ]]; then
    realpath -- "$0.runfiles/${{path}}"
    return
  fi
  echo "unable to locate runfile: ${{path}}" >&2
  exit 1
}}

cargo_audit=$(_rf {cargo_audit})
cargo=$(_rf {cargo})
lock=$(_rf {lock})
cd "$(dirname "$lock")"

# tame-index runs `$CARGO -V` (else `cargo`) to pick the crates.io index hash.
# debian:13 CI has no host cargo; use the rules_rust toolchain binary.
export CARGO="$cargo"
export PATH="$(dirname "$cargo"):${{PATH:-}}"
export CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse

export CARGO_HOME="${{TEST_TMPDIR:-${{TMPDIR:-/tmp}}}}/cargo-audit-home"
mkdir -p "$CARGO_HOME"
exec "$cargo_audit" audit {flags} "$@"
"""

def _rlocation(file, workspace_name):
    short = file.short_path
    if short.startswith("../"):
        return short[3:]
    return workspace_name + "/" + short

def _impl(ctx):
    cargo_audit = ctx.executable.cargo_audit
    if not cargo_audit:
        fail("{}: cargo-audit {} is not executable".format(
            ctx.label,
            ctx.attr.cargo_audit.label,
        ))
    cargo = None
    for f in ctx.files.cargo:
        if f.basename in ("cargo", "cargo.exe"):
            cargo = f
            break
    if not cargo:
        fail("{}: {} has no cargo binary".format(ctx.label, ctx.attr.cargo.label))

    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = script,
        content = _SCRIPT.format(
            cargo_audit = shell.quote(_rlocation(cargo_audit, ctx.workspace_name)),
            cargo = shell.quote(_rlocation(cargo, ctx.workspace_name)),
            lock = shell.quote(_rlocation(ctx.file.lock, ctx.workspace_name)),
            flags = " ".join([shell.quote(a) for a in ctx.attr.flags]),
        ),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [
        script,
        cargo_audit,
        cargo,
        ctx.file.lock,
        ctx.file.manifest,
    ])
    runfiles = runfiles.merge(ctx.attr.cargo_audit[DefaultInfo].default_runfiles)
    runfiles = runfiles.merge(ctx.attr.cargo[DefaultInfo].default_runfiles)
    return [DefaultInfo(
        executable = script,
        files = depset([script]),
        runfiles = runfiles,
    )]

cargo_audit_test = rule(
    implementation = _impl,
    test = True,
    attrs = {
        "cargo": attr.label(
            default = Label("@rules_rust//rust/toolchain:current_cargo_files"),
            allow_files = True,
            cfg = "target",
            doc = "Hermetic cargo from the rules_rust toolchain (`cargo -V`).",
        ),
        "cargo_audit": attr.label(
            default = Label("//bazel/vuln:cargo-audit"),
            executable = True,
            cfg = "target",
            doc = "cargo-audit binary from the @cargo hub.",
        ),
        "flags": attr.string_list(
            doc = "cargo-audit arguments after `audit` (e.g. --color never).",
        ),
        "lock": attr.label(
            default = Label("//:Cargo.lock"),
            allow_single_file = True,
            doc = "Cargo.lock to audit.",
        ),
        "manifest": attr.label(
            default = Label("//:Cargo.toml"),
            allow_single_file = True,
            doc = "Cargo.toml next to Cargo.lock (workspace root).",
        ),
    },
    doc = "bazel test: cargo-audit against locked crates (no-sandbox, needs rustsec DB).",
)
