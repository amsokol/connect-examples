"""Executable wrapper whose target name is the PATH name buf looks up."""

def _buf_plugin_impl(ctx):
    """Wrap an executable so ctx.label.name is the PATH plugin name.

    native.alias is transparent: ctx.attr.plugins then sees the actual
    rust_binary name (often `*_bin` from crate_universe).
    """
    actual = ctx.attr.actual[DefaultInfo]
    exe = actual.files_to_run.executable
    if not exe:
        fail("{}: actual {} has no executable".format(ctx.label, ctx.attr.actual.label))
    out = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(output = out, target_file = exe, is_executable = True)
    runfiles = ctx.runfiles(files = [out]).merge(actual.default_runfiles)
    return [DefaultInfo(
        executable = out,
        runfiles = runfiles,
    )]

buf_plugin = rule(
    implementation = _buf_plugin_impl,
    doc = "Codegen plugin on PATH under this target's name (not the actual binary's name).",
    attrs = {
        "actual": attr.label(
            executable = True,
            cfg = "exec",
            mandatory = True,
        ),
    },
    executable = True,
)
