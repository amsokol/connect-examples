//! Connect Echo service server over HTTP/1.1 and h2c.

mod log;

include!(concat!(env!("OUT_DIR"), "/_connectrpc.rs"));

use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;

use api::v1::{ECHO_SERVICE_SERVICE_NAME, EchoRequest, EchoResponse, EchoService, EchoServiceExt};
use connectrpc::{
    ConnectError, ConnectRpcService, RequestContext, Response, Router, Server, ServiceRequest,
    ServiceResult,
};
use connectrpc_health::install_static;
use log::LogInterceptor;
use tracing_subscriber::EnvFilter;

/// Echo service implementation.
struct EchoServer;

impl EchoService for EchoServer {
    #[allow(refining_impl_trait_internal)]
    async fn echo(
        &self,
        _ctx: RequestContext,
        request: ServiceRequest<'_, EchoRequest>,
    ) -> ServiceResult<EchoResponse> {
        let message = request.message.unwrap_or("");
        if message.is_empty() {
            return Err(ConnectError::invalid_argument(
                "message is required and must be non-empty",
            ));
        }

        Response::ok(EchoResponse::default().with_message(format!("Hello, {message}!")))
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into()))
        .init();

    let addr: SocketAddr = "127.0.0.1:8080".parse()?;

    // grpc.health.v1 for Kubernetes gRPC probes / grpc_health_probe.
    let (router, _health) = install_static(Router::new(), [ECHO_SERVICE_SERVICE_NAME]);
    let router = Arc::new(EchoServer).register(router);
    let service = ConnectRpcService::new(router).with_interceptor(LogInterceptor);

    // Match the Go server: HTTP/1.1 + h2c, 10s header read timeout.
    Server::from_service(service)
        .with_header_read_timeout(Some(Duration::from_secs(10)))
        .serve(addr)
        .await?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use buffa::Message as _;
    use bytes::Bytes;
    use connectrpc::HasMessageView as _;

    #[tokio::test]
    async fn echo_greets_message() {
        let body = Bytes::from(EchoRequest::default().with_message("Jane").encode_to_vec());
        let view = EchoRequest::decode_view(&body).expect("decode request");
        let req = ServiceRequest::<EchoRequest>::from_parts(&view, &body);

        let res = EchoServer
            .echo(RequestContext::new(Default::default()), req)
            .await
            .expect("echo succeeds");

        assert_eq!(res.body.message.as_deref(), Some("Hello, Jane!"));
    }

    #[tokio::test]
    async fn echo_rejects_empty_message() {
        let body = Bytes::from(EchoRequest::default().encode_to_vec());
        let view = EchoRequest::decode_view(&body).expect("decode request");
        let req = ServiceRequest::<EchoRequest>::from_parts(&view, &body);

        let Err(err) = EchoServer
            .echo(RequestContext::new(Default::default()), req)
            .await
        else {
            panic!("empty message should be invalid");
        };

        assert_eq!(err.code, connectrpc::ErrorCode::InvalidArgument);
    }
}
