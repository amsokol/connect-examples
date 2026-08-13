"""Hermetic buf generate/lint for Bazel.

Buf CLI: prebuilt from @rules_buf_toolchains (cannot use go_binary — bufprivateusage).
Codegen plugins are Bazel-built executables on PATH (not host PATH, not BSR remotes).
Workspace config is //bazel/buf:buf.yaml. Protovalidate protos come from
@protovalidate_proto and are staged at third_party/protovalidate (no BSR network).
"""

BufGeneratedInfo = provider(
    doc = "Generated files from buf_generate.",
    fields = {
        "directory": "TreeArtifact directory of generated files.",
    },
)

# Must match the local module path in //bazel/buf:buf.yaml.
_PROTOVALIDATE_MODULE_PATH = "third_party/protovalidate"

def _module_directory(ctx):
    """Single TreeArtifact from a buf_module dependency."""
    files = ctx.files.module
    if len(files) != 1:
        fail("{}: module must be a single directory (buf_module), got {}".format(
            ctx.label,
            [f.path for f in files],
        ))
    return files[0]

def _external_rel(file):
    """Path of an external file relative to its repository root."""
    sp = file.short_path
    if sp.startswith("../"):
        rest = sp[3:]
        slash = rest.find("/")
        if slash == -1:
            return rest
        return rest[slash + 1:]
    return sp

def _plugin_path_lines(ctx):
    """Write PATH wrappers that exec Bazel-built plugins."""
    lines = [
        'PLUGIN_BIN="$WORKDIR/plugin_bin"',
        'mkdir -p "$PLUGIN_BIN"',
    ]
    for i, target in enumerate(ctx.attr.plugins):
        exe = target[DefaultInfo].files_to_run.executable
        if not exe:
            fail("{}: plugin {} has no executable".format(ctx.label, target.label))
        name = target.label.name
        lines.append('PLUGIN_{}="$(realpath "{}")"'.format(i, exe.path))
        # Quote $@ so it is expanded when buf invokes the wrapper, not when
        # this action writes the wrapper (unquoted EOF would bake in "").
        lines.append("\n".join([
            'cat > "$PLUGIN_BIN/{}" <<EOF'.format(name),
            "#!/usr/bin/env bash",
            'exec "$PLUGIN_{}" "\\$@"'.format(i),
            "EOF",
            'chmod +x "$PLUGIN_BIN/{}"'.format(name),
        ]))
    lines.append('export PATH="$PLUGIN_BIN:$PATH"')
    lines.extend([
        'export HOME="$WORKDIR/home"',
        'export BUF_CACHE_DIR="$WORKDIR/buf-cache"',
        'mkdir -p "$HOME" "$BUF_CACHE_DIR"',
    ])
    return lines

def _workdir_lines(ctx, buf_bin, module_dir):
    """Copy buf_module into a workdir for hermetic buf CLI."""
    return [
        "set -euo pipefail",
        'BUF="$(realpath "{}")"'.format(buf_bin.path),
        'WORKDIR="$PWD/{}.work"'.format(ctx.label.name),
        'rm -rf "$WORKDIR"',
        'mkdir -p "$WORKDIR"',
        'cp -a "{}/." "$WORKDIR/"'.format(module_dir.path),
    ]

def _run_buf(ctx, *, module_dir, outputs, extra_inputs, extra_tools, lines, mnemonic, progress_message):
    """Run hermetic `$BUF ...` with a prebuilt buf CLI over a staged module."""
    buf_bin = ctx.executable._buf
    plugin_tools = [
        t[DefaultInfo].files_to_run
        for t in getattr(ctx.attr, "plugins", [])
    ]
    ctx.actions.run_shell(
        outputs = outputs,
        inputs = depset(
            direct = [module_dir] + extra_inputs,
        ),
        tools = [buf_bin] + extra_tools + plugin_tools,
        command = "\n".join(_workdir_lines(ctx, buf_bin, module_dir) + lines),
        mnemonic = mnemonic,
        progress_message = progress_message,
        use_default_shell_env = True,
    )

_MODULE_ATTR = attr.label(
    allow_files = True,
    mandatory = True,
    doc = "buf_module TreeArtifact (hermetic buf.yaml + protos + protovalidate).",
)

_BUF_ATTR = attr.label(
    default = Label("@rules_buf_toolchains//:buf"),
    executable = True,
    cfg = "exec",
    allow_single_file = True,
)

_PLUGIN_ATTR = attr.label_list(
    mandatory = True,
    cfg = "exec",
    allow_files = True,
    doc = "Local codegen plugins; wrapped onto PATH under their target names.",
)

