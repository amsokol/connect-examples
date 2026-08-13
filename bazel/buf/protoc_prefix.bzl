"""Unix-layout prefix from the resolved proto toolchain's protoc.

Never depend on @protobuf//:protoc — that cc_binary compiles protoc from source.
Protobuf 33.4+ registers a GitHub prebuilt on
@protobuf//bazel/private:proto_toolchain_type when prefer_prebuilt_protoc is
true (the default).
"""

_PROTO_TOOLCHAIN_TYPE = "@protobuf//bazel/private:proto_toolchain_type"

def _protoc_prefix_impl(ctx):
    toolchain = ctx.toolchains[_PROTO_TOOLCHAIN_TYPE]
    if not toolchain:
        fail("{}: no proto toolchain registered".format(ctx.label))
    compiler = toolchain.proto.proto_compiler
    protoc = compiler.executable
    if not protoc:
        fail("{}: proto toolchain has no proto_compiler".format(ctx.label))

    out = ctx.actions.declare_directory(ctx.label.name)
    copies = [
        'cp "{}" "$OUT/include/google/protobuf/{}"'.format(src.path, src.basename)
        for src in ctx.files.wkts
    ]
    ctx.actions.run_shell(
        outputs = [out],
        inputs = depset(direct = [protoc] + ctx.files.wkts),
        tools = [compiler],
        command = "\n".join([
            "set -euo pipefail",
            'OUT="{}"'.format(out.path),
            'mkdir -p "$OUT/bin" "$OUT/include/google/protobuf"',
            'cp "{}" "$OUT/bin/protoc"'.format(protoc.path),
            "chmod +x \"$OUT/bin/protoc\"",
        ] + copies),
        mnemonic = "ProtocPrefix",
        progress_message = "Staging prebuilt protoc prefix %{label}",
    )
    return [DefaultInfo(files = depset([out]))]

protoc_prefix = rule(
    implementation = _protoc_prefix_impl,
    attrs = {
        "wkts": attr.label_list(
            allow_files = [".proto"],
            mandatory = True,
            doc = "google.protobuf WKT .proto files (filegroups, not compiled C++).",
        ),
    },
    toolchains = [_PROTO_TOOLCHAIN_TYPE],
)
