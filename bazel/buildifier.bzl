"""Workspace-wide buildifier: cd to the repo, skip hidden dirs."""

load("//bazel:workspace_tool.bzl", "workspace_tool_rule")

def _buildifier(*, executable = False, test = False):
    return workspace_tool_rule(
        executable = executable,
        test = test,
        tool_attr = "buildifier",
        tool_default = "//bazel/lint:buildifier",
        tool_doc = "Buildifier binary (go.mod tool).",
        flags_doc = "Extra flags passed to buildifier before discovered files.",
        doc = "bazel run: format/lint Starlark files in the workspace." if executable else "bazel test: check Starlark files in the workspace (no-sandbox).",
        find_starlark = True,
    )

buildifier_run = _buildifier(executable = True)

buildifier_test = _buildifier(test = True)
