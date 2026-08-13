"""x86-64 microarchitecture level variants."""

# x86-64 microarchitecture level for the target platform.
# Maps to rustc's -Ctarget-cpu=x86-64-v{2,3,4}.
# See https://en.wikipedia.org/wiki/X86-64#Microarchitecture_levels
#
# v2 - CMPXCHG16B, LAHF/SAHF, POPCNT, SSE3, SSE4.1, SSE4.2, SSSE3
# v3 - AVX, AVX2, BMI1, BMI2, F16C, FMA, LZCNT, MOVBE, XSAVE
# v4 - AVX-512F/BW/CD/DQ/VL
AMD64_VARIANTS = ["v2", "v3", "v4"]
