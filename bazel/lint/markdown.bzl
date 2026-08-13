"""Workspace markdownlint-cli2: cd to the repo, run against config globs."""

load("//bazel:workspace_tool.bzl", "workspace_tool_rule")

markdownlint_test = workspace_tool_rule(
    test = True,
    tool_attr = "markdownlint",
    tool_default = "//bazel/lint:markdownlint-cli2",
    tool_doc = "markdownlint-cli2 js_binary from @npm.",
    flags_doc = "markdownlint-cli2 arguments (empty uses .markdownlint-cli2.yaml globs).",
    doc = "bazel test: markdownlint-cli2 against the workspace (no-sandbox).",
    pre_exec = """\
export BAZEL_BINDIR="${BAZEL_BINDIR:-.}"
export JS_BINARY__CHDIR="$PWD"
""",
)
