# HARDVINO AVX2/SIMD Configuration - Code Reference

Complete code snippets showing how AVX512/AVX2 is configured throughout the codebase.

---

## 1. OpenVINO CMake Configuration

**File:** `/home/user/HARDVINO/build_hardened_openvino.sh` (Lines 98-157)

### Complete CMake Invocation
```bash
cmake "${OPENVINO_DIR}" \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}/openvino" \
    -DCMAKE_C_COMPILER=gcc \
    -DCMAKE_CXX_COMPILER=g++ \
    -DCMAKE_C_FLAGS="${CMAKE_C_FLAGS}" \
    -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS}" \
    -DCMAKE_EXE_LINKER_FLAGS="${CMAKE_EXE_LINKER_FLAGS}" \
    -DCMAKE_SHARED_LINKER_FLAGS="${CMAKE_EXE_LINKER_FLAGS}" \
    
    # CPU/GPU/NPU Backends
    -DENABLE_INTEL_CPU=ON \
    -DENABLE_INTEL_GPU=ON \
    -DENABLE_INTEL_NPU=ON \
    
    # Model Format Support
    -DENABLE_OV_ONNX_FRONTEND=ON \
    -DENABLE_OV_PYTORCH_FRONTEND=ON \
    -DENABLE_OV_TF_FRONTEND=ON \
    -DENABLE_OV_TF_LITE_FRONTEND=ON \
    
    # ============================================
    # SIMD CONFIGURATION (AVX2-FIRST)
    # ============================================
    
    # Line 146: Baseline support
    -DENABLE_SSE42=ON \
    
    # Line 147: PRIMARY OPTIMIZATION TARGET
    -DENABLE_AVX2=ON \
    
    # Line 148: DISABLED (not available on Meteor Lake)
    -DENABLE_AVX512F=OFF \
    
    # ============================================
    # Optimization Flags
    # ============================================
    
    -DENABLE_FASTER_BUILD=ON \
    -DENABLE_LTO=ON \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_VISIBILITY_INLINES_HIDDEN=ON \
    
    # Threading Framework
    -DTHREADING=TBB \
    -DENABLE_TBBBIND_2_5=ON \
    -DTBB_DIR="${INSTALL_PREFIX}/oneapi-tbb/lib/cmake/TBB"
```

### Key Lines Explained

```cmake
-DENABLE_SSE42=ON
  # Purpose: Enable SSE4.2 as fallback path
  # Rationale: Ensures compatibility with older CPUs
  # Performance: Slower than AVX2
  # Used when: AVX2 not available
  # Status: ✅ ENABLED (as fallback only)

-DENABLE_AVX2=ON
  # Purpose: Enable AVX2 (256-bit vectors)
  # Rationale: Meteor Lake P-cores fully support AVX2
  # Performance: Primary optimization path
  # Used when: Modern CPU detected
  # Status: ✅ ENABLED (PRIMARY)

-DENABLE_AVX512F=OFF
  # Purpose: Disable AVX512 Foundation extension
  # Rationale: NOT available on Meteor Lake P-cores
  # Performance: Would fail at runtime on this CPU
  # Hardware: Only on Xeon Scalable processors
  # Status: ✅ DISABLED (correct for target platform)
```

---

## 2. oneDNN CMake Configuration

**File:** `/home/user/HARDVINO/build_hardened_oneapi.sh` (Lines 41-72)

### Complete oneDNN Build Configuration
```bash
cmake "${SCRIPT_DIR}/oneapi-dnn" \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}/oneapi-dnn" \
    -DCMAKE_C_FLAGS="${CFLAGS_NPU_HARDENED}" \
    -DCMAKE_CXX_FLAGS="${CFLAGS_NPU_HARDENED} -std=c++17" \
    -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS_NPU_HARDENED}" \
    -DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS_NPU_HARDENED}" \
    
    # ============================================
    # CPU ISA CONFIGURATION
    # ============================================
    
    # Line 56: Threading Runtime
    -DDNNL_CPU_RUNTIME=TBB \
    
    # Lines 62-63: ISA DETECTION & OPTIMIZATION
    -DDNNL_ENABLE_MAX_CPU_ISA=ON \
    -DDNNL_ENABLE_CPU_ISA_HINTS=ON \
    
    # ============================================
    # Build Options
    # ============================================
    
    -DDNNL_GPU_RUNTIME=NONE \
    -DDNNL_BUILD_TESTS=OFF \
    -DDNNL_BUILD_EXAMPLES=OFF \
    -DDNNL_ENABLE_CONCURRENT_EXEC=ON \
    -DDNNL_ENABLE_PRIMITIVE_CACHE=ON \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DTBB_DIR="${INSTALL_PREFIX}/oneapi-tbb/lib/cmake/TBB"
```

### Key Lines Explained

