"""AArch64 ISA version variants."""

# AArch64 ISA version for the target platform.
# Maps to rustc's -Ctarget-feature=+v{8.1a,...,9.6a}.
# See https://en.wikipedia.org/wiki/AArch64#ARMv8-A
#
# v8_1a  - LSE atomics, VHE, PAN, RDMA
# v8_2a  - FP16, cache clean to PoP, PAN enhancements  (e.g., Graviton 2, Ampere Altra)
# v8_3a  - pointer authentication, JS conversion, complex numbers
# v8_4a  - nested virtualization, flag manipulation, RCPC2  (e.g., Graviton 3, Neoverse V1)
# v8_5a  - speculation barrier, BTI, random number generation
# v8_6a  - BFloat16, matrix multiplication, fine-grained traps
# v8_7a  - WFxT, HCRX_EL2, XS attribute, LS64
# v8_8a  - NMI, HINTED conditional branches, MOPS memcpy/memset
# v8_9a  - RCPC3, RAS v2, translation hardening
# v9a    - SVE2 baseline, MTE, BTI  (e.g., Graviton 4, Neoverse V2)
# v9_1a  - builds on v8.6a + SVE2
# v9_2a  - builds on v8.7a + SVE2
# v9_3a  - builds on v8.8a + SVE2
# v9_4a  - GCS, 128-bit atomics, 128-bit page tables
# v9_5a  - CPA, PAC enhancements, FP8
# v9_6a  - SVE2.2, SME2.2, compare-and-branch
ARM64_VARIANTS = [
    "v8_1a",
    "v8_2a",
    "v8_3a",
    "v8_4a",
    "v8_5a",
    "v8_6a",
    "v8_7a",
    "v8_8a",
    "v8_9a",
    "v9a",
    "v9_1a",
    "v9_2a",
    "v9_3a",
    "v9_4a",
    "v9_5a",
    "v9_6a",
]
