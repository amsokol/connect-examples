//! Retry transient Connect unary failures with exponential backoff.

use std::future::Future;
use std::time::Duration;

use connectrpc::{ConnectError, ErrorCode};
use tokio::time::sleep;

const MAX_RETRIES: u32 = 5;
const INITIAL_BACKOFF: Duration = Duration::from_secs(1);

/// Run `f` up to [`MAX_RETRIES`] times, backing off 1s, 2s, 4s, 8s between attempts.
pub async fn with_retry<T, F, Fut>(mut f: F) -> Result<T, ConnectError>
where
    F: FnMut() -> Fut,
    Fut: Future<Output = Result<T, ConnectError>>,
{
    let mut last: Option<ConnectError> = None;

    for attempt in 0..MAX_RETRIES {
        match f().await {
            Ok(value) => return Ok(value),
            Err(err) => {
                if !is_retryable(&err) || attempt + 1 == MAX_RETRIES {
                    return Err(err);
                }
                last = Some(err);
                sleep(INITIAL_BACKOFF * 2u32.pow(attempt)).await;
            }
        }
    }

    Err(last.expect("retry loop exited without a result or error"))
}

fn is_retryable(err: &ConnectError) -> bool {
    matches!(
        err.code,
        ErrorCode::Unavailable | ErrorCode::ResourceExhausted
    )
}
