"""Workspace-wide buildifier: cd to the repo, skip hidden dirs."""

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

buildifier=$(_rf {buildifier})
module=$(_rf {workspace})
cd "${{BUILD_WORKSPACE_DIRECTORY:-$(dirname "$module")}}"

find . -path './.*' -prune -o -type f \\( \\
    -name '*.bzl' \\
    -o -name '*.bazel' \\
    -o -name BUILD \\
    -o -name '*.BUILD' \\
    -o -name WORKSPACE \\
    -o -name WORKSPACE.bazel \\
    \\) -print0 \\
    | xargs -r -0 "$buildifier" {flags} "$@"
"""

def _rlocation(file, workspace_name):
    short = file.short_path
    if short.startswith("../"):
        return short[3:]
    return workspace_name + "/" + short

def _impl(ctx):
    buildifier = ctx.executable.buildifier
    if not buildifier:
        fail("{}: buildifier {} is not executable".format(
            ctx.label,
            ctx.attr.buildifier.label,
        ))

    # Not ctx.label.name: //bazel:lint would collide with package bazel/lint.
    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = script,
        content = _SCRIPT.format(
            buildifier = shell.quote(_rlocation(buildifier, ctx.workspace_name)),
            workspace = shell.quote(_rlocation(ctx.file.workspace, ctx.workspace_name)),
            flags = " ".join([shell.quote(a) for a in ctx.attr.flags]),
        ),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [script, buildifier, ctx.file.workspace])
    runfiles = runfiles.merge(ctx.attr.buildifier[DefaultInfo].default_runfiles)
    return [DefaultInfo(
        executable = script,
        files = depset([script]),
        runfiles = runfiles,
    )]

_ATTRS = {
    "buildifier": attr.label(
        default = Label("//bazel/lint:buildifier"),
        executable = True,
        cfg = "target",
        doc = "Buildifier binary (go.mod tool).",
    ),
    "flags": attr.string_list(
        doc = "Extra flags passed to buildifier before discovered files.",
    ),
    "workspace": attr.label(
        default = Label("//:MODULE.bazel"),
        allow_single_file = True,
        doc = "Repo-root marker used when BUILD_WORKSPACE_DIRECTORY is unset.",
    ),
}

buildifier_run = rule(
    implementation = _impl,
    executable = True,
    attrs = _ATTRS,
    doc = "bazel run: format/lint Starlark files in the workspace.",
)

buildifier_test = rule(
    implementation = _impl,
    test = True,
    attrs = _ATTRS,
    doc = "bazel test: check Starlark files in the workspace (no-sandbox).",
)
