"""Workspace golangci-lint: cd to the repo, run on ./go/..."""

load("//bazel:workspace_tool.bzl", "workspace_tool_rule")

golangci_test = workspace_tool_rule(
    test = True,
    tool_attr = "golangci",
    tool_default = "//bazel/lint:golangci-lint",
    tool_doc = "golangci-lint binary (go.mod tool).",
    flags_doc = "golangci-lint arguments after the binary (e.g. run ./go/...).",
    doc = "bazel test: golangci-lint against the workspace (no-sandbox).",
    use_go_sdk = True,
)
