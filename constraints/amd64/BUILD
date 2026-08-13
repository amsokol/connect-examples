load("//constraints/amd64:defs.bzl", "AMD64_VARIANTS")

package(default_visibility = ["//visibility:public"])

constraint_setting(
    name = "amd64",
)

[
    constraint_value(
        name = v,
        constraint_setting = ":amd64",
    )
    for v in AMD64_VARIANTS
]
