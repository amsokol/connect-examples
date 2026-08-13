"""Put Bazel's Go SDK on PATH for wrappers that exec `go`.

govulncheck and golangci-lint shell out to `go env` / `go list`. The SDK is
the one `go_sdk.from_file` already downloaded from go.mod — not host `go`.

GO_SDK_BASH is concatenated into scripts (not str.format'd): bash ${var} is
written as-is.
"""

GO_TOOLCHAIN_TYPE = "@rules_go//go:toolchain"

GO_SDK_BASH = """\
_export_goroot() {
  local go_bin
  go_bin=$(realpath -- "$1")
  export GOROOT="$(dirname "$(dirname "$go_bin")")"
  export PATH="$GOROOT/bin:${PATH:-}"
  export GOTOOLCHAIN=local
  if [[ ! -x "$GOROOT/bin/go" ]]; then
    echo "hermetic go is not executable: $GOROOT/bin/go (from $1)" >&2
    exit 1
  fi
}
"""

def go_sdk(ctx):
    """Return the GoSDK from the resolved rules_go toolchain.

    Args:
      ctx: Rule context that requested GO_TOOLCHAIN_TYPE.

    Returns:
      The toolchain's GoSDK provider (bin/go, GOROOT files, tools).
    """
    toolchain = ctx.toolchains[GO_TOOLCHAIN_TYPE]
    sdk = toolchain.sdk
    if not sdk or not sdk.go:
        fail("{}: Go toolchain has no SDK go binary".format(ctx.label))
    return sdk

def go_sdk_runfiles(ctx, sdk):
    """Runfiles for a usable GOROOT (bin/go plus stdlib and tools).

    Args:
      ctx: Rule context used to build the runfiles tree.
      sdk: GoSDK from go_sdk(ctx).

    Returns:
      Runfiles containing the SDK layout govulncheck/golangci-lint need.
    """
    return ctx.runfiles(
        files = [sdk.go, sdk.root_file],
        transitive_files = depset(transitive = [
            sdk.headers,
            sdk.libs,
            sdk.srcs,
            sdk.tools,
        ]),
    )
