"""Retry interceptor for transient Connect unary failures."""

from __future__ import annotations

import time
from typing import TYPE_CHECKING, TypeVar

from connectrpc.code import Code
from connectrpc.errors import ConnectError

if TYPE_CHECKING:
    from collections.abc import Callable

    from connectrpc.request import RequestContext

REQ = TypeVar("REQ")
RES = TypeVar("RES")

_MAX_RETRIES = 5
_INITIAL_BACKOFF_S = 1.0


class RetryInterceptor:
    """Retries Unavailable / ResourceExhausted and other transient errors."""

    def intercept_unary_sync(
        self,
        call_next: Callable[[REQ, RequestContext[REQ, RES]], RES],
        request: REQ,
        ctx: RequestContext[REQ, RES],
    ) -> RES:
        """Retry a unary RPC on transient failures with exponential backoff."""
        last_error: BaseException | None = None

        for attempt in range(_MAX_RETRIES):
            try:
                return call_next(request, ctx)
            except Exception as err:  # noqa: PERF203
                last_error = err
                if not _is_retryable(err) or attempt == _MAX_RETRIES - 1:
                    raise
                time.sleep(_INITIAL_BACKOFF_S * (2**attempt))

        if last_error is None:
            msg = "retry loop exited without a result or error"
            raise RuntimeError(msg)
        raise last_error


def _is_retryable(err: BaseException) -> bool:
    if isinstance(err, ConnectError):
        return err.code in (Code.UNAVAILABLE, Code.RESOURCE_EXHAUSTED)

    # Transport / dial failures (connection refused, timeouts, etc.).
    return isinstance(err, (OSError, TimeoutError, ConnectionError))
