load("@rules_rust//rust:defs.bzl", "rust_binary")

rust_binary(
    name = "protoc-gen-buffa",
    srcs = glob(["src/**/*.rs"]),
    crate_root = "src/main.rs",
    edition = "2021",
    visibility = ["//visibility:public"],
    deps = [
        "@cargo//:buffa",
        "@cargo//:buffa-codegen",
    ],
)
