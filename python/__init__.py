"""Python package root for generated stubs and the Echo client."""

from __future__ import annotations

import sys
from pathlib import Path


def _register_generated_wkt() -> None:
    """Load pip ``google.protobuf``, then add generated ``go_features_pb2``.

    ``python/gen`` is on ``sys.path`` for ``buf.validate``, so it must be
    removed before importing ``google`` or it would shadow the pip package.
    """
    gen = Path(__file__).resolve().parent / "gen"
    gen_resolved = gen.resolve()
    removed: list[str] = []
    kept: list[str] = []
    for entry in sys.path:
        try:
            if Path(entry).resolve() == gen_resolved:
                removed.append(entry)
                continue
        except OSError:
            pass
        kept.append(entry)
    sys.path[:] = kept

    import google.protobuf  # noqa: PLC0415

    sys.path.extend(removed)

    wkt = gen / "google" / "protobuf"
    if wkt.is_dir():
        path = str(wkt)
        if path not in google.protobuf.__path__:
            google.protobuf.__path__.append(path)


_register_generated_wkt()
