//! Pins Buf Rust codegen plugin crates and cargo-audit in the workspace lockfile.
//!
//! Not an application crate. Direct dependencies pull `connectrpc-codegen`
//! and `protoc-gen-protovalidate-buffa` (both have libs, so Cargo keeps them)
//! plus `buffa` / `buffa-codegen` for the `protoc-gen-buffa` rust_binary
//! and `cargo-audit` for `//rust:vuln`.
