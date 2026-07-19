"""Hermetic buf generate/lint for Bazel.

Buf CLI: prebuilt from @rules_buf_toolchains (cannot use go_binary — bufprivateusage).
Go plugins: built once as go_binary tools and copied to workdir/bin/.
Module layout (buf.yaml / buf.lock / protos) comes from buf_module.
"""

BufGeneratedInfo = provider(
    doc = "Generated files from buf_generate.",
    fields = {
        "directory": "TreeArtifact directory of generated files.",
    },
)

def _module_directory(ctx):
    """Single TreeArtifact from a buf_module dependency."""
    files = ctx.files.module
    if len(files) != 1:
        fail("{}: module must be a single directory (buf_module), got {}".format(
            ctx.label,
            [f.path for f in files],
        ))
    return files[0]

def _plugin_executables(ctx):
    """Return File executables for ctx.attr.plugins."""
    out = []
    for target in ctx.attr.plugins:
        exe = target[DefaultInfo].files_to_run.executable
        if exe == None:
            fail("buf_generate plugin {} is not executable".format(target.label))
        out.append(exe)
    return out

def _workdir_lines(ctx, buf_bin, module_dir, plugins):
    """Copy buf_module into a workdir; optional plugin binaries + go wrapper on PATH."""
    lines = [
        "set -euo pipefail",
        'BUF="$(realpath "{}")"'.format(buf_bin.path),
        'WORKDIR="$PWD/{}.work"'.format(ctx.label.name),
        'rm -rf "$WORKDIR"',
        'mkdir -p "$WORKDIR"',
        'cp -a "{}/." "$WORKDIR/"'.format(module_dir.path),
    ]
    if plugins:
        # Template keeps `local: [go, tool, <plugin>]` for non-Bazel (`go tool buf`).
        # Bazel puts real plugin binaries in bin/ and a `go` shim that execs them.
        lines.append('mkdir -p "$WORKDIR/bin"')
        for plugin in plugins:
            lines.append(
                'cp "{0}" "$WORKDIR/bin/{1}" && chmod +x "$WORKDIR/bin/{1}"'.format(
                    plugin.path,
                    plugin.basename,
                ),
            )
        lines.extend([
            'cat > "$WORKDIR/bin/go" <<\'EOF\'',
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'BIN_DIR="$(cd "$(dirname "$0")" && pwd)"',
            'if [[ "${1:-}" == "tool" && -n "${2:-}" && -x "$BIN_DIR/$2" ]]; then',
            '  tool="$2"',
            "  shift 2",
            '  exec "$BIN_DIR/$tool" "$@"',
            "fi",
            'echo "buf_generate go wrapper: unsupported args: $*" >&2',
            "exit 1",
            "EOF",
            'chmod +x "$WORKDIR/bin/go"',
            'export PATH="$WORKDIR/bin:/usr/bin:/bin"',
        ])
    return lines

def _run_buf(ctx, *, module_dir, outputs, extra_inputs, lines, mnemonic, progress_message, plugins):
    """Run hermetic `$BUF ...` with a prebuilt buf CLI over a staged module."""
    buf_bin = ctx.executable._buf
    tools = [buf_bin] + plugins
    ctx.actions.run_shell(
        outputs = outputs,
        inputs = depset(
            direct = [module_dir] + extra_inputs + plugins,
        ),
        tools = tools,
        command = "\n".join(_workdir_lines(ctx, buf_bin, module_dir, plugins) + lines),
        mnemonic = mnemonic,
        progress_message = progress_message,
        use_default_shell_env = True,
        execution_requirements = {"requires-network": "1"},
    )

_MODULE_ATTR = attr.label(
    allow_files = True,
    mandatory = True,
    doc = "buf_module TreeArtifact (buf.yaml, buf.lock, protos).",
)

_BUF_ATTR = attr.label(
    default = Label("@rules_buf_toolchains//:buf"),
    executable = True,
    cfg = "exec",
    allow_single_file = True,
)

def _buf_generate_impl(ctx):
    out_dir = ctx.actions.declare_directory(ctx.label.name)
    outdir = ctx.attr.outdir
    module_dir = _module_directory(ctx)

    # With --include-imports, plugins also emit imported packages under outdir
    # (e.g. python/gen/buf/validate/). Copy the whole outdir tree in that case.
    if ctx.attr.include_imports:
        generated_rel = outdir
    else:
        proto_dir = ctx.attr.proto_dir
        if not proto_dir:
            fail("{}: proto_dir is required when include_imports is False".format(ctx.label))
        generated_rel = "{}/{}".format(outdir, proto_dir)

    plugins = _plugin_executables(ctx)
    generate = '"$BUF" generate --template buf.gen.yaml'
    if ctx.attr.include_imports:
        generate += " --include-imports"

    lines = [
        'cp "{}" "$WORKDIR/buf.gen.yaml"'.format(ctx.file.template.path),
        'mkdir -p "{}"'.format(out_dir.path),
        'OUT="$(realpath "{}")"'.format(out_dir.path),
        'cd "$WORKDIR"',
        generate,
        'if [[ ! -d "{}" ]]; then'.format(generated_rel),
        '  echo "buf_generate: expected \'{}\' was not created" >&2'.format(generated_rel),
        "  exit 1",
        "fi",
        'cp -a "{}/." "$OUT/"'.format(generated_rel),
    ]
    if ctx.attr.include_imports:
        # Package markers for directory sync; remote py plugins do not emit them.
        lines.extend([
            'find "$OUT" -type d -print0 | while IFS= read -r -d "" d; do',
            '  if [[ ! -f "$d/__init__.py" ]]; then',
            '    printf "%s\\n" "from __future__ import annotations" > "$d/__init__.py"',
            "  fi",
            "done",
        ])

    _run_buf(
        ctx,
        module_dir = module_dir,
        outputs = [out_dir],
        extra_inputs = [ctx.file.template],
        lines = lines,
        mnemonic = "BufGenerate",
        progress_message = "Generating %{label} with buf",
        plugins = plugins,
    )
    return [
        DefaultInfo(files = depset([out_dir])),
        BufGeneratedInfo(directory = out_dir),
    ]

