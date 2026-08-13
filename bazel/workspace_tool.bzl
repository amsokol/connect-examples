"""Shared workspace-cd wrappers for lint/vuln tools that exec a hermetic binary."""

load("@bazel_skylib//lib:shell.bzl", "shell")
load("//bazel:go_sdk_env.bzl", "GO_SDK_BASH", "GO_TOOLCHAIN_TYPE", "go_sdk", "go_sdk_runfiles")
load("//bazel:runfiles.bzl", "rlocation")
load("//bazel:workspace_cd.bzl", "WORKSPACE_BASH")

_WORKSPACE_ATTR = attr.label(
    default = Label("//:MODULE.bazel"),
    allow_single_file = True,
    doc = "Repo-root marker used when BUILD_WORKSPACE_DIRECTORY is unset.",
)

def _quote_args(args):
    return " ".join([shell.quote(a) for a in args])

def _tool_cmds(ctx, *, require_flags, find_starlark):
    flags = _quote_args(ctx.attr.flags)
    also = getattr(ctx.attr, "also", [])
    if require_flags and not ctx.attr.flags:
        fail("{}: flags must be non-empty".format(ctx.label))
    if find_starlark:
        return """find . -path './.*' -prune -o -type f \\( \\
    -name '*.bzl' \\
    -o -name '*.bazel' \\
    -o -name BUILD \\
    -o -name '*.BUILD' \\
    -o -name WORKSPACE \\
    -o -name WORKSPACE.bazel \\
    \\) -print0 \\
    | xargs -r -0 "$tool" """ + flags + ' "$@"'
    if also:
        return '"$tool" {first}\nexec "$tool" {second} "$@"'.format(
            first = flags,
            second = _quote_args(also),
        )
    return 'exec "$tool" {flags} "$@"'.format(flags = flags)

def _workspace_tool_impl(
        ctx,
        *,
        tool,
        tool_target,
        use_go_sdk,
        find_starlark,
        require_flags,
        pre_exec):
    if not tool:
        fail("{}: {} is not executable".format(ctx.label, tool_target.label))

    ws = ctx.workspace_name
    chunks = [
        "#!/usr/bin/env bash\n",
        "set -euo pipefail\n\n",
        WORKSPACE_BASH,
    ]
    sdk = None
    if use_go_sdk:
        chunks.append(GO_SDK_BASH)
        sdk = go_sdk(ctx)

    chunks.append("tool=$(_rf {})\n".format(shell.quote(rlocation(tool, ws))))
    if sdk:
        chunks.append('_export_goroot "$(_rf {})"\n'.format(
            shell.quote(rlocation(sdk.go, ws)),
        ))
    chunks.append('cd "$(_workspace_dir "$(_rf {})")"\n'.format(
        shell.quote(rlocation(ctx.file.workspace, ws)),
    ))
    if pre_exec:
        chunks.append(pre_exec)
        if not pre_exec.endswith("\n"):
            chunks.append("\n")
    chunks.append(_tool_cmds(ctx, require_flags = require_flags, find_starlark = find_starlark))
    chunks.append("\n")

    # Not ctx.label.name: //bazel:lint would collide with package bazel/lint.
    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = script,
        content = "".join(chunks),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [script, tool, ctx.file.workspace])
    runfiles = runfiles.merge(tool_target[DefaultInfo].default_runfiles)
    if sdk:
        runfiles = runfiles.merge(go_sdk_runfiles(ctx, sdk))
    return [DefaultInfo(
        executable = script,
        files = depset([script]),
        runfiles = runfiles,
    )]

def workspace_tool_rule(
        *,
        doc,
        tool_attr,
        tool_default,
        tool_doc,
        flags_doc,
        executable = False,
        test = False,
        use_go_sdk = False,
        find_starlark = False,
        require_flags = False,
        pre_exec = "",
        extra_attrs = None):
    """Return a run or test rule that cds to the workspace and execs `tool`.

    Args:
      doc: Rule doc.
      tool_attr: Attribute name for the hermetic binary (e.g. "golangci").
      tool_default: Default label string for that binary.
      tool_doc: Attribute doc for the binary.
      flags_doc: Attribute doc for `flags`.
      executable: If True, `bazel run` rule.
      test: If True, `bazel test` rule.
      use_go_sdk: Put the resolved rules_go SDK on PATH.
      find_starlark: Discover Starlark files with find|xargs (buildifier).
      require_flags: Fail if `flags` is empty (ruff).
      pre_exec: Optional bash after `cd`, before the tool (markdownlint env).
      extra_attrs: Extra rule attributes (e.g. ruff `also`).

    Returns:
      A `rule` with the same public attribute names as the former per-tool rules.
    """
    if executable == test:
        fail("workspace_tool_rule: set exactly one of executable or test")

    attrs = {
        tool_attr: attr.label(
            default = Label(tool_default),
            executable = True,
            cfg = "target",
            doc = tool_doc,
        ),
        "flags": attr.string_list(doc = flags_doc),
        "workspace": _WORKSPACE_ATTR,
    }
    if extra_attrs:
        attrs.update(extra_attrs)

    def _impl(ctx):
        return _workspace_tool_impl(
            ctx,
            tool = getattr(ctx.executable, tool_attr),
            tool_target = getattr(ctx.attr, tool_attr),
            use_go_sdk = use_go_sdk,
            find_starlark = find_starlark,
            require_flags = require_flags,
            pre_exec = pre_exec,
        )

    return rule(
        implementation = _impl,
        executable = executable,
        test = test,
        toolchains = [GO_TOOLCHAIN_TYPE] if use_go_sdk else [],
        attrs = attrs,
        doc = doc,
    )