```cmake
-DDNNL_ENABLE_MAX_CPU_ISA=ON
  # Purpose: Enable maximum CPU ISA extensions
  # What it does: Tells oneDNN to use best available SIMD
  # On Meteor Lake: Will use up to AVX2
  # Mechanism: Runtime CPU detection
  # Status: ✅ ENABLED

-DDNNL_ENABLE_CPU_ISA_HINTS=ON
  # Purpose: Allow runtime hints for ISA selection
  # What it does: Respects CPU hints at runtime
  # Fallback path: Automatically selects lower ISA if needed
  # Used for: Dynamic kernel selection
  # Status: ✅ ENABLED
```

---

## 3. Compiler Flags Configuration

**File:** `/home/user/HARDVINO/meteor_lake_flags_ultimate/METEOR_LAKE_COMPLETE_FLAGS.sh` (Lines 73-122)

### Complete CFLAGS_OPTIMAL

```bash
export CFLAGS_OPTIMAL="\
-O3 \
-pipe \
-fomit-frame-pointer \
-funroll-loops \
-fstrict-aliasing \
-fno-plt \
-fdata-sections \
-ffunction-sections \
-flto=auto \
-fuse-linker-plugin \

# ============================================
# ARCHITECTURE TARGETING
# ============================================

-march=meteorlake \
-mtune=meteorlake \

# ============================================
# VECTOR INSTRUCTIONS (ALL AVX2 COMPATIBLE)
# ============================================

# Baseline SSE
-msse4.2 \

# Main Vector Extensions (256-bit)
-mpopcnt \
-mavx \
-mavx2 \
-mfma \
-mf16c \

# ============================================
# AI/ML ACCELERATION (AVX2-BASED)
# ============================================

# Vector Neural Network Instructions
-mavxvnni \

# ============================================
# CRYPTOGRAPHY (AVX2-BASED)
# ============================================

-maes \
-mvaes \
-mpclmul \
-mvpclmulqdq \
-msha \
-mgfni \

# ============================================
# BIT MANIPULATION
# ============================================

-mbmi \
-mbmi2 \
-mlzcnt \
-madx \

# ============================================
# MEMORY OPERATIONS
# ============================================

-mclflushopt \
-mclwb \
-mcldemote \
-mmovdiri \
-mmovdir64b \

# ============================================
# ADVANCED FEATURES
# ============================================

-mwaitpkg \
-mserialize \
-mtsxldtrk \
-muintr \
-mprefetchw \
-mprfchw \

# ============================================
# SECURITY & MISC
# ============================================

-mrdrnd \
-mrdseed \
-mfsgsbase \
-mfxsr \
-mxsave \
-mxsaveopt \
-mxsavec \
-mxsaves"
```

### Security Variant: CFLAGS_NPU_HARDENED

**File:** `/home/user/HARDVINO/npu_military_config.sh` (Lines 138-149)

```bash
export CFLAGS_NPU_HARDENED="$CFLAGS_NPU_MILITARY \
    $CFLAGS_SECURITY \
    -D_FORTIFY_SOURCE=3 \
    -fstack-protector-strong \
    -fstack-clash-protection \
    -fcf-protection=full \
    -mindirect-branch=thunk \
    -mfunction-return=thunk \
    -mindirect-branch-register \
    -fno-delete-null-pointer-checks \
    -fno-strict-overflow \
    -fwrapv"
```

Where:
- `$CFLAGS_NPU_MILITARY`: NPU-specific optimization flags
- `$CFLAGS_SECURITY`: Security hardening flags (see below)
- Additional security enhancements for kernel integration

### Security Hardening Flags

**File:** `/home/user/HARDVINO/meteor_lake_flags_ultimate/METEOR_LAKE_COMPLETE_FLAGS.sh` (Lines 160-178)

```bash
export CFLAGS_SECURITY="\
-D_FORTIFY_SOURCE=3 \
-fstack-protector-strong \
-fstack-clash-protection \
-fcf-protection=full \
-fpie \
-fPIC \
-Wformat \
-Wformat-security \
-Werror=format-security \
-Wl,-z,relro \
-Wl,-z,now \
-Wl,-z,noexecstack \
-Wl,-z,separate-code \
-mindirect-branch=thunk \
-mfunction-return=thunk \
-mindirect-branch-register"
```

---

## 4. Kernel Compilation Flags

**File:** `/home/user/HARDVINO/meteor_lake_flags_ultimate/METEOR_LAKE_COMPLETE_FLAGS.sh` (Lines 184-204)

### KCFLAGS for Kernel Build

```bash
export KCFLAGS="\
-O3 \
-pipe \
-march=meteorlake \
-mtune=meteorlake \

# ============================================
# KERNEL-SPECIFIC SIMD
# ============================================

-msse4.2 \
-mpopcnt \
-mavx \
-mavx2 \
-mfma \
-mavxvnni \

# Cryptography acceleration
-maes \
-mvaes \
-mpclmul \
-mvpclmulqdq \
-msha \
-mgfni \

# ============================================
# KERNEL-SPECIFIC ALIGNMENT
# ============================================

-falign-functions=32 \
-falign-jumps=32 \
-falign-loops=32 \
-falign-labels=32"

export KCPPFLAGS="$KCFLAGS"
```

