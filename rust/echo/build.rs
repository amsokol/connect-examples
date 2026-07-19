//! Shared Connect-rust codegen for `echo-client` / `echo-server`.
//!
//! Cargo: repo root from `CARGO_MANIFEST_DIR`, `buf` on `PATH`.
//! Bazel: `CONNECT_BUF_ROOT` points at `//api/v1:module`; `BUF_BIN` is the hermetic Buf CLI.

use std::env;
use std::fs;
use std::path::{Path, PathBuf};

const PROTO_DIR: &str = "api/v1";

fn main() {
    if let Ok(buf_bin) = env::var("BUF_BIN") {
        let dir = Path::new(&buf_bin)
            .parent()
            .expect("BUF_BIN must include a directory component");
        let path = env::var("PATH").unwrap_or_default();
        let new_path = format!(
            "{}{}{}",
            dir.display(),
            if path.is_empty() { "" } else { ":" },
            path
        );
        // Build scripts are single-threaded before `compile()`.
        unsafe { env::set_var("PATH", new_path) };
    }

    let root = env::var_os("CONNECT_BUF_ROOT").map(PathBuf::from).unwrap_or_else(|| {
        // Crate lives at rust/echo/{client,server} → three levels under the repo root.
        PathBuf::from(env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR"))
            .ancestors()
            .nth(3)
            .expect("rust echo crate must live three levels under the repository root")
            .to_path_buf()
    });
    env::set_current_dir(&root).expect("chdir to buf module root");

    let mut protos: Vec<String> = fs::read_dir(root.join(PROTO_DIR))
        .unwrap_or_else(|e| panic!("read {PROTO_DIR}: {e}"))
        .filter_map(Result::ok)
        .map(|e| e.path())
        .filter(|p| p.extension().is_some_and(|ext| ext == "proto"))
        .map(|p| {
            format!(
                "{PROTO_DIR}/{}",
                p.file_name()
                    .expect("proto path has a file name")
                    .to_string_lossy()
            )
        })
        .collect();
    protos.sort();
    assert!(!protos.is_empty(), "no .proto files under {PROTO_DIR}");

    for proto in &protos {
        println!("cargo:rerun-if-changed=../../../{proto}");
    }
    println!("cargo:rerun-if-changed=../../../buf.yaml");
    println!("cargo:rerun-if-changed=../../../buf.lock");
    println!("cargo:rerun-if-env-changed=BUF_BIN");
    println!("cargo:rerun-if-env-changed=CONNECT_BUF_ROOT");

    let proto_refs: Vec<&str> = protos.iter().map(String::as_str).collect();
    connectrpc_build::Config::new()
        .use_buf()
        .files(&proto_refs)
        // Required once `connectrpc-health` enables `buffa/json` in the workspace.
        .generate_json(true)
        .include_file("_connectrpc.rs")
        .compile()
        .expect("connectrpc-build codegen failed");
}
