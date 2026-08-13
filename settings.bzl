"""
Module of global project settings.
"""

load("//constraints/amd64:defs.bzl", "AMD64_VARIANTS")
load("//constraints/arm64:defs.bzl", "ARM64_VARIANTS")

# Target platforms keyed by arch (linux + optional microarch constraints).
PLATFORMS_PER_ARCH = dict(
    [
        ("arm64", "//:linux-aarch64"),
        ("amd64", "//:linux-x86_64"),
    ] +
    [("arm64_%s" % v, "//:linux-aarch64-%s" % v) for v in ARM64_VARIANTS] +
    [("amd64_%s" % v, "//:linux-x86_64-%s" % v) for v in AMD64_VARIANTS],
)

_BUILD_FLAGS_DEBUG = [
    "-Copt-level=0",
]

_BUILD_FLAGS_RELEASE = [
    "-Clink-arg=-flto",
    "-Clink-arg=-s",
    "-Ccodegen-units=1",
    "-Cpanic=abort",
    "-Copt-level=3",
    "-Cstrip=symbols",
]

# Selects the right -Ctarget-cpu for x86-64 microarchitecture levels.
# Falls back to no flag (baseline x86-64) when no constraint is set.
_AMD64_MICROARCH_FLAGS = select(dict(
    [("//:amd64_%s" % v, ["-Ctarget-cpu=x86-64-%s" % v]) for v in AMD64_VARIANTS] +
    [("//conditions:default", [])],
))

# Selects the right -Ctarget-feature for AArch64 ISA versions.
# Falls back to no flag (baseline ARMv8.0-A) when no constraint is set.
_ARM64_MICROARCH_FLAGS = select(dict(
    [("//:arm64_%s" % v, ["-Ctarget-feature=+%s" % v.replace("_", ".")]) for v in ARM64_VARIANTS] +
    [("//conditions:default", [])],
))

RUST_BUILD_FLAGS = select({
    "//:optimized": _BUILD_FLAGS_RELEASE,
    "//conditions:default": _BUILD_FLAGS_DEBUG,
})

# For a single rust_binary under platform transitions (image_index / multiarch).
# Microarch flags activate when the target platform carries the matching constraint.
RUST_MULTIARCH_BUILD_FLAGS = RUST_BUILD_FLAGS + _AMD64_MICROARCH_FLAGS + _ARM64_MICROARCH_FLAGS

RUST_BUILD_FLAGS_PER_ARCH = dict(
    [
        ("arm64", RUST_BUILD_FLAGS),
        ("amd64", RUST_BUILD_FLAGS),
    ] +
    [("arm64_%s" % v, RUST_BUILD_FLAGS + _ARM64_MICROARCH_FLAGS) for v in ARM64_VARIANTS] +
    [("amd64_%s" % v, RUST_BUILD_FLAGS + _AMD64_MICROARCH_FLAGS) for v in AMD64_VARIANTS],
)

RUST_BINARY_ARCHS = [
    "arm64",
    # "arm64_v8_1a",
    # "arm64_v8_2a",
    # "arm64_v8_3a",
    # "arm64_v8_4a",
    # "arm64_v8_5a",
    # "arm64_v8_6a",
    # "arm64_v8_7a",
    # "arm64_v8_8a",
    # "arm64_v8_9a",
    # "arm64_v9a",
    # "arm64_v9_1a",
    # "arm64_v9_2a",
    # "arm64_v9_3a",
    # "arm64_v9_4a",
    # "arm64_v9_5a",
    # "arm64_v9_6a",
    # "amd64",
    # "amd64_v2",
    "amd64_v3",
    # "amd64_v4",
]

# rules_go: linux/arm64 plus GOAMD64 v1–v4. No GOARM64 ISA variants.
GO_BINARY_ARCHS = [
    "arm64",
    # "amd64",
    # "amd64_v2",
    "amd64_v3",
    # "amd64_v4",
]
