"""Locate the source workspace for lint/vuln wrappers.

`bazel run` sets BUILD_WORKSPACE_DIRECTORY. `bazel test` does not. Runfiles
may contain a copy of MODULE.bazel (processwrapper) rather than a symlink, so
dirname(realpath(marker)) is not the checkout. execroot/_main is Bazel's source
overlay and has go.mod / go / … as symlinks into the repo.

These snippets are concatenated into scripts (not str.format'd): bash ${var}
is written as-is.
"""

# pip-audit / cargo-audit only need runfile lookup (they cd next to the lock).
RUNFILES_BASH = """\
_rf() {
  local path=$1
  if [[ -n "${RUNFILES_DIR:-}" && -e "${RUNFILES_DIR}/${path}" ]]; then
    realpath -- "${RUNFILES_DIR}/${path}"
    return
  fi
  if [[ -e "$0.runfiles/${path}" ]]; then
    realpath -- "$0.runfiles/${path}"
    return
  fi
  echo "unable to locate runfile: ${path}" >&2
  exit 1
}
"""

# Shared by govulncheck, golangci-lint, ruff, markdownlint, buildifier.
WORKSPACE_BASH = RUNFILES_BASH + """
_workspace_dir() {
  local marker=$1
  if [[ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
    printf '%s\\n' "${BUILD_WORKSPACE_DIRECTORY}"
    return
  fi
  local dir
  dir=$(dirname "$marker")
  if [[ -f "$dir/go.mod" ]]; then
    printf '%s\\n' "$dir"
    return
  fi
  local p="${TEST_SRCDIR:-}"
  while [[ -n "$p" && "$p" != "/" ]]; do
    if [[ "$(basename "$p")" == "bazel-out" ]]; then
      dir=$(dirname "$p")
      if [[ -f "$dir/go.mod" ]]; then
        printf '%s\\n' "$dir"
        return
      fi
    fi
    p=$(dirname "$p")
  done
  echo "unable to locate workspace root (go.mod). marker=$marker TEST_SRCDIR=${TEST_SRCDIR:-}" >&2
  exit 1
}
"""
