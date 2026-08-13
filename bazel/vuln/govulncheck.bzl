"""Workspace govulncheck: cd to the repo, run on ./go/..."""

load("@bazel_skylib//lib:shell.bzl", "shell")
load("//bazel:workspace_cd.bzl", "WORKSPACE_BASH")

_SCRIPT = """\
#!/usr/bin/env bash
set -euo pipefail

""" + WORKSPACE_BASH + """
govulncheck=$(_rf {govulncheck})
cd "$(_workspace_dir "$(_rf {workspace})")"
exec "$govulncheck" {flags} "$@"
"""

def _rlocation(file, workspace_name):
    short = file.short_path
    if short.startswith("../"):
        return short[3:]
    return workspace_name + "/" + short

def _impl(ctx):
    govulncheck = ctx.executable.govulncheck
    if not govulncheck:
        fail("{}: govulncheck {} is not executable".format(
            ctx.label,
            ctx.attr.govulncheck.label,
        ))

    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = script,
        content = _SCRIPT.format(
            govulncheck = shell.quote(_rlocation(govulncheck, ctx.workspace_name)),
            workspace = shell.quote(_rlocation(ctx.file.workspace, ctx.workspace_name)),
            flags = " ".join([shell.quote(a) for a in ctx.attr.flags]),
        ),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [script, govulncheck, ctx.file.workspace])
    runfiles = runfiles.merge(ctx.attr.govulncheck[DefaultInfo].default_runfiles)
    return [DefaultInfo(
        executable = script,
        files = depset([script]),
        runfiles = runfiles,
    )]

govulncheck_test = rule(
    implementation = _impl,
    test = True,
    attrs = {
        "flags": attr.string_list(
            doc = "govulncheck arguments after the binary (e.g. ./go/...).",
        ),
        "govulncheck": attr.label(
            default = Label("//bazel/vuln:govulncheck"),
            executable = True,
            cfg = "target",
            doc = "govulncheck binary (go.mod tool).",
        ),
        "workspace": attr.label(
            default = Label("//:MODULE.bazel"),
            allow_single_file = True,
            doc = "Repo-root marker used when BUILD_WORKSPACE_DIRECTORY is unset.",
        ),
    },
    doc = "bazel test: govulncheck against the workspace (no-sandbox, needs vuln.go.dev).",
)
