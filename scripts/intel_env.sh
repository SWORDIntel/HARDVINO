#!/bin/bash
# ============================================================================
# Intel Acceleration Stack Environment Configuration
# HARDVINO / DSMIL Build Environment
# ============================================================================
#
# INTEL METEOR LAKE - Core Ultra 7 165H (6P+10E cores)
# GPU: Intel Arc Graphics (Xe-LPG)
# NPU: VPU 3720
# Features: AVX2, AVX-VNNI, AES-NI, SHA
#
# Usage:
#   source scripts/intel_env.sh
#
# ============================================================================

# ============================================================================
# TOOLCHAIN (LLVM / LVMM)
# ============================================================================

export CC=clang
export CXX=clang++
export AR=llvm-ar
export NM=llvm-nm
export RANLIB=llvm-ranlib
export OBJCOPY=llvm-objcopy
export STRIP=llvm-strip
export LD=lld     # for userland; kernel via LLVM=1

# ============================================================================
# METEOR LAKE - OPTIMAL FLAGS
# Intel Core Ultra 7 165H - Full feature set
# ============================================================================

# Check if compiler supports meteorlake, fall back to alderlake
if ${CC:-clang} -march=meteorlake -E - < /dev/null > /dev/null 2>&1; then
    MARCH="meteorlake"
else
    echo "[INFO] Compiler does not support -march=meteorlake, falling back to alderlake"
    MARCH="alderlake"
fi

# SIMD/ISA extensions for Meteor Lake
METEOR_LAKE_ISA="-msse4.2 -mpopcnt -mavx -mavx2 -mfma -mf16c -mbmi -mbmi2 -mlzcnt -mmovbe"
METEOR_LAKE_VNNI="-mavxvnni"
METEOR_LAKE_CRYPTO="-maes -mvaes -mpclmul -mvpclmulqdq -msha -mgfni"
METEOR_LAKE_MISC="-madx -mclflushopt -mclwb -mcldemote -mmovdiri -mmovdir64b -mwaitpkg -mserialize -mtsxldtrk -muintr -mprefetchw -mprfchw -mrdrnd -mrdseed"

# Combined ISA flags
export METEOR_LAKE_FLAGS="${METEOR_LAKE_ISA} ${METEOR_LAKE_VNNI} ${METEOR_LAKE_CRYPTO} ${METEOR_LAKE_MISC}"

# ============================================================================
# OPTIMAL C FLAGS (copy & paste ready)
# ============================================================================

export CFLAGS_OPTIMAL="-O3 -pipe -fomit-frame-pointer -funroll-loops -fstrict-aliasing -fno-plt -fdata-sections -ffunction-sections -flto=auto -march=${MARCH} -mtune=${MARCH} ${METEOR_LAKE_FLAGS}"

export LDFLAGS_OPTIMAL="-Wl,--as-needed -Wl,--gc-sections -Wl,-O1 -Wl,--hash-style=gnu -flto=auto"

# ============================================================================
# HARDENED C FLAGS (HARDVINO default - adds security)
# ============================================================================

# Security hardening (ImageHarden-inspired)
CFLAGS_HARDENING="-fstack-protector-strong -fstack-clash-protection -fcf-protection=full -D_FORTIFY_SOURCE=3 -fPIC"

export CFLAGS="${CFLAGS_OPTIMAL} ${CFLAGS_HARDENING}"
export CXXFLAGS="${CFLAGS}"

# Full RELRO for hardened linking
export LDFLAGS="${LDFLAGS_OPTIMAL} -Wl,-z,relro -Wl,-z,now"

# ============================================================================
# KERNEL COMPILATION FLAGS
# ============================================================================

export KCFLAGS="-O3 -pipe -march=${MARCH} -mtune=${MARCH} -mavx2 -mfma -mavxvnni -maes -mvaes -mpclmul -mvpclmulqdq -msha -mgfni -falign-functions=32"
export KCPPFLAGS="${KCFLAGS}"

# Kernel build command:
# make -j$(nproc) LLVM=1 LLVM_IAS=1 CC=clang HOSTCC=clang HOSTCXX=clang++ KCFLAGS="$KCFLAGS" KCPPFLAGS="$KCFLAGS"

# ============================================================================
# BUILD SYSTEM CONFIGURATION
# ============================================================================

export MAKEFLAGS="-j$(nproc)"
export CMAKE_GENERATOR="Ninja"
export CMAKE_BUILD_TYPE="Release"
export CMAKE_C_COMPILER="${CC}"
export CMAKE_CXX_COMPILER="${CXX}"

# ============================================================================
# RUST FLAGS (for NUC2.1 etc.)
# ============================================================================

export RUSTFLAGS="-C target-cpu=native -C opt-level=3 -C lto=thin -C codegen-units=1 -C link-arg=-Wl,-O1 -C link-arg=-Wl,--as-needed"
export CARGO_BUILD_JOBS="$(nproc)"

# ============================================================================
# NPU CONFIGURATION (VPU 3720)
# ============================================================================

export OV_NPU_COMPILER_TYPE=DRIVER
export OV_NPU_PLATFORM=3720
export OV_NPU_DEVICE_ID=0x7D1D
export OV_NPU_MAX_TILES=2
export OV_NPU_DPU_GROUPS=4
export OV_NPU_DMA_ENGINES=4
export OV_NPU_POWER_MODE=MAXIMUM_PERFORMANCE
export OV_NPU_PERFORMANCE_HINT=LATENCY

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

print_intel_env() {
    echo "============================================"
    echo "HARDVINO Intel Acceleration Stack"
    echo "============================================"
    echo ""
    echo "Target: Intel Core Ultra 7 165H (Meteor Lake)"
    echo "  Arch:  ${MARCH} (6P+10E cores)"
    echo "  GPU:   Intel Arc Graphics (Xe-LPG)"
    echo "  NPU:   VPU 3720 (8086:7d1d)"
    echo ""
    echo "Toolchain:"
    echo "  CC:  ${CC}"
    echo "  CXX: ${CXX}"
    echo "  LD:  ${LD}"
    echo ""
    echo "Flags: AVX2, AVX-VNNI, AES-NI, SHA, GFNI"
    echo "Security: FORTIFY=3, CET/CFI, RELRO"
    echo ""
    echo "Build: ${CMAKE_GENERATOR} / $(nproc) jobs"
    echo "============================================"
}

verify_toolchain() {
    local missing=0
    for tool in clang clang++ lld llvm-ar; do
        if ! command -v "${tool}" &> /dev/null; then
            echo "[ERROR] Missing: ${tool}"
            missing=1
        fi
    done
    [[ $missing -eq 1 ]] && echo "[ERROR] Install: apt install clang lld llvm" && return 1
    echo "[OK] LLVM toolchain verified"
}

test_flags() {
    echo 'int main(){return 0;}' | ${CC} -xc ${CFLAGS_OPTIMAL} - -o /tmp/hardvino_test 2>/dev/null && \
        echo "[OK] Meteor Lake flags working" && rm -f /tmp/hardvino_test || \
        echo "[WARN] Some flags not supported, trying alderlake fallback"
}

export -f print_intel_env verify_toolchain test_flags

# ============================================================================
# AUTO-PRINT ON SOURCE
# ============================================================================

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "[INFO] HARDVINO environment loaded. Run 'print_intel_env' for details."
fi
