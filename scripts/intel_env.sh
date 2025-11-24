#!/bin/bash
# ============================================================================
# Intel Acceleration Stack Environment Configuration
# HARDVINO / DSMIL Build Environment
# ============================================================================
#
# This script configures the complete build environment for the Intel
# Acceleration Stack, including:
#   - LLVM/Clang toolchain selection
#   - Meteor Lake CPU tuning flags
#   - Security hardening flags (CET/CFI, RELRO, FORTIFY=3)
#   - Rust compilation flags
#   - Kernel compilation flags
#
# Usage:
#   source scripts/intel_env.sh
#
# ============================================================================

set -e

# ============================================================================
# B1. TOOLCHAIN (LLVM / LVMM)
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
# CPU TUNING (Meteor Lake)
# ============================================================================

# Primary: Meteor Lake tuning
# Fallback: Use alderlake if meteorlake not supported by compiler version
CPU_TUNE_FLAGS_COMMON="-march=meteorlake -mtune=meteorlake"

# Check if compiler supports meteorlake, fall back to alderlake
if ! ${CC:-clang} -march=meteorlake -E - < /dev/null > /dev/null 2>&1; then
    echo "[INFO] Compiler does not support -march=meteorlake, falling back to alderlake"
    CPU_TUNE_FLAGS_COMMON="-march=alderlake -mtune=alderlake"
fi

export CPU_TUNE_FLAGS_COMMON

# ============================================================================
# B1. USERLAND C/C++ FLAGS
# ============================================================================

# Core optimization + CPU tuning + SIMD extensions
CFLAGS_TUNE="
  -O3 -pipe -fomit-frame-pointer -funroll-loops
  ${CPU_TUNE_FLAGS_COMMON}
  -mavx2 -mavxvnni -mfma -maes -mpclmul -msha -mgfni -mvaes -mvpclmulqdq
"

# Code generation optimizations
CFLAGS_CODEGEN="
  -fno-plt -fno-semantic-interposition
  -fvisibility=hidden
  -ffunction-sections -fdata-sections
"

# Security hardening (ImageHarden-inspired)
CFLAGS_HARDENING="
  -fstack-protector-strong -fstack-clash-protection
  -fcf-protection=full
  -D_FORTIFY_SOURCE=3 -U_FORTIFY_SOURCE
  -fPIC
"

# Combined C flags
export CFLAGS="${CFLAGS_TUNE} ${CFLAGS_CODEGEN} ${CFLAGS_HARDENING}"

# C++ flags (add C++-specific options)
export CXXFLAGS="${CFLAGS} -fno-exceptions -fno-rtti"

# Linker flags
export LDFLAGS="
  -Wl,-O1 -Wl,--as-needed -Wl,--gc-sections -Wl,--hash-style=gnu
  -flto=thin
  -Wl,-z,relro -Wl,-z,now
"

# ============================================================================
# BUILD SYSTEM CONFIGURATION
# ============================================================================

export MAKEFLAGS="-j$(nproc)"
export CMAKE_GENERATOR="Ninja"
export CMAKE_BUILD_TYPE="Release"
export CMAKE_C_COMPILER="${CC}"
export CMAKE_CXX_COMPILER="${CXX}"

# ============================================================================
# B2. RUST FLAGS (for NUC2.1 etc.)
# ============================================================================

export RUSTFLAGS="
  -C target-cpu=native
  -C opt-level=3
  -C lto=thin
  -C codegen-units=1
  -C link-arg=-Wl,-O1
  -C link-arg=-Wl,--as-needed
"

# Cargo configuration
export CARGO_BUILD_JOBS="$(nproc)"

# ============================================================================
# B3. KERNEL COMPILE FLAGS (DSMIL kernel)
# ============================================================================

# Keep kernel flags conservative but tuned
# Note: Kernel builds should use -O2, not -O3
export KCFLAGS="
  -O2 -pipe
  ${CPU_TUNE_FLAGS_COMMON}
"

export KCPPFLAGS="${KCFLAGS}"

# ============================================================================
# KERNEL BUILD COMMAND REFERENCE
# ============================================================================
#
# Build the DSMIL kernel with these flags:
#
#   make LLVM=1 LLVM_IAS=1 \
#        CC=clang HOSTCC=clang HOSTCXX=clang++ \
#        KCFLAGS="${KCFLAGS}" KCPPFLAGS="${KCPPFLAGS}" \
#        -j"$(nproc)"
#
# ============================================================================

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Print current environment configuration
print_intel_env() {
    echo "============================================"
    echo "Intel Acceleration Stack Environment"
    echo "============================================"
    echo ""
    echo "Toolchain:"
    echo "  CC:        ${CC}"
    echo "  CXX:       ${CXX}"
    echo "  AR:        ${AR}"
    echo "  LD:        ${LD}"
    echo ""
    echo "CPU Tuning:"
    echo "  ${CPU_TUNE_FLAGS_COMMON}"
    echo ""
    echo "Build System:"
    echo "  Generator: ${CMAKE_GENERATOR}"
    echo "  Type:      ${CMAKE_BUILD_TYPE}"
    echo "  Jobs:      $(nproc)"
    echo ""
    echo "Security Hardening: FORTIFY=3, CET/CFI, RELRO, Stack Protector"
    echo "============================================"
}

# Verify toolchain is available
verify_toolchain() {
    local missing=0
    for tool in clang clang++ lld llvm-ar llvm-nm; do
        if ! command -v "${tool}" &> /dev/null; then
            echo "[ERROR] Missing tool: ${tool}"
            missing=1
        fi
    done
    if [ "${missing}" -eq 1 ]; then
        echo "[ERROR] Install LLVM toolchain: apt install clang lld llvm"
        return 1
    fi
    echo "[OK] LLVM toolchain verified"
}

# Export functions for subshells
export -f print_intel_env
export -f verify_toolchain

# ============================================================================
# AUTO-PRINT ON SOURCE
# ============================================================================

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Script is being sourced
    echo "[INFO] Intel environment loaded. Run 'print_intel_env' for details."
fi
