"""Hermetic ruff wheel binary, workspace check tests, and format run targets."""

load("@bazel_lib//lib:copy_file.bzl", "COPY_FILE_TOOLCHAINS", "copy_file_action")
load("@bazel_skylib//lib:shell.bzl", "shell")

def _ruff_binary_impl(ctx):
    """Copy `bin/ruff` out of the installed ruff wheel (no console_scripts)."""
    dirs = [
        f
        for f in ctx.attr.pkg[DefaultInfo].default_runfiles.files.to_list()
        if f.is_directory and f.basename == "install"
    ]
    if len(dirs) != 1:
        fail("{}: expected one wheel install dir from {}, got {}".format(
            ctx.label,
            ctx.attr.pkg.label,
            [d.path for d in dirs],
        ))
    exe = ctx.actions.declare_file(ctx.label.name)
    copy_file_action(ctx, dirs[0], exe, dir_path = ctx.attr.script_path)
    return [
        DefaultInfo(
            executable = exe,
            files = depset([exe]),
            runfiles = ctx.runfiles(files = [exe]),
        ),
    ]

ruff_binary = rule(
    implementation = _ruff_binary_impl,
    doc = "Native ruff executable from the pinned @pypi wheel install.",
    executable = True,
    attrs = {
        "pkg": attr.label(
            doc = "Hub package providing the installed ruff wheel.",
            mandatory = True,
        ),
        "script_path": attr.string(
            default = "bin/ruff",
            doc = "Path to the ruff binary inside the wheel install directory.",
        ),
    },
    toolchains = COPY_FILE_TOOLCHAINS,
)

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

ruff=$(_rf {ruff})
module=$(_rf {workspace})
cd "${{BUILD_WORKSPACE_DIRECTORY:-$(dirname "$module")}}"
{ruff_cmds}
"""

def _rlocation(file, workspace_name):
    short = file.short_path
    if short.startswith("../"):
        return short[3:]
    return workspace_name + "/" + short

def _ruff_cmds(ctx):
    if not ctx.attr.flags:
        fail("{}: flags must be non-empty".format(ctx.label))
    first = " ".join([shell.quote(a) for a in ctx.attr.flags])
    if not ctx.attr.also:
        return 'exec "$ruff" {} "$@"'.format(first)
    second = " ".join([shell.quote(a) for a in ctx.attr.also])
    return '"$ruff" {first}\nexec "$ruff" {second} "$@"'.format(
        first = first,
        second = second,
    )

def _ruff_impl(ctx):
    ruff = ctx.executable.ruff
    if not ruff:
        fail("{}: ruff {} is not executable".format(ctx.label, ctx.attr.ruff.label))

    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = script,
        content = _SCRIPT.format(
            ruff = shell.quote(_rlocation(ruff, ctx.workspace_name)),
            workspace = shell.quote(_rlocation(ctx.file.workspace, ctx.workspace_name)),
            ruff_cmds = _ruff_cmds(ctx),
        ),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [script, ruff, ctx.file.workspace])
    runfiles = runfiles.merge(ctx.attr.ruff[DefaultInfo].default_runfiles)
    return [DefaultInfo(
        executable = script,
        files = depset([script]),
        runfiles = runfiles,
    )]

_ATTRS = {
    "also": attr.string_list(
        doc = "Optional second ruff argv (e.g. format --check python) after flags.",
    ),
    "flags": attr.string_list(
        doc = "ruff arguments after the binary (e.g. check python).",
    ),
    "ruff": attr.label(
        default = Label("//bazel/lint:ruff"),
        executable = True,
        cfg = "target",
        doc = "Ruff binary from the @pypi wheel.",
    ),
    "workspace": attr.label(
        default = Label("//:MODULE.bazel"),
        allow_single_file = True,
        doc = "Repo-root marker used when BUILD_WORKSPACE_DIRECTORY is unset.",
    ),
}

ruff_run = rule(
    implementation = _ruff_impl,
    executable = True,
    attrs = _ATTRS,
    doc = "bazel run: ruff against the workspace (writes when invoked as format).",
)

ruff_test = rule(
    implementation = _ruff_impl,
    test = True,
    attrs = _ATTRS,
    doc = "bazel test: ruff against the workspace (no-sandbox, check-only).",
)
