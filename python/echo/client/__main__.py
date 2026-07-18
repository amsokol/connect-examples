"""Connect client for the Echo service."""

from __future__ import annotations

import logging
import sys

from connectrpc.errors import ConnectError

from python.api.v1.echo_connect import EchoServiceClientSync
from python.api.v1.echo_pb import EchoRequest
from python.echo.client.retry import RetryInterceptor

logging.basicConfig(level=logging.INFO, format="%(message)s")
log = logging.getLogger(__name__)


def main() -> int:
    """Call EchoService.Echo and print the response."""
    with EchoServiceClientSync(
        "http://localhost:8080",
        interceptors=[RetryInterceptor()],
    ) as client:
        try:
            res = client.echo(EchoRequest(message="Jane"))
        except (ConnectError, OSError, TimeoutError, ConnectionError):
            log.exception("echo RPC failed")
            return 1

    log.info("%s", res.message)
    return 0


if __name__ == "__main__":
    sys.exit(main())
