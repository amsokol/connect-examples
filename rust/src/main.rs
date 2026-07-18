//! Connect client for the Echo service over HTTP/2 cleartext (h2c).

mod retry;

include!(concat!(env!("OUT_DIR"), "/_connectrpc.rs"));

use api::v1::{EchoRequest, EchoServiceClient};
use connectrpc::client::{ClientConfig, HttpClient};
use connectrpc::Protocol;

#[tokio::main]
async fn main() {
    // Transport: HTTP/2 cleartext (h2c). Protocol: Connect (not gRPC).
    // For HTTP/1.1 instead, use `HttpClient::plaintext()`.
    // For gRPC-over-h2, use `.with_protocol(Protocol::Grpc)`.
    let http = HttpClient::plaintext_http2_only();
    let config = ClientConfig::new(
        "http://localhost:8080"
            .parse()
            .expect("static base URI is valid"),
    )
    .with_protocol(Protocol::Connect);
    let client = EchoServiceClient::new(http, config);

    let result =
        retry::with_retry(|| client.echo(EchoRequest::default().with_message("Jane"))).await;

    match result {
        Ok(res) => {
            println!("{}", res.view().message.unwrap_or_default());
        }
        Err(err) => {
            eprintln!("{err}");
            std::process::exit(1);
        }
    }
}
