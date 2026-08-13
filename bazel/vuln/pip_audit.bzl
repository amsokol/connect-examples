"""Workspace pip-audit: audit locked Python runtime deps from uv.lock."""

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

pip_audit=$(_rf {pip_audit})
uv=$(_rf {uv})
lock=$(_rf {lock})
cd "$(dirname "$lock")"

reqs="$(mktemp)"
trap 'rm -f "$reqs"' EXIT
"$uv" export --frozen --no-dev --no-emit-project --output-file "$reqs"
exec "$pip_audit" -r "$reqs" {flags} "$@"
"""

def _rlocation(file, workspace_name):
    short = file.short_path
    if short.startswith("../"):
        return short[3:]
    return workspace_name + "/" + short

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

    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = script,
        content = _SCRIPT.format(
            pip_audit = shell.quote(_rlocation(pip_audit, ctx.workspace_name)),
            uv = shell.quote(_rlocation(uv, ctx.workspace_name)),
            lock = shell.quote(_rlocation(ctx.file.lock, ctx.workspace_name)),
            flags = " ".join([shell.quote(a) for a in ctx.attr.flags]),
        ),
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