def _buf_generate_impl(ctx):
    out_dir = ctx.actions.declare_directory(ctx.label.name)
    outdir = ctx.attr.outdir
    module_dir = _module_directory(ctx)

    if ctx.attr.include_imports or ctx.attr.full_tree:
        generated_rel = outdir
    else:
        proto_dir = ctx.attr.proto_dir
        if not proto_dir:
            fail("{}: proto_dir is required when include_imports/full_tree is False".format(ctx.label))
        generated_rel = "{}/{}".format(outdir, proto_dir)

    generate = '"$BUF" generate --template buf.gen.yaml --path api'
    if ctx.attr.include_imports:
        generate += " --include-imports"

    lines = _plugin_path_lines(ctx) + [
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

    _run_buf(
        ctx,
        module_dir = module_dir,
        outputs = [out_dir],
        extra_inputs = [ctx.file.template],
        extra_tools = [],
        lines = lines,
        mnemonic = "BufGenerate",
        progress_message = "Generating %{label} with buf",
    )
    return [
        DefaultInfo(files = depset([out_dir])),
        BufGeneratedInfo(directory = out_dir),
    ]

buf_generate = rule(
    implementation = _buf_generate_impl,
    doc = """Hermetic `buf generate` over a buf_module with Bazel-built local plugins.

Returns a directory TreeArtifact and BufGeneratedInfo for write_source_files.

Without include_imports/full_tree: contents of `<outdir>/<proto_dir>/`.
With include_imports or full_tree: full `<outdir>/` tree.
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
            doc = "plugins[].out from the template (e.g. \"go\").",
        ),
        "proto_dir": attr.string(
            default = "",
            doc = "Proto package dir inside the module (e.g. \"api/v1\"). Required unless include_imports/full_tree.",
        ),
        "include_imports": attr.bool(
            default = False,
            doc = "Pass --include-imports to buf generate.",
        ),
        "full_tree": attr.bool(
            default = False,
            doc = "Copy the whole outdir tree without --include-imports.",
        ),
        "plugins": _PLUGIN_ATTR,
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
        extra_tools = [],
        lines = [
            'MARKER="$PWD/{}"'.format(marker.path),
            'mkdir -p "$(dirname "$MARKER")"',
            'export HOME="$WORKDIR/home"',
            'export BUF_CACHE_DIR="$WORKDIR/buf-cache"',
            'mkdir -p "$HOME" "$BUF_CACHE_DIR"',
            'cd "$WORKDIR"',
            '"$BUF" lint --path api',
            'touch "$MARKER"',
        ],
        mnemonic = "BufLint",
        progress_message = "Linting %{label} with buf",
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
    """Stage //bazel/buf:buf.yaml + protos + vendored protovalidate into a TreeArtifact."""
    out = ctx.actions.declare_directory(ctx.label.name)
    lines = [
        "set -euo pipefail",
        'OUT="{}"'.format(out.path),
        'rm -rf "$OUT"',
        'mkdir -p "$OUT/{}"'.format(_PROTOVALIDATE_MODULE_PATH),
        'cp "{}" "$OUT/buf.yaml"'.format(ctx.file._config.path),
    ]
    for src in ctx.files.srcs:
        lines.append('mkdir -p "$OUT/$(dirname "{}")"'.format(src.short_path))
        lines.append('cp "{}" "$OUT/{}"'.format(src.path, src.short_path))
    for src in ctx.files.protovalidate:
        rel = _external_rel(src)
        if rel in ("BUILD", "BUILD.bazel", "WORKSPACE", "WORKSPACE.bazel", "REPO.bazel"):
            continue
        lines.append('mkdir -p "$OUT/{}/$(dirname "{}")"'.format(_PROTOVALIDATE_MODULE_PATH, rel))
        lines.append('cp "{}" "$OUT/{}/{}"'.format(src.path, _PROTOVALIDATE_MODULE_PATH, rel))
    ctx.actions.run_shell(
        outputs = [out],
        inputs = depset(direct = [ctx.file._config] + ctx.files.srcs + ctx.files.protovalidate),
        command = "\n".join(lines),
        mnemonic = "BufModule",
        progress_message = "Staging buf module %{label}",
        use_default_shell_env = True,
    )
    return [DefaultInfo(files = depset([out]))]

buf_module = rule(
    implementation = _buf_module_impl,
    doc = """Directory with //bazel/buf:buf.yaml, vendored protovalidate, and protos at workspace-relative paths.

Shared by buf_generate and buf_lint_test. Does not fetch BSR modules.
""",
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".proto"],
            mandatory = True,
            doc = "Protobuf sources (paths preserved under the module root).",
        ),
        "_config": attr.label(
            allow_single_file = True,
            default = Label("//bazel/buf:buf.yaml"),
        ),
        "protovalidate": attr.label(
            allow_files = True,
            default = Label("@protovalidate_proto//:files"),
            doc = "Pinned buf.build/bufbuild/protovalidate proto files from @protovalidate_proto.",
        ),
    },
)
