//! Connect client for the Echo service over HTTP/2 cleartext (h2c).

mod retry;

include!(concat!(env!("OUT_DIR"), "/_connectrpc.rs"));

use api::v1::{EchoRequest, EchoServiceClient};
use connectrpc::client::{ClientConfig, HttpClient};

#[tokio::main]
async fn main() {
    // Transport: HTTP/2 cleartext (h2c). Wire protocol defaults to Connect (not gRPC).
    // For HTTP/1.1 instead, use `HttpClient::plaintext()`.
    let http = HttpClient::plaintext_http2_only();
    let config = ClientConfig::new(
        "http://localhost:8080"
            .parse()
            .expect("static base URI is valid"),
    );
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
