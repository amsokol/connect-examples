"""Hermetic buf generate for `bazel build` via the rules_go Go toolchain.

Runs `go tool buf generate` (never `buf dep update`). Output is a directory
TreeArtifact plus BufGeneratedInfo for write_source_files consumers.
"""

load("@rules_go//go:def.bzl", "go_context")

_GO_TOOLCHAIN = "@rules_go//go:toolchain"

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

def _buf_generate_impl(ctx):
    go = go_context(ctx, maybe_needs_cc_toolchain = False)
    sdk = go.sdk
    go_bin = sdk.go

    out_dir = ctx.actions.declare_directory(ctx.label.name)
    outdir = ctx.attr.outdir
    proto_dir = _common_proto_dir(ctx.files.srcs)
    # With --include-imports, plugins also emit imported packages under outdir
    # (e.g. python/gen/buf/validate/). Copy the whole outdir tree in that case.
    if ctx.attr.include_imports:
        generated_rel = outdir
    else:
        generated_rel = outdir if proto_dir == "" else "{}/{}".format(outdir, proto_dir)

    lines = [
        "set -euo pipefail",
        'GO="$(realpath "{}")"'.format(go_bin.path),
        'export GOROOT="$(cd "$(dirname "$GO")/.." && pwd)"',
        "export GOTOOLCHAIN=local",
        'export GOPATH=""',
        'export GOCACHE="$PWD/{}.gocache"'.format(ctx.label.name),
        'export GOMODCACHE="$PWD/{}.gomodcache"'.format(ctx.label.name),
        'mkdir -p "$GOCACHE" "$GOMODCACHE"',
        'WORKDIR="$PWD/{}.work"'.format(ctx.label.name),
        'rm -rf "$WORKDIR"',
        'mkdir -p "$WORKDIR"',
        'mkdir -p "{}"'.format(out_dir.path),
        'OUT="$(realpath "{}")"'.format(out_dir.path),
        'cp "{}" "$WORKDIR/buf.yaml"'.format(ctx.file.config.path),
        'cp "{}" "$WORKDIR/buf.lock"'.format(ctx.file.lock.path),
        'cp "{}" "$WORKDIR/go.mod"'.format(ctx.file.go_mod.path),
        'cp "{}" "$WORKDIR/go.sum"'.format(ctx.file.go_sum.path),
        'cp "{}" "$WORKDIR/buf.gen.yaml"'.format(ctx.file.template.path),
    ]
    for src in ctx.files.srcs:
        lines.append('mkdir -p "$WORKDIR/$(dirname "{}")"'.format(src.short_path))
        lines.append('cp "{}" "$WORKDIR/{}"'.format(src.path, src.short_path))

    generate = '"$GO" tool buf generate --template buf.gen.yaml'
    if ctx.attr.include_imports:
        generate += " --include-imports"

    lines.extend([
        'cd "$WORKDIR"',
        generate,
        'if [[ ! -d "{}" ]]; then'.format(generated_rel),
        '  echo "buf_generate: expected \'{}\' was not created" >&2'.format(generated_rel),
        "  exit 1",
        "fi",
        'cp -a "{}/." "$OUT/"'.format(generated_rel),
    ])
    if ctx.attr.include_imports:
        # Package markers for directory sync; remote py plugins do not emit them.
        lines.extend([
            'find "$OUT" -type d -print0 | while IFS= read -r -d "" d; do',
            '  if [[ ! -f "$d/__init__.py" ]]; then',
            '    printf "%s\\n" "from __future__ import annotations" > "$d/__init__.py"',
            "  fi",
            "done",
        ])

    sdk_files = depset(
        direct = [go_bin, sdk.root_file, sdk.package_list],
        transitive = [sdk.tools, sdk.headers, sdk.srcs, sdk.libs],
    )

    ctx.actions.run_shell(
        outputs = [out_dir],
        inputs = depset(
            direct = ctx.files.srcs + [
                ctx.file.template,
                ctx.file.config,
                ctx.file.lock,
                ctx.file.go_mod,
                ctx.file.go_sum,
            ],
            transitive = [sdk_files],
        ),
        tools = [go_bin],
        command = "\n".join(lines),
        mnemonic = "BufGenerate",
        progress_message = "Generating %{label} with go tool buf",
        use_default_shell_env = True,
        execution_requirements = {"requires-network": "1"},
    )

    return [
        DefaultInfo(files = depset([out_dir])),
        BufGeneratedInfo(directory = out_dir),
    ]

buf_generate = rule(
    implementation = _buf_generate_impl,
    doc = """Hermetic `go tool buf generate` (rules_go toolchain).

    Returns a directory TreeArtifact and BufGeneratedInfo for write_source_files.

    Without include_imports: contents of `<outdir>/<proto_dir>/` (flat).
    With include_imports: full `<outdir>/` tree (nested; imported packages included).
    """,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".proto"],
            mandatory = True,
            doc = "Protobuf sources (paths preserved under the buf module root).",
        ),
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
        "config": attr.label(
            allow_single_file = True,
            default = Label("//:buf.yaml"),
        ),
        "lock": attr.label(
            allow_single_file = True,
            default = Label("//:buf.lock"),
        ),
        "go_mod": attr.label(
            allow_single_file = True,
            default = Label("//:go.mod"),
        ),
        "go_sum": attr.label(
            allow_single_file = True,
            default = Label("//:go.sum"),
        ),
        "_go_context_data": attr.label(
            default = "@rules_go//:go_context_data",
        ),
    },
    toolchains = [_GO_TOOLCHAIN],
)
