load("//constraints/arm64:defs.bzl", "ARM64_VARIANTS")

package(default_visibility = ["//visibility:public"])

constraint_setting(
    name = "arm64",
)

[
    constraint_value(
        name = v,
        constraint_setting = ":arm64",
    )
    for v in ARM64_VARIANTS
]
