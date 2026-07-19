//! Unary RPC request logging interceptor.

use std::time::Instant;

use connectrpc::ConnectError;
use connectrpc::async_trait;
use connectrpc::interceptor::{Interceptor, Next, UnaryRequest, UnaryResponse};
use connectrpc_health::HEALTH_SERVICE_NAME;

/// Logs procedure, protocol, peer, headers, and duration for each unary RPC.
pub struct LogInterceptor;

#[async_trait]
impl Interceptor for LogInterceptor {
    async fn intercept_unary(
        &self,
        req: UnaryRequest,
        next: Next<'_>,
    ) -> Result<UnaryResponse, ConnectError> {
        let procedure = req.ctx.path().unwrap_or("-").to_owned();
        // Match the Go server: health probes are not logged.
        if procedure.contains(HEALTH_SERVICE_NAME) {
            return next.run(req).await;
        }

        let start = Instant::now();
        let protocol = req
            .ctx
            .protocol()
            .map(|p| p.to_string())
            .unwrap_or_else(|| "-".into());
        let peer = req
            .ctx
            .peer_addr()
            .map(|a| a.to_string())
            .unwrap_or_else(|| "-".into());
        let content_type = req
            .ctx
            .header(http::header::CONTENT_TYPE)
            .and_then(|v| v.to_str().ok())
            .unwrap_or("-")
            .to_owned();
        let user_agent = req
            .ctx
            .header(http::header::USER_AGENT)
            .and_then(|v| v.to_str().ok())
            .unwrap_or("-")
            .to_owned();

        let result = next.run(req).await;
        let duration = start.elapsed();

        match &result {
            Ok(_) => {
                tracing::info!(
                    procedure = %procedure,
                    protocol = %protocol,
                    peer = %peer,
                    content_type = %content_type,
                    user_agent = %user_agent,
                    ?duration,
                    "rpc"
                );
            }
            Err(err) => {
                tracing::error!(
                    procedure = %procedure,
                    protocol = %protocol,
                    peer = %peer,
                    content_type = %content_type,
                    user_agent = %user_agent,
                    ?duration,
                    code = err.code.as_str(),
                    error = %err,
                    "rpc"
                );
            }
        }

        result
    }
}
