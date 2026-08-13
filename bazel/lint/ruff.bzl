"""Hermetic ruff: native wheel binary as the test executable."""

load("@bazel_lib//lib:copy_file.bzl", "COPY_FILE_TOOLCHAINS", "copy_file_action")

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

def _ruff_test_impl(ctx):
    ruff = ctx.attr._ruff[DefaultInfo]
    ruff_exe = ruff.files_to_run.executable
    if not ruff_exe:
        fail("{}: ruff binary {} is not executable".format(ctx.label, ctx.attr._ruff.label))

    exe = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(output = exe, target_file = ruff_exe, is_executable = True)

    runfiles = ctx.runfiles(
        files = ctx.files.srcs + [ctx.file.config, exe],
    ).merge(ruff.default_runfiles)

    return [
        DefaultInfo(
            executable = exe,
            runfiles = runfiles,
        ),
    ]

ruff_test = rule(
    implementation = _ruff_test_impl,
    doc = """Runs hermetic ruff as the test executable.

    Pass ruff subcommands via the implicit test `args` (e.g. `check python`).
    `srcs` and `config` are in the test runfiles at their workspace paths.
    """,
    test = True,
    attrs = {
        "config": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "Ruff config (root pyproject.toml).",
        ),
        "srcs": attr.label_list(
            allow_files = True,
            mandatory = True,
            doc = "Python sources to place in runfiles.",
        ),
        "_ruff": attr.label(
            default = Label("//bazel/lint:ruff"),
            executable = True,
            cfg = "target",
        ),
    },
)
