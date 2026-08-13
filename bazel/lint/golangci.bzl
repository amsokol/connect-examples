"""Workspace golangci-lint: cd to the repo, run on ./go/..."""

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

golangci=$(_rf {golangci})
module=$(_rf {workspace})
cd "${{BUILD_WORKSPACE_DIRECTORY:-$(dirname "$module")}}"
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

    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = script,
        content = _SCRIPT.format(
            golangci = shell.quote(_rlocation(golangci, ctx.workspace_name)),
            workspace = shell.quote(_rlocation(ctx.file.workspace, ctx.workspace_name)),
            flags = " ".join([shell.quote(a) for a in ctx.attr.flags]),
        ),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [script, golangci, ctx.file.workspace])
    runfiles = runfiles.merge(ctx.attr.golangci[DefaultInfo].default_runfiles)
    return [DefaultInfo(
        executable = script,
        files = depset([script]),
        runfiles = runfiles,
    )]

golangci_test = rule(
    implementation = _impl,
    test = True,
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
