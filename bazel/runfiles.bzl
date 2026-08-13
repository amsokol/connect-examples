"""Runfiles path of a File for bash `_rf` (see workspace_cd.bzl)."""

def rlocation(file, workspace_name):
    """Return the runfiles-tree path for `file`.

    Args:
      file: A File (short_path is used).
      workspace_name: ctx.workspace_name of the calling rule.

    Returns:
      Path relative to the runfiles root (`workspace/short` or the
      external repo path without the leading `../`).
    """
    short = file.short_path
    if short.startswith("../"):
        return short[3:]
    return workspace_name + "/" + short
