use std::env;
use std::path::PathBuf;

fn main() {
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let repo_root = manifest_dir
        .ancestors()
        .nth(2)
        .expect("rust/server crate must live two levels under the repository root");

    // `buf build` resolves imports via the repo-root `buf.yaml`.
    env::set_current_dir(repo_root).expect("chdir to repository root");

    println!("cargo:rerun-if-changed=../../api/v1/echo.proto");
    println!("cargo:rerun-if-changed=../../buf.yaml");
    println!("cargo:rerun-if-changed=../../buf.lock");

    connectrpc_build::Config::new()
        .use_buf()
        .files(&["api/v1/echo.proto"])
        // Required once `connectrpc-health` enables `buffa/json` in the workspace.
        .generate_json(true)
        .include_file("_connectrpc.rs")
        .compile()
        .expect("connectrpc-build codegen failed");
}
