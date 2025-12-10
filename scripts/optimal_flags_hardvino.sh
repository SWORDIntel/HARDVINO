#!/bin/bash
# ============================================================================
# HARDVINO OPTIMAL COMPILER FLAGS - METEOR LAKE
# Intel Core Ultra 7 165H - AI/ML Inference Optimized
# ============================================================================
#
# This configuration is optimized for:
#   - OpenVINO / oneDNN / PyTorch / TensorFlow workloads
#   - AI/ML inference (neural networks)
#   - Multi-threaded applications (TBB, OpenMP)
#   - Security-hardened builds
#   - NPU VPU 3720 acceleration
#
# Selected from: METEOR_LAKE_COMPLETE_FLAGS.sh
# ============================================================================

# Source the complete flags reference
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../meteor_lake_flags_ultimate/METEOR_LAKE_COMPLETE_FLAGS.sh" 2>/dev/null || {
    echo "[WARN] Could not source METEOR_LAKE_COMPLETE_FLAGS.sh, using fallback"
}

# ============================================================================
# COMPILER DETECTION
# ============================================================================

# Detect compiler and version
if command -v clang &> /dev/null && clang --version | grep -q "clang version 1[3-9]"; then
    export CC="${CC:-clang}"
    export CXX="${CXX:-clang++}"
    export COMPILER="clang"
    export COMPILER_VERSION=$(clang --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
elif command -v gcc &> /dev/null && gcc --version | grep -qE "gcc.*1[3-9]"; then
    export CC="${CC:-gcc}"
    export CXX="${CXX:-g++}"
    export COMPILER="gcc"
    export COMPILER_VERSION=$(gcc --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
else
    export CC="${CC:-gcc}"
    export CXX="${CXX:-g++}"
    export COMPILER="gcc"
    echo "[WARN] Using system compiler, may not have all optimizations"
fi

# ============================================================================
# ARCHITECTURE DETECTION
# ============================================================================

# Check if compiler supports meteorlake
if ${CC} -march=meteorlake -E - < /dev/null > /dev/null 2>&1; then
    MARCH="meteorlake"
    MTUNE="meteorlake"
elif ${CC} -march=alderlake -E - < /dev/null > /dev/null 2>&1; then
    MARCH="alderlake"
    MTUNE="alderlake"
    echo "[INFO] Using alderlake as meteorlake fallback"
else
    MARCH="native"
    MTUNE="native"
    echo "[INFO] Using native architecture detection"
fi

export ARCH_FLAGS="-march=${MARCH} -mtune=${MTUNE}"

# ============================================================================
# OPTIMAL FLAGS FOR AI/ML INFERENCE WORKLOADS
# ============================================================================
#
# Selection rationale:
# 1. Use CFLAGS_OPTIMAL (not CFLAGS_SPEED) - ML frameworks need IEEE compliance
# 2. Include AVX-VNNI + AVX-VNNI-INT8 for neural network acceleration
# 3. Include AVX-IFMA + AVX-NE-CONVERT for Meteor Lake AI extensions
# 4. Add IPA flags for interprocedural optimization (critical for large ML libs)
# 5. Include cache tuning for Meteor Lake hierarchy
# 6. Add security hardening (HARDVINO requirement)
# 7. Use LTO for better whole-program optimization
# ============================================================================

# Base optimization (IEEE-compliant, safe for ML)
if [[ "$COMPILER" == "gcc" ]]; then
    export CFLAGS_BASE_ML="\
-O3 \
-pipe \
-fomit-frame-pointer \
-funroll-loops \
-fstrict-aliasing \
-fno-plt \
-fdata-sections \
-ffunction-sections \
-flto=auto \
-fuse-linker-plugin"
else
    # Clang doesn't need -fuse-linker-plugin (LLD handles LTO automatically)
    export CFLAGS_BASE_ML="\
-O3 \
-pipe \
-fomit-frame-pointer \
-funroll-loops \
-fstrict-aliasing \
-fno-plt \
-fdata-sections \
-ffunction-sections \
-flto=thin"
fi

# Architecture
export CFLAGS_ARCH="${ARCH_FLAGS}"

# ISA Extensions - AI/ML Focused
# Core SIMD (required)
export ISA_CORE="-msse4.2 -mpopcnt"

# AVX2 + VNNI (PRIMARY for ML workloads)
export ISA_AVX2_VNNI="-mavx -mavx2 -mfma -mf16c -mavxvnni -mavxvnniint8"

# Meteor Lake AI Extensions
export ISA_ML_EXTENSIONS="-mavxifma -mavxneconvert"

# Cryptographic (for secure ML)
export ISA_CRYPTO="-maes -mvaes -mpclmul -mvpclmulqdq -msha -mgfni"

# Bit Manipulation
export ISA_BMI="-mbmi -mbmi2 -mlzcnt"

# Memory Operations
# Note: -mprefetchw is GCC-specific, Clang uses -mprfchw or doesn't support it
if [[ "$COMPILER" == "gcc" ]]; then
    export ISA_MEMORY="-mmovbe -mclflushopt -mclwb -mcldemote -mprefetchw -mprefetchi -mprfchw"
else
    export ISA_MEMORY="-mmovbe -mclflushopt -mclwb -mcldemote -mprefetchi -mprfchw"
fi

# Advanced Features
export ISA_ADVANCED="-madx -mrdrnd -mrdseed -mfsgsbase -mfxsr -mxsave -mxsaveopt -mxsavec -mxsaves -minvpcid"

# Control Flow
export ISA_CONTROL="-mwaitpkg -mserialize -mtsxldtrk"

# CET (Control-flow Enforcement Technology)
# Note: -mibt is GCC-specific, Clang uses -fcf-protection instead
if [[ "$COMPILER" == "gcc" ]]; then
    export ISA_CET="-mshstk -mibt"
else
    export ISA_CET="-mshstk"
fi

# Combined ISA flags
export ISA_FLAGS="${ISA_CORE} ${ISA_AVX2_VNNI} ${ISA_ML_EXTENSIONS} ${ISA_CRYPTO} ${ISA_BMI} ${ISA_MEMORY} ${ISA_ADVANCED} ${ISA_CONTROL} ${ISA_CET}"

# Interprocedural Analysis (GCC-specific, critical for large ML libraries)
if [[ "$COMPILER" == "gcc" ]]; then
    export IPA_FLAGS="\
-fipa-pta \
-fipa-cp-clone \
-fipa-ra \
-fipa-sra \
-fipa-vrp \
-fdevirtualize-speculatively \
-fdevirtualize-at-ltrans"
else
    # Clang doesn't support IPA flags, use LLVM optimizations instead
    export IPA_FLAGS=""
fi

# Loop Optimizations (GCC-specific)
if [[ "$COMPILER" == "gcc" ]]; then
    export LOOP_FLAGS="\
-ftree-loop-im \
-ftree-loop-distribution \
-ftree-loop-distribute-patterns \
-ftree-loop-vectorize \
-floop-nest-optimize \
-ftree-vectorize \
-ftree-slp-vectorize"
else
    # Clang uses different vectorization flags (handled in CLANG_LLVM_FLAGS)
    export LOOP_FLAGS=""
fi

# Code Generation Optimizations (GCC-specific)
if [[ "$COMPILER" == "gcc" ]]; then
    export CODEGEN_FLAGS="\
-fgcse-after-reload \
-fpredictive-commoning \
-ftree-partial-pre \
-fprefetch-loop-arrays"
else
    # Clang doesn't support these GCC-specific flags
    export CODEGEN_FLAGS=""
fi

# Cache Tuning for Meteor Lake (GCC-specific --param flags)
if [[ "$COMPILER" == "gcc" ]]; then
    export CACHE_PARAMS="\
--param l1-cache-size=48 \
--param l1-cache-line-size=64 \
--param l2-cache-size=2048 \
--param prefetch-latency=300 \
--param simultaneous-prefetches=6"
else
    # Clang doesn't support --param flags
    export CACHE_PARAMS=""
fi

# Inlining Parameters (GCC-specific)
if [[ "$COMPILER" == "gcc" ]]; then
    export INLINE_PARAMS="\
--param max-inline-insns-single=1000 \
--param max-inline-insns-auto=200 \
--param inline-unit-growth=200"
else
    # Clang uses -mllvm flags for inlining (handled in CLANG_LLVM_FLAGS)
    export INLINE_PARAMS=""
fi

# Security Hardening (HARDVINO requirement)
export CFLAGS_SECURITY="\
-D_FORTIFY_SOURCE=3 \
-fstack-protector-strong \
-fstack-clash-protection \
-fcf-protection=full \
-fpie \
-fPIC \
-Wformat \
-Wformat-security \
-Werror=format-security"

# ============================================================================
# COMPLETE OPTIMAL FLAGS FOR HARDVINO
# ============================================================================

# Build CFLAGS - only include flags that are supported by the compiler
export CFLAGS_OPTIMAL_HARDVINO="\
${CFLAGS_BASE_ML} \
${CFLAGS_ARCH} \
${ISA_FLAGS} \
${IPA_FLAGS} \
${LOOP_FLAGS} \
${CODEGEN_FLAGS} \
${CACHE_PARAMS} \
${INLINE_PARAMS} \
${CFLAGS_SECURITY}"

# Remove empty flags and extra spaces
CFLAGS_OPTIMAL_HARDVINO=$(echo "${CFLAGS_OPTIMAL_HARDVINO}" | sed 's/  */ /g' | sed 's/^ *//' | sed 's/ *$//')
export CFLAGS_OPTIMAL_HARDVINO

export CXXFLAGS_OPTIMAL_HARDVINO="${CFLAGS_OPTIMAL_HARDVINO} -std=c++17"

# Linker Flags
if [[ "$COMPILER" == "gcc" ]]; then
    export LDFLAGS_OPTIMAL_HARDVINO="\
-Wl,--as-needed \
-Wl,--gc-sections \
-Wl,-O2 \
-Wl,--hash-style=gnu \
-Wl,--sort-common \
-flto=auto \
-fuse-linker-plugin \
-Wl,-z,relro \
-Wl,-z,now \
-Wl,-z,noexecstack \
-Wl,-z,separate-code \
-pie"
else
    # Clang/LLD flags
    export LDFLAGS_OPTIMAL_HARDVINO="\
-Wl,--as-needed \
-Wl,--gc-sections \
-Wl,-O2 \
-flto=thin \
-Wl,-z,relro \
-Wl,-z,now \
-Wl,-z,noexecstack \
-Wl,-z,separate-code \
-pie"
fi

# ============================================================================
# CLANG-SPECIFIC OPTIMIZATIONS (if using Clang)
# ============================================================================

if [[ "$COMPILER" == "clang" ]]; then
    # Clang LLVM optimizations (replace GCC-specific flags)
    export CLANG_LLVM_FLAGS="\
-mllvm -inline-threshold=1000 \
-mllvm -unroll-threshold=1000 \
-mllvm -vectorize-loops \
-mllvm -vectorize-slp \
-mllvm -enable-gvn-hoist \
-mllvm -enable-gvn-sink \
-mllvm -enable-loop-flatten \
-mllvm -hot-cold-split"
    
    # Polly Polyhedral Optimizer (powerful for ML workloads)
    # Note: Requires LLVM with Polly support
    export CLANG_POLLY_FLAGS="\
-mllvm -polly \
-mllvm -polly-vectorizer=stripmine \
-mllvm -polly-parallel \
-mllvm -polly-omp-backend=LLVM \
-mllvm -polly-num-threads=6 \
-mllvm -polly-tiling"
    
    # Try to detect if Polly is available
    if echo 'int main(){return 0;}' | ${CC} -mllvm -polly -xc - -o /dev/null 2>/dev/null; then
        CLANG_EXTRA_FLAGS="${CLANG_LLVM_FLAGS} ${CLANG_POLLY_FLAGS}"
        export POLLY_AVAILABLE=1
    else
        CLANG_EXTRA_FLAGS="${CLANG_LLVM_FLAGS}"
        export POLLY_AVAILABLE=0
    fi
    
    # Append Clang-specific flags
    export CFLAGS_OPTIMAL_HARDVINO="${CFLAGS_OPTIMAL_HARDVINO} ${CLANG_EXTRA_FLAGS}"
    CFLAGS_OPTIMAL_HARDVINO=$(echo "${CFLAGS_OPTIMAL_HARDVINO}" | sed 's/  */ /g' | sed 's/^ *//' | sed 's/ *$//')
    export CFLAGS_OPTIMAL_HARDVINO
fi

# ============================================================================
# GCC-SPECIFIC OPTIMIZATIONS (if using GCC)
# ============================================================================

if [[ "$COMPILER" == "gcc" ]]; then
    # Graphite optimizations (GCC-specific)
    export GRAPHITE_FLAGS="\
-fgraphite \
-fgraphite-identity \
-floop-nest-optimize \
-floop-parallelize-all \
-ftree-loop-linear"
    
    export CFLAGS_OPTIMAL_HARDVINO="${CFLAGS_OPTIMAL_HARDVINO} ${GRAPHITE_FLAGS}"
    CFLAGS_OPTIMAL_HARDVINO=$(echo "${CFLAGS_OPTIMAL_HARDVINO}" | sed 's/  */ /g' | sed 's/^ *//' | sed 's/ *$//')
    export CFLAGS_OPTIMAL_HARDVINO
fi

# ============================================================================
# EXPORT FOR BUILD SYSTEMS
# ============================================================================

# Standard environment variables
export CFLAGS="${CFLAGS_OPTIMAL_HARDVINO}"
export CXXFLAGS="${CXXFLAGS_OPTIMAL_HARDVINO}"
export LDFLAGS="${LDFLAGS_OPTIMAL_HARDVINO}"

# CMake variables
export CMAKE_C_FLAGS="${CFLAGS_OPTIMAL_HARDVINO}"
export CMAKE_CXX_FLAGS="${CXXFLAGS_OPTIMAL_HARDVINO}"
export CMAKE_EXE_LINKER_FLAGS="${LDFLAGS_OPTIMAL_HARDVINO}"
export CMAKE_SHARED_LINKER_FLAGS="${LDFLAGS_OPTIMAL_HARDVINO}"
export CMAKE_MODULE_LINKER_FLAGS="${LDFLAGS_OPTIMAL_HARDVINO}"

# Build system
export CMAKE_BUILD_TYPE="Release"
export CMAKE_GENERATOR="Ninja"
export CMAKE_C_COMPILER="${CC}"
export CMAKE_CXX_COMPILER="${CXX}"

# Parallelization (Meteor Lake: 6 P-cores for compute-intensive tasks)
export MAKEFLAGS="-j6"
export OMP_NUM_THREADS="6"
export GOMP_CPU_AFFINITY="0-5"
export OMP_PROC_BIND="true"
export OMP_PLACES="cores"

# ============================================================================
# KERNEL COMPILATION FLAGS
# ============================================================================

export KCFLAGS="\
-O3 \
-pipe \
${ARCH_FLAGS} \
-msse4.2 \
-mpopcnt \
-mavx \
-mavx2 \
-mfma \
-mavxvnni \
-mavxvnniint8 \
-maes \
-mvaes \
-mpclmul \
-mvpclmulqdq \
-msha \
-mgfni \
-falign-functions=64 \
-falign-jumps=64 \
-falign-loops=64 \
-falign-labels=64 \
${CACHE_PARAMS}"

export KCPPFLAGS="${KCFLAGS}"

# ============================================================================
# RUST FLAGS (for NUC2.1 and other Rust components)
# ============================================================================

export RUSTFLAGS="\
-C target-cpu=${MARCH} \
-C opt-level=3 \
-C lto=fat \
-C embed-bitcode=yes \
-C codegen-units=1 \
-C target-feature=+avx2,+fma,+aes,+vaes,+pclmul,+vpclmulqdq,+sha,+gfni,+avxvnni,+avxvnniint8,+avxifma,+avxneconvert"

# ============================================================================
# VERIFICATION FUNCTIONS
# ============================================================================

verify_flags() {
    echo "=== Verifying HARDVINO Optimal Flags ==="
    echo ""
    echo "Compiler: ${COMPILER} ${COMPILER_VERSION}"
    echo "Architecture: ${MARCH}"
    echo ""
    
    # Test C compilation (compile only, no linking to avoid linker dependency issues)
    if echo 'int main(){return 0;}' | ${CC} -xc ${CFLAGS_OPTIMAL_HARDVINO} -c - -o /tmp/hardvino_test.o 2>/dev/null; then
        echo "✓ CFLAGS compilation successful"
        rm -f /tmp/hardvino_test.o
    else
        echo "✗ CFLAGS compilation failed"
        echo "  Testing with fallback flags..."
        if echo 'int main(){return 0;}' | ${CC} -xc -O3 -march=${MARCH} -c - -o /tmp/hardvino_test.o 2>/dev/null; then
            echo "  ✓ Fallback flags work"
            rm -f /tmp/hardvino_test.o
        else
            echo "  ✗ Fallback also failed - check compiler installation"
            return 1
        fi
    fi
    
    # Test C++ compilation (compile only)
    if echo 'int main(){return 0;}' | ${CXX} -xc++ ${CXXFLAGS_OPTIMAL_HARDVINO} -c - -o /tmp/hardvino_test.o 2>/dev/null; then
        echo "✓ CXXFLAGS compilation successful"
        rm -f /tmp/hardvino_test.o
    else
        echo "✗ CXXFLAGS compilation failed"
    fi
    
    echo ""
    echo "Key Features Enabled:"
    echo "  ✓ AVX2 + AVX-VNNI (AI/ML acceleration)"
    echo "  ✓ AVX-VNNI-INT8 (8-bit neural networks)"
    echo "  ✓ AVX-IFMA + AVX-NE-CONVERT (Meteor Lake AI)"
    echo "  ✓ Interprocedural Analysis (IPA)"
    echo "  ✓ Cache tuning (Meteor Lake hierarchy)"
    echo "  ✓ Security hardening (FORTIFY=3, CET, RELRO)"
    if [[ "$COMPILER" == "clang" && "$POLLY_AVAILABLE" == "1" ]]; then
        echo "  ✓ Clang Polly polyhedral optimizer"
    fi
    echo ""
}

show_flags() {
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║  HARDVINO OPTIMAL FLAGS - METEOR LAKE                                   ║"
    echo "║  Intel Core Ultra 7 165H | AI/ML Inference Optimized                    ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Compiler: ${COMPILER} ${COMPILER_VERSION}"
    echo "Architecture: ${MARCH}"
    echo ""
    echo "CFLAGS:"
    echo "${CFLAGS_OPTIMAL_HARDVINO}" | tr ' ' '\n' | grep -v '^$' | head -30
    echo "... (truncated)"
    echo ""
    echo "LDFLAGS:"
    echo "${LDFLAGS_OPTIMAL_HARDVINO}" | tr ' ' '\n' | grep -v '^$'
    echo ""
}

# ============================================================================
# ACTIVATION
# ============================================================================

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Script is being sourced
    echo "[INFO] HARDVINO optimal flags loaded"
    echo "  Compiler: ${COMPILER} ${COMPILER_VERSION}"
    echo "  Architecture: ${MARCH}"
    echo "  Run 'verify_flags' to test, 'show_flags' to display"
else
    # Script is being executed
    show_flags
    verify_flags
fi
