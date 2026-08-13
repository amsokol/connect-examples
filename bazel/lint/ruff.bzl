"""Hermetic ruff wheel binary, workspace check tests, and format run targets."""

load("@bazel_lib//lib:copy_file.bzl", "COPY_FILE_TOOLCHAINS", "copy_file_action")
load("//bazel:workspace_tool.bzl", "workspace_tool_rule")

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

_RUFF_ATTRS = {
    "also": attr.string_list(
        doc = "Optional second ruff argv (e.g. format --check python) after flags.",
    ),
}

def _ruff(*, executable = False, test = False):
    return workspace_tool_rule(
        executable = executable,
        test = test,
        tool_attr = "ruff",
        tool_default = "//bazel/lint:ruff",
        tool_doc = "Ruff binary from the @pypi wheel.",
        flags_doc = "ruff arguments after the binary (e.g. check python).",
        doc = "bazel run: ruff against the workspace (writes when invoked as format)." if executable else "bazel test: ruff against the workspace (no-sandbox, check-only).",
        require_flags = True,
        extra_attrs = _RUFF_ATTRS,
    )

ruff_run = _ruff(executable = True)

ruff_test = _ruff(test = True)
