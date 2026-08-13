"""Workspace markdownlint-cli2: cd to the repo, run against config globs."""

load("@bazel_skylib//lib:shell.bzl", "shell")
load("//bazel:workspace_cd.bzl", "WORKSPACE_BASH")

_SCRIPT = """\
#!/usr/bin/env bash
set -euo pipefail

""" + WORKSPACE_BASH + """
markdownlint=$(_rf {markdownlint})
cd "$(_workspace_dir "$(_rf {workspace})")"
export BAZEL_BINDIR="${{BAZEL_BINDIR:-.}}"
export JS_BINARY__CHDIR="$PWD"
exec "$markdownlint" {flags} "$@"
"""

def _rlocation(file, workspace_name):
    short = file.short_path
    if short.startswith("../"):
        return short[3:]
    return workspace_name + "/" + short

def _impl(ctx):
    markdownlint = ctx.executable.markdownlint
    if not markdownlint:
        fail("{}: markdownlint-cli2 {} is not executable".format(
            ctx.label,
            ctx.attr.markdownlint.label,
        ))

    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = script,
        content = _SCRIPT.format(
            markdownlint = shell.quote(_rlocation(markdownlint, ctx.workspace_name)),
            workspace = shell.quote(_rlocation(ctx.file.workspace, ctx.workspace_name)),
            flags = " ".join([shell.quote(a) for a in ctx.attr.flags]),
        ),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [script, markdownlint, ctx.file.workspace])
    runfiles = runfiles.merge(ctx.attr.markdownlint[DefaultInfo].default_runfiles)
    return [DefaultInfo(
        executable = script,
        files = depset([script]),
        runfiles = runfiles,
    )]

markdownlint_test = rule(
    implementation = _impl,
    test = True,
    attrs = {
        "flags": attr.string_list(
            doc = "markdownlint-cli2 arguments (empty uses .markdownlint-cli2.yaml globs).",
        ),
        "markdownlint": attr.label(
            default = Label("//bazel/lint:markdownlint-cli2"),
            executable = True,
            cfg = "target",
            doc = "markdownlint-cli2 js_binary from @npm.",
        ),
        "workspace": attr.label(
            default = Label("//:MODULE.bazel"),
            allow_single_file = True,
            doc = "Repo-root marker used when BUILD_WORKSPACE_DIRECTORY is unset.",
        ),
    },
    doc = "bazel test: markdownlint-cli2 against the workspace (no-sandbox).",
)
