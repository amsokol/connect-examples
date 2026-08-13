"""Workspace golangci-lint: cd to the repo, run on ./go/..."""

load("@bazel_skylib//lib:shell.bzl", "shell")
load("//bazel:go_sdk_env.bzl", "GO_SDK_BASH", "GO_TOOLCHAIN_TYPE", "go_sdk", "go_sdk_runfiles")
load("//bazel:workspace_cd.bzl", "WORKSPACE_BASH")

_SCRIPT = """\
#!/usr/bin/env bash
set -euo pipefail

""" + WORKSPACE_BASH + GO_SDK_BASH + """
golangci=$(_rf {golangci})
_export_goroot "$(_rf {go})"
cd "$(_workspace_dir "$(_rf {workspace})")"
exec "$golangci" {flags} "$@"
"""

def _rlocation(file, workspace_name):
    short = file.short_path
    if short.startswith("../"):
        return short[3:]
    return workspace_name + "/" + short

def _impl(ctx):
    golangci = ctx.executable.golangci
    if not golangci:
        fail("{}: golangci-lint {} is not executable".format(
            ctx.label,
            ctx.attr.golangci.label,
        ))
    sdk = go_sdk(ctx)

    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = script,
        content = _SCRIPT.format(
            golangci = shell.quote(_rlocation(golangci, ctx.workspace_name)),
            go = shell.quote(_rlocation(sdk.go, ctx.workspace_name)),
            workspace = shell.quote(_rlocation(ctx.file.workspace, ctx.workspace_name)),
            flags = " ".join([shell.quote(a) for a in ctx.attr.flags]),
        ),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [script, golangci, ctx.file.workspace])
    runfiles = runfiles.merge(ctx.attr.golangci[DefaultInfo].default_runfiles)
    runfiles = runfiles.merge(go_sdk_runfiles(ctx, sdk))
    return [DefaultInfo(
        executable = script,
        files = depset([script]),
        runfiles = runfiles,
    )]

golangci_test = rule(
    implementation = _impl,
    test = True,
    toolchains = [GO_TOOLCHAIN_TYPE],
    attrs = {
        "flags": attr.string_list(
            doc = "golangci-lint arguments after the binary (e.g. run ./go/...).",
        ),
        "golangci": attr.label(
            default = Label("//bazel/lint:golangci-lint"),
            executable = True,
            cfg = "target",
            doc = "golangci-lint binary (go.mod tool).",
        ),
        "workspace": attr.label(
            default = Label("//:MODULE.bazel"),
            allow_single_file = True,
            doc = "Repo-root marker used when BUILD_WORKSPACE_DIRECTORY is unset.",
        ),
    },
    doc = "bazel test: golangci-lint against the workspace (no-sandbox).",
)
