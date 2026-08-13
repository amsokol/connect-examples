"""Workspace govulncheck: cd to the repo, run on ./go/..."""

load("//bazel:workspace_tool.bzl", "workspace_tool_rule")

govulncheck_test = workspace_tool_rule(
    test = True,
    tool_attr = "govulncheck",
    tool_default = "//bazel/vuln:govulncheck",
    tool_doc = "govulncheck binary (go.mod tool).",
    flags_doc = "govulncheck arguments after the binary (e.g. ./go/...).",
    doc = "bazel test: govulncheck against the workspace (no-sandbox, needs vuln.go.dev).",
    use_go_sdk = True,
)
