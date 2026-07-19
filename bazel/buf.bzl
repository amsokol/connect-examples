"""Hermetic buf generate/lint for Bazel.

Buf CLI: prebuilt from @rules_buf_toolchains (cannot use go_binary — bufprivateusage).
Go plugins: built once as go_binary tools and copied to workdir/bin/.
BSR pins stay in buf.lock.
"""

BufGeneratedInfo = provider(
    doc = "Generated files from buf_generate.",
    fields = {
        "directory": "TreeArtifact directory of generated files.",
    },
)

def _common_proto_dir(srcs):
    """Directory of proto srcs relative to the module root (e.g. api/v1)."""
    dirs = {}
    for src in srcs:
        parts = src.short_path.rsplit("/", 1)
        d = "" if len(parts) == 1 else parts[0]
        dirs[d] = True
    keys = sorted(dirs.keys())
    if len(keys) != 1:
        fail("buf_generate srcs must share a single directory, got: {}".format(keys))
    return keys[0]

def _plugin_executables(ctx):
    """Return File executables for ctx.attr.plugins."""
    out = []
    for target in ctx.attr.plugins:
        exe = target[DefaultInfo].files_to_run.executable
        if exe == None:
            fail("buf_generate plugin {} is not executable".format(target.label))
        out.append(exe)
    return out

def _workdir_lines(ctx, buf_bin, plugins):
    """Buf module workdir; optional plugin binaries + go wrapper on PATH."""
    lines = [
        "set -euo pipefail",
        'BUF="$(realpath "{}")"'.format(buf_bin.path),
        'WORKDIR="$PWD/{}.work"'.format(ctx.label.name),
        'rm -rf "$WORKDIR"',
        'mkdir -p "$WORKDIR"',
        'cp "{}" "$WORKDIR/buf.yaml"'.format(ctx.file.config.path),
        'cp "{}" "$WORKDIR/buf.lock"'.format(ctx.file.lock.path),
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
    for src in ctx.files.srcs:
        lines.append('mkdir -p "$WORKDIR/$(dirname "{}")"'.format(src.short_path))
        lines.append('cp "{}" "$WORKDIR/{}"'.format(src.path, src.short_path))
    return lines

def _run_buf(ctx, *, outputs, extra_inputs, lines, mnemonic, progress_message, plugins):
    """Run hermetic `$BUF ...` with a prebuilt buf CLI."""
    buf_bin = ctx.executable._buf
    tools = [buf_bin] + plugins
    ctx.actions.run_shell(
        outputs = outputs,
        inputs = depset(
            direct = ctx.files.srcs + [
                ctx.file.config,
                ctx.file.lock,
            ] + extra_inputs + plugins,
        ),
        tools = tools,
        command = "\n".join(_workdir_lines(ctx, buf_bin, plugins) + lines),
        mnemonic = mnemonic,
        progress_message = progress_message,
        use_default_shell_env = True,
        execution_requirements = {"requires-network": "1"},
    )

_COMMON_ATTRS = {
    "srcs": attr.label_list(
        allow_files = [".proto"],
        mandatory = True,
        doc = "Protobuf sources (paths preserved under the buf module root).",
    ),
    "config": attr.label(
        allow_single_file = True,
        default = Label("//:buf.yaml"),
    ),
    "lock": attr.label(
        allow_single_file = True,
        default = Label("//:buf.lock"),
    ),
    "_buf": attr.label(
        default = Label("@rules_buf_toolchains//:buf"),
        executable = True,
        cfg = "exec",
        allow_single_file = True,
    ),
}

def _buf_generate_impl(ctx):
    out_dir = ctx.actions.declare_directory(ctx.label.name)
    outdir = ctx.attr.outdir
    proto_dir = _common_proto_dir(ctx.files.srcs)
    # With --include-imports, plugins also emit imported packages under outdir
    # (e.g. python/gen/buf/validate/). Copy the whole outdir tree in that case.
    if ctx.attr.include_imports:
        generated_rel = outdir
    else:
        generated_rel = outdir if proto_dir == "" else "{}/{}".format(outdir, proto_dir)

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
    doc = """Hermetic `buf generate` with prebuilt CLI and optional go_binary plugins.

    Returns a directory TreeArtifact and BufGeneratedInfo for write_source_files.

    Without include_imports: contents of `<outdir>/<proto_dir>/` (flat).
    With include_imports: full `<outdir>/` tree (nested; imported packages included).
    """,
    attrs = {
        "srcs": _COMMON_ATTRS["srcs"],
        "template": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "buf.gen.yaml template.",
        ),
        "outdir": attr.string(
            mandatory = True,
            doc = "plugins[].out from the template (e.g. \"go\"). Combined with the proto directory.",
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
        "config": _COMMON_ATTRS["config"],
        "lock": _COMMON_ATTRS["lock"],
        "_buf": _COMMON_ATTRS["_buf"],
    },
)

def _buf_lint_test_impl(ctx):
    marker = ctx.actions.declare_file(ctx.label.name + ".ok")
    _run_buf(
        ctx,
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
    doc = "Hermetic `buf lint` test using the shared rules_buf CLI.",
    attrs = _COMMON_ATTRS,
    test = True,
)
