"""Workspace cargo-audit: audit locked crates from Cargo.lock."""

load("@bazel_skylib//lib:shell.bzl", "shell")
load("//bazel:runfiles.bzl", "rlocation")
load("//bazel:workspace_cd.bzl", "RUNFILES_BASH")

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

    ws = ctx.workspace_name
    flags = " ".join([shell.quote(a) for a in ctx.attr.flags])
    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = script,
        content = "".join([
            "#!/usr/bin/env bash\n",
            "set -euo pipefail\n\n",
            RUNFILES_BASH,
            "cargo_audit=$(_rf {})\n".format(shell.quote(rlocation(cargo_audit, ws))),
            "cargo=$(_rf {})\n".format(shell.quote(rlocation(cargo, ws))),
            "lock=$(_rf {})\n".format(shell.quote(rlocation(ctx.file.lock, ws))),
            'cd "$(dirname "$lock")"\n\n',
            "# tame-index runs `$CARGO -V` (else `cargo`) to pick the crates.io index hash.\n",
            "# debian:13 CI has no host cargo; use the rules_rust toolchain binary.\n",
            'export CARGO="$cargo"\n',
            'export PATH="$(dirname "$cargo"):${PATH:-}"\n',
            "export CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse\n\n",
            'export CARGO_HOME="${TEST_TMPDIR:-${TMPDIR:-/tmp}}/cargo-audit-home"\n',
            'mkdir -p "$CARGO_HOME"\n',
            'exec "$cargo_audit" audit {flags} "$@"\n'.format(flags = flags),
        ]),
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