buf_generate = rule(
    implementation = _buf_generate_impl,
    doc = """Hermetic `buf generate` over a buf_module, with optional go_binary plugins.

    Returns a directory TreeArtifact and BufGeneratedInfo for write_source_files.

    Without include_imports: contents of `<outdir>/<proto_dir>/` (flat).
    With include_imports: full `<outdir>/` tree (nested; imported packages included).
    """,
    attrs = {
        "module": _MODULE_ATTR,
        "template": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "buf.gen.yaml template.",
        ),
        "outdir": attr.string(
            mandatory = True,
            doc = "plugins[].out from the template (e.g. \"go\"). Combined with proto_dir.",
        ),
        "proto_dir": attr.string(
            default = "",
            doc = "Proto package dir inside the module (e.g. \"api/v1\"). Required unless include_imports.",
        ),
        "include_imports": attr.bool(
            default = False,
            doc = "Pass --include-imports to buf generate.",
        ),
        "plugins": attr.label_list(
            cfg = "exec",
            default = [],
            doc = "Local plugin go_binary targets; used via a PATH go shim for [go, tool, <name>].",
        ),
        "_buf": _BUF_ATTR,
    },
)

def _buf_lint_test_impl(ctx):
    module_dir = _module_directory(ctx)
    marker = ctx.actions.declare_file(ctx.label.name + ".ok")
    _run_buf(
        ctx,
        module_dir = module_dir,
        outputs = [marker],
        extra_inputs = [],
        lines = [
            'MARKER="$PWD/{}"'.format(marker.path),
            'mkdir -p "$(dirname "$MARKER")"',
            'cd "$WORKDIR"',
            '"$BUF" lint',
            'touch "$MARKER"',
        ],
        mnemonic = "BufLint",
        progress_message = "Linting %{label} with buf",
        plugins = [],
    )
    runner = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        output = runner,
        content = "#!/usr/bin/env bash\nset -euo pipefail\nexit 0\n",
        is_executable = True,
    )
    return [DefaultInfo(
        executable = runner,
        runfiles = ctx.runfiles(files = [marker]),
    )]

buf_lint_test = rule(
    implementation = _buf_lint_test_impl,
    doc = "Hermetic `buf lint` test over a buf_module.",
    attrs = {
        "module": _MODULE_ATTR,
        "_buf": _BUF_ATTR,
    },
    test = True,
)

def _buf_module_impl(ctx):
    """Stage buf.yaml + buf.lock + protos into a TreeArtifact with workspace layout."""
    out = ctx.actions.declare_directory(ctx.label.name)
    lines = [
        "set -euo pipefail",
        'OUT="{}"'.format(out.path),
        'rm -rf "$OUT"',
        'mkdir -p "$OUT"',
        'cp "{}" "$OUT/buf.yaml"'.format(ctx.file.config.path),
        'cp "{}" "$OUT/buf.lock"'.format(ctx.file.lock.path),
    ]
    for src in ctx.files.srcs:
        lines.append('mkdir -p "$OUT/$(dirname "{}")"'.format(src.short_path))
        lines.append('cp "{}" "$OUT/{}"'.format(src.path, src.short_path))
    ctx.actions.run_shell(
        outputs = [out],
        inputs = depset(direct = ctx.files.srcs + [ctx.file.config, ctx.file.lock]),
        command = "\n".join(lines),
        mnemonic = "BufModule",
        progress_message = "Staging buf module %{label}",
    )
    return [DefaultInfo(files = depset([out]))]

buf_module = rule(
    implementation = _buf_module_impl,
    doc = """Directory with `buf.yaml`, `buf.lock`, and protos at their workspace-relative paths.

    Shared by Rust (`CONNECT_BUF_ROOT`), buf_generate, and buf_lint_test.
    """,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".proto"],
            mandatory = True,
            doc = "Protobuf sources (paths preserved under the module root).",
        ),
        "config": attr.label(
            allow_single_file = True,
            default = Label("//:buf.yaml"),
        ),
        "lock": attr.label(
            allow_single_file = True,
            default = Label("//:buf.lock"),
        ),
    },
)
