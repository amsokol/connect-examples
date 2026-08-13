"""Workspace pip-audit: audit locked Python runtime deps from uv.lock."""

load("@bazel_skylib//lib:shell.bzl", "shell")
load("//bazel:runfiles.bzl", "rlocation")
load("//bazel:workspace_cd.bzl", "RUNFILES_BASH")

def _impl(ctx):
    pip_audit = ctx.executable.pip_audit
    if not pip_audit:
        fail("{}: pip-audit {} is not executable".format(
            ctx.label,
            ctx.attr.pip_audit.label,
        ))
    uv = ctx.file.uv
    if not uv:
        fail("{}: uv {} is missing".format(
            ctx.label,
            ctx.attr.uv.label,
        ))

    ws = ctx.workspace_name
    flags = " ".join([shell.quote(a) for a in ctx.attr.flags])
    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = script,
        content = "".join([
            "#!/usr/bin/env bash\n",
            "set -euo pipefail\n\n",
            RUNFILES_BASH,
            "pip_audit=$(_rf {})\n".format(shell.quote(rlocation(pip_audit, ws))),
            "uv=$(_rf {})\n".format(shell.quote(rlocation(uv, ws))),
            "lock=$(_rf {})\n".format(shell.quote(rlocation(ctx.file.lock, ws))),
            'cd "$(dirname "$lock")"\n\n',
            'reqs="$(mktemp)"\n',
            "trap 'rm -f \"$reqs\"' EXIT\n",
            '"$uv" export --frozen --no-dev --no-emit-project --output-file "$reqs"\n',
            'exec "$pip_audit" -r "$reqs" {flags} "$@"\n'.format(flags = flags),
        ]),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [
        script,
        pip_audit,
        uv,
        ctx.file.lock,
        ctx.file.pyproject,
    ])
    runfiles = runfiles.merge(ctx.attr.pip_audit[DefaultInfo].default_runfiles)
    runfiles = runfiles.merge(ctx.attr.uv[DefaultInfo].default_runfiles)
    return [DefaultInfo(
        executable = script,
        files = depset([script]),
        runfiles = runfiles,
    )]

pip_audit_test = rule(
    implementation = _impl,
    test = True,
    attrs = {
        "flags": attr.string_list(
            doc = "pip-audit arguments after -r <exported lock> (e.g. --disable-pip).",
        ),
        "lock": attr.label(
            default = Label("//:uv.lock"),
            allow_single_file = True,
            doc = "uv.lock used by `uv export --frozen`.",
        ),
        "pip_audit": attr.label(
            default = Label("//bazel/vuln:pip-audit"),
            executable = True,
            cfg = "target",
            doc = "pip-audit console script from the @pypi hub.",
        ),
        "pyproject": attr.label(
            default = Label("//:pyproject.toml"),
            allow_single_file = True,
            doc = "pyproject.toml next to uv.lock (required by uv export).",
        ),
        "uv": attr.label(
            default = Label("@uv//:uv"),
            allow_single_file = True,
            cfg = "exec",
            doc = "uv binary from uv_bin.toolchain (export --frozen).",
        ),
    },
    doc = "bazel test: pip-audit against locked runtime deps (no-sandbox, needs OSV).",
)