---

## 5. NPU Configuration Integration

**File:** `/home/user/HARDVINO/npu_military_config.sh` (Lines 18-149)

### NPU Optimization Flags

```bash
export NPU_MILITARY_FLAGS="\
    -DNPU_OVERDRIVE=1 \
    -DVPU37XX_FIRMWARE_OVERRIDE=1 \
    -DINTEL_NPU_PLATFORM=VPU3720 \
    -DNPU_MAX_POWER_MODE=UNRESTRICTED \
    -DNPU_THERMAL_THROTTLE_DISABLE=1 \
    -DENABLE_NPU_KERNEL_BYPASS=1 \
    -DNPU_DIRECT_MEMORY_ACCESS=1 \
    -DVPU_FREQUENCY_BOOST=1850 \
    -DNPU_WORKLOAD_PRIORITY=REALTIME \
    -DENABLE_NPU_MULTI_STREAM=16 \
    -DNPU_BATCH_SIZE_OVERRIDE=256 \
    -DENABLE_NPU_FP8_EXPERIMENTAL=1 \
    -DENABLE_NPU_INT4_QUANTIZATION=1 \
    -DNPU_ASYNC_INFER_QUEUE=64 \
    -DNPU_MEMORY_POOL_SIZE=2048MB"
```

### Combined Military + Hardening Flags

```bash
export CFLAGS_NPU_MILITARY="$CFLAGS_OPTIMAL \
    $NPU_MILITARY_FLAGS \
    -DINTEL_NPU_WORKAROUNDS=1 \
    -DVPU_COMPILER_WORKAROUNDS=1 \
    -DNPU_2_NEURAL_COMPUTE_ENGINES=1 \
    -DENABLE_VPU_COUNTER_BASED_SCHEDULING=1 \
    -DENABLE_DMA_DESCRIPTOR_CACHE=1 \
    -DENABLE_CMX_SLICING=1 \
    -DENABLE_KERNEL_CACHING=1 \
    -DNPU_L2_CACHE_SIZE=2621440 \
    -DNPU_SRAM_SIZE=4194304 \
    -DVPU_NN_FREQUENCY=1850000000 \
    -DVPU_COSIM_MODE=0"

# Then add security hardening
export CFLAGS_NPU_HARDENED="$CFLAGS_NPU_MILITARY \
    $CFLAGS_SECURITY"
```

---

## 6. Kernel Integration Export

**File:** `/home/user/HARDVINO/kernel_integration.sh` (Lines 45-100)

### Kernel Configuration Export to kernel_config.mk

```bash
cat > "${config_file}" << EOF
# Installation paths
HARDVINO_ROOT := ${SCRIPT_DIR}
HARDVINO_INSTALL := ${INSTALL_PREFIX}
OPENVINO_ROOT := \$(HARDVINO_INSTALL)/openvino
ONETBB_ROOT := \$(HARDVINO_INSTALL)/oneapi-tbb
ONEDNN_ROOT := \$(HARDVINO_INSTALL)/oneapi-dnn

# ============================================
# COMPILER FLAGS (with SIMD & hardening)
# ============================================

# C Flags: SIMD + NPU + Hardening
HARDVINO_CFLAGS := ${CFLAGS_NPU_HARDENED}

# Linker flags: Hardening + optimization
HARDVINO_LDFLAGS := ${LDFLAGS_NPU_HARDENED}

# ============================================
# KERNEL-SPECIFIC FLAGS (with SIMD)
# ============================================

# Kernel compilation flags: Meteor Lake AVX2 + hardening
HARDVINO_KCFLAGS := ${KCFLAGS}

# NPU optimization flags
HARDVINO_NPU_FLAGS := ${NPU_MILITARY_FLAGS}

# ============================================
# LIBRARY & INCLUDE PATHS
# ============================================

HARDVINO_INCLUDES := -I\$(OPENVINO_ROOT)/runtime/include \
                     -I\$(ONETBB_ROOT)/include \
                     -I\$(ONEDNN_ROOT)/include

HARDVINO_LIBDIRS := -L\$(OPENVINO_ROOT)/runtime/lib/intel64 \
                    -L\$(OPENVINO_ROOT)/lib \
                    -L\$(ONETBB_ROOT)/lib \
                    -L\$(ONEDNN_ROOT)/lib

HARDVINO_LIBS := -lopenvino -lopenvino_c -ltbb -ldnnl

# Export all variables for kernel use
export HARDVINO_ROOT
export HARDVINO_CFLAGS
export HARDVINO_LDFLAGS
export HARDVINO_KCFLAGS
export HARDVINO_INCLUDES
export HARDVINO_LIBDIRS
export HARDVINO_LIBS
