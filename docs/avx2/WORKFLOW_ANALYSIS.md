# HARDVINO Codebase Analysis: AVX512/AVX2 Configuration and Build Settings

## Executive Summary

HARDVINO is a hardened OpenVINO/OneAPI build system optimized for Intel Meteor Lake (Core Ultra 7 165H) with NPU VPU 3720 support. The current configuration is **already AVX2-first** by design, with AVX512 explicitly disabled for Meteor Lake compatibility.

**Current Branch:** `claude/redesign-avx2-workflow-011CV37KCE4y5HKo8wJPwN1D`

---

## 1. CURRENT AVX512/AVX2 CONFIGURATION

### 1.1 OpenVINO Build Configuration
**File:** `/home/user/HARDVINO/build_hardened_openvino.sh` (Line 146-148)

```bash
-DENABLE_SSE42=ON
-DENABLE_AVX2=ON
-DENABLE_AVX512F=OFF
```

**Status:**
- ✅ AVX2: **ENABLED** (Full support)
- ❌ AVX512F: **DISABLED** (Explicitly turned off)
- ✅ SSE4.2: **ENABLED** (Fallback support)

### 1.2 oneDNN (Deep Neural Network Library) Configuration
**File:** `/home/user/HARDVINO/build_hardened_oneapi.sh` (Line 56-63)

```bash
-DDNNL_CPU_RUNTIME=TBB
-DDNNL_GPU_RUNTIME=NONE
-DDNNL_ENABLE_CONCURRENT_EXEC=ON
-DDNNL_ENABLE_PRIMITIVE_CACHE=ON
-DDNNL_ENABLE_MAX_CPU_ISA=ON
-DDNNL_ENABLE_CPU_ISA_HINTS=ON
```

**Status:**
- ✅ MAX_CPU_ISA: **ENABLED** (Supports up to AVX2 on Meteor Lake)
- ✅ CPU_ISA_HINTS: **ENABLED** (Runtime CPU detection)
- ✅ TBB Runtime: **ENABLED** (Parallelization framework)

### 1.3 Architecture Target
**Files:** 
- `/home/user/HARDVINO/meteor_lake_flags_ultimate/METEOR_LAKE_COMPLETE_FLAGS.sh`
- `/home/user/HARDVINO/npu_military_config.sh`

**Primary Architecture:**
```bash
-march=meteorlake -mtune=meteorlake
```

**Fallback Options:**
```bash
-march=alderlake -mtune=alderlake      # Fallback if meteorlake not available
-march=native -mtune=native             # Native CPU detection
```

---

## 2. SIMD INSTRUCTION SET CONFIGURATION

### 2.1 Enabled Instruction Sets (All in CFLAGS_OPTIMAL)
**File:** `/home/user/HARDVINO/meteor_lake_flags_ultimate/METEOR_LAKE_COMPLETE_FLAGS.sh` (Line 73-122)

#### Base Vector Instructions
```bash
-msse4.2        # SSE 4.2 (Baseline)
-mavx           # AVX (256-bit)
-mavx2          # AVX2 (256-bit, Meteor Lake native)
-mfma           # Fused Multiply-Add
-mf16c          # Float16 conversion
```

#### AI/ML Acceleration (Meteor Lake Specific)
```bash
-mavxvnni       # AVX Vector Neural Network Instructions
                # KEY: AI acceleration without AVX512
```

#### Cryptographic Acceleration
```bash
-maes           # AES-NI encryption
-mvaes          # Vector AES (AVX2-based)
-mpclmul        # Carry-less multiplication (AES-GCM)
-mvpclmulqdq    # Vector PCLMUL
-msha           # SHA1/SHA256 acceleration
-mgfni          # Galois Field NI
```

#### Bit Manipulation
```bash
-mbmi           # Bit Manipulation Instructions 1
-mbmi2          # Bit Manipulation Instructions 2
-mlzcnt         # Leading zeros count
-mpopcnt        # Population count
-madx           # Add with carry (multiplication)
```

#### Memory Operations
```bash
-mmovbe         # Move with byte swap
-mmovdiri       # Direct cache store (non-temporal)
-mmovdir64b     # 64-byte store (non-temporal)
-mclflushopt    # Cache line flush optimization
-mclwb          # Cache line writeback
-mcldemote      # Cache line demote
```

#### Control Flow & Advanced
```bash
-mwaitpkg       # Wait package (power optimization)
-mserialize     # Serialize instruction
-mtsxldtrk      # TSX load tracking
-muintr         # User-level interrupts
-mprfchw        # Prefetch for write
```

#### Security Features
```bash
-mrdrnd         # Random seed
-mrdseed        # Enhanced random seed
-mfsgsbase      # Base address for segment registers
-mfxsr          # FPU save/restore
-mxsave         # Extended save state
-mxsaveopt      # Optimized extended save
-mxsavec        # Compact extended save
-mxsaves        # Supervisor extended save
```

### 2.2 Explicitly Disabled Instructions
```bash
# NOT included (not available on Meteor Lake):
# - AVX512F (Foundation)
# - AVX512CD (Conflict Detection)
# - AVX512ER (Exponential & Reciprocal)
# - AVX512PF (Prefetch)
# - AVX512BW (Byte & Word)
# - AVX512DQ (Doubleword & Quadword)
# - AVX512VL (Vector Length)
# - AMX (Advanced Matrix eXtensions) - not in current flags
```

---

## 3. BUILD SCRIPTS & CONFIGURATION FILES

### 3.1 Main Build Scripts

#### 1. **build_all.sh** - Master Build Script
**Path:** `/home/user/HARDVINO/build_all.sh`
- **Purpose:** Orchestrates complete HARDVINO build
- **Components:** OneAPI → OpenVINO → Kernel Integration
- **Options:**
  ```bash
  --clean              # Remove previous builds
  --skip-oneapi        # Skip TBB/oneDNN
  --skip-openvino      # Skip OpenVINO
  --skip-kernel        # Skip kernel integration
  --verbose            # Verbose output
  ```

#### 2. **build_hardened_openvino.sh** - OpenVINO Build
**Path:** `/home/user/HARDVINO/build_hardened_openvino.sh`
- **Lines 98-157:** CMake configuration with hardening flags
- **Key Variables:**
  - `CMAKE_C_FLAGS` / `CMAKE_CXX_FLAGS`: Uses `${CFLAGS_NPU_HARDENED}`
  - `CMAKE_EXE_LINKER_FLAGS` / `CMAKE_SHARED_LINKER_FLAGS`: Uses `${LDFLAGS_NPU_HARDENED}`
- **Features Enabled:**
  - CPU, GPU, NPU backends
  - ONNX, PyTorch, TensorFlow, TF-Lite frontends
  - Python bindings
  - Link-Time Optimization (LTO)
  - Position Independent Code (PIC)

#### 3. **build_hardened_oneapi.sh** - OneAPI Build
**Path:** `/home/user/HARDVINO/build_hardened_oneapi.sh`
- **Builds:**
  1. oneTBB (Threading Building Blocks) - Threading framework
  2. oneDNN (Deep Neural Network Library) - SIMD-optimized DNN operations
- **Configuration:**
  - CPU-only runtime (GPU disabled)
  - Max CPU ISA detection enabled
  - Concurrent execution enabled
  - Primitive cache enabled

### 3.2 Configuration Files

#### 1. **npu_military_config.sh** - NPU Configuration
**Path:** `/home/user/HARDVINO/npu_military_config.sh`
- **Lines 18-33:** NPU optimization defines
- **Lines 39-94:** OpenVINO NPU runtime environment variables
- **Lines 123-149:** Compilation flags combining:
  - NPU military flags
  - Security hardening flags
  - FORTIFY_SOURCE=3
  - Stack protectors
  - Control-flow integrity
  - Indirect branch protection

#### 2. **METEOR_LAKE_COMPLETE_FLAGS.sh** - Compiler Flags
**Path:** `/home/user/HARDVINO/meteor_lake_flags_ultimate/METEOR_LAKE_COMPLETE_FLAGS.sh`
- **Sections:**
  1. Base optimization flags (O3, LTO, PIC)
  2. Instruction set extensions (all AVX2-compatible)
  3. Optimal flags (CFLAGS_OPTIMAL)
  4. Performance profiles (Speed, Balanced, Size, Debug)
  5. Link-time optimization
  6. Security hardening
  7. Kernel compilation flags
  8. Advanced optimization techniques
  9. Compiler-specific flags (GCC, Clang, ICC)
  10. Parallelization & threading
  11. Mathematics & numerical optimizations
  12. Memory optimization
  13. Warning flags
  14. Language-specific flags
  15. Build system exports (CMake, Autotools, Meson)
  16. Usage functions
  17. Complete environment setup
  18. Quick reference commands

### 3.3 Compiler Flags Structure

**Flag Composition Hierarchy:**
```
CFLAGS_OPTIMAL (Complete optimal set)
    ├── CFLAGS_BASE (O3, LTO, PIC, etc.)
    ├── ARCH_FLAGS (-march=meteorlake -mtune=meteorlake)
    ├── ISA_AVX (-mavx -mavx2 -mfma)
    ├── ISA_VNNI (-mavxvnni)
    ├── ISA_BMI (-mbmi -mbmi2)
    ├── ISA_CRYPTO (-maes -mvaes -mpclmul...)
    ├── ISA_MEMORY (-mmovbe -mmovdiri...)
    ├── ISA_ADVANCED (-madx -mrdrnd...)
    ├── ISA_PREFETCH (-mprfchw...)
    ├── ISA_CONTROL (-mwaitpkg -muintr...)
    └── ISA_CET (-mcet -mshstk)

CFLAGS_NPU_HARDENED (Security + NPU)
    ├── CFLAGS_NPU_MILITARY
    ├── CFLAGS_SECURITY
    ├── FORTIFY_SOURCE=3
    ├── Stack protectors
    ├── CFI protection
    ├── Indirect branch protection
    └── Additional hardening
```

---

## 4. OPENVINO & ONEAPI INTEGRATION POINTS

### 4.1 Dependency Chain

```
HARDVINO (Master)
├── oneTBB (Threading Building Blocks)
│   └── Provides: Threading, parallelization framework
│   └── Used by: oneDNN, OpenVINO
│
├── oneDNN (Deep Neural Network Library)
│   ├── Depends on: oneTBB
│   ├── Provides: CPU-optimized DNN operations with SIMD
│   ├── CPU Runtime: TBB
│   └── Features: AVX2 optimized kernels, FP16, INT8, INT4 support
│
└── OpenVINO (Open Visual Inference Engine)
    ├── Depends on: oneTBB, oneDNN, Level-Zero
    ├── Provides: Unified inference API
    ├── Backends: CPU (via oneDNN), GPU (Intel Arc), NPU (VPU 3720)
    └── Frontends: ONNX, PyTorch, TensorFlow, TF-Lite, PaddlePaddle
```

### 4.2 OpenVINO Configuration in build_hardened_openvino.sh

**Lines 119-143: Feature Enablement**
```bash
-DENABLE_INTEL_CPU=ON          # CPU backend (uses oneDNN)
-DENABLE_INTEL_GPU=ON          # GPU backend (Intel Arc)
-DENABLE_INTEL_NPU=ON          # NPU backend (VPU 3720) ← KEY
-DENABLE_AUTO=ON               # Auto device selection
-DENABLE_AUTO_BATCH=ON         # Automatic batching
-DENABLE_HETERO=ON             # Heterogeneous execution
-DENABLE_MULTI=ON              # Multi-device support
-DENABLE_OV_ONNX_FRONTEND=ON   # ONNX model support
-DENABLE_OV_PYTORCH_FRONTEND=ON
-DENABLE_OV_TF_FRONTEND=ON
-DENABLE_OV_TF_LITE_FRONTEND=ON
-DENABLE_PYTHON=ON             # Python bindings
-DENABLE_GAPI_PREPROCESSING=ON # GPU-accelerated preprocessing
```

### 4.3 NPU Integration Configuration

**File:** `/home/user/HARDVINO/npu_military_config.sh`

**NPU Specification:**
- Platform: VPU 3720 (Intel AI Boost on Meteor Lake)
- Device ID: 0x7D1D
- Neural Compute Engines: 2
- CMX Memory: 4MB (Close-to-Metal eXecution)
- DDR Bandwidth: 68 GB/s
- Frequency: 1.85 GHz (Turbo)

**OpenVINO NPU Environment Variables (Lines 39-50):**
```bash
OV_NPU_COMPILER_TYPE=DRIVER
OV_NPU_PLATFORM=3720
OV_NPU_PLATFORM_FOR_GENERATION=VPU3720
OV_NPU_DEVICE_ID=0x7D1D
OV_NPU_MAX_TILES=2
OV_NPU_DPU_GROUPS=4
OV_NPU_DMA_ENGINES=4
OV_NPU_USE_ELF_COMPILER_BACKEND=YES
OV_NPU_CREATE_EXECUTOR=1
```

**Performance Optimization (Lines 56-69):**
```bash
OV_NPU_ENABLE_LAYER_FUSION=YES
OV_NPU_ENABLE_FP16_COMPRESSION=YES
OV_NPU_ENABLE_DYNAMIC_SHAPE=YES
OV_NPU_ENABLE_BATCH_MODE=YES
OV_NPU_ENABLE_STREAM_EXECUTOR=YES
OV_NPU_ENABLE_ASYNC_EXECUTOR=YES
```

---

## 5. SECURITY HARDENING IMPLEMENTATION

### 5.1 Compile-Time Hardening Flags

**File:** `/home/user/HARDVINO/meteor_lake_flags_ultimate/METEOR_LAKE_COMPLETE_FLAGS.sh` (Lines 160-178)

```bash
CFLAGS_SECURITY="\
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
-Wl,-z,separate-code"
```

**Hardening Features:**
1. **Buffer Overflow Protection:** `_FORTIFY_SOURCE=3` (Level 3)
2. **Stack Protectors:** `-fstack-protector-strong` + `-fstack-clash-protection`
3. **Control-Flow Integrity:** `-fcf-protection=full` (CET support) - provides Spectre v2 mitigation
4. **Position Independence:** `-fpie -pie -fPIC`
5. **Memory Protection:** `-Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack -Wl,-z,separate-code`

### 5.2 Security Hardening Integration

**Applied in Multiple Places:**
1. **OpenVINO Build:** Line 105-107 in `build_hardened_openvino.sh`
2. **OneAPI Build:** Line 52-54 in `build_hardened_oneapi.sh`
3. **Kernel Integration:** Line 64 in `kernel_integration.sh`

---

## 6. KERNEL INTEGRATION

### 6.1 Kernel Configuration Export
**File:** `/home/user/HARDVINO/kernel_integration.sh`

Exports kernel-compatible configuration to `kernel_config.mk`:
- Installation paths
- Compiler flags (CFLAGS_NPU_HARDENED)
- Linker flags (LDFLAGS_NPU_HARDENED)
- Kernel-specific flags (KCFLAGS)
- NPU flags
- Include and library paths
- Link libraries

### 6.2 Kernel Compilation Flags
**File:** `/home/user/HARDVINO/meteor_lake_flags_ultimate/METEOR_LAKE_COMPLETE_FLAGS.sh` (Lines 184-212)

```bash
KCFLAGS="\
-O2 \
-pipe \
-march=meteorlake \
-mtune=meteorlake \
-msse4.2 \
-mpopcnt \
-mavx \
-mavx2 \
-mfma \
-mavxvnni \
-maes \
-mvaes \
-mpclmul \
-mvpclmulqdq \
-msha \
-mgfni \
-falign-functions=32 \
-falign-jumps=32 \
-falign-loops=32 \
-falign-labels=32"
```

**Kernel Build Integration (Recommended):**
```makefile
export HARDVINO_ROOT=/path/to/hardvino
include $(HARDVINO_ROOT)/Kbuild.mk
KBUILD_CFLAGS += $(HARDVINO_KCFLAGS)
```

---

## 7. WHERE CHANGES ARE NEEDED FOR AVX2-FIRST WORKFLOW

### 7.1 Currently AVX2-Optimized Areas (No Changes Needed)

✅ **Compiler Flags** - Already AVX2-focused
- CFLAGS_OPTIMAL includes -mavx2
- CFLAGS_BASE includes optimization for Meteor Lake
- KCFLAGS explicitly includes -mavx2

✅ **OpenVINO Configuration** - AVX512 already disabled
- `-DENABLE_AVX512F=OFF` (Line 148, build_hardened_openvino.sh)
- `-DENABLE_AVX2=ON` (Line 147, build_hardened_openvino.sh)

✅ **oneDNN Configuration** - CPU ISA hints enabled
- `-DDNNL_ENABLE_MAX_CPU_ISA=ON`
- `-DDNNL_ENABLE_CPU_ISA_HINTS=ON`
- Runtime auto-detection of CPU capabilities

### 7.2 Areas for AVX2-First Workflow Enhancement

#### A. Documentation Updates Needed

**Files to Update:**
1. **README.md** - Update architecture optimization section
2. **meteor_lake_flags_ultimate/README.md** - Emphasize AVX2-only approach
3. Create new document: **AVX2_WORKFLOW.md**

**Topics to Clarify:**
- Why AVX512 is not available on Meteor Lake (P-cores limited to AVX2)
- AVX-VNNI as AVX2 alternative for AI acceleration
- Performance characteristics of AVX2 vs AVX512 on this platform
- Fallback options for older CPUs

#### B. Configuration Variables to Standardize

**Recommendation:** Create explicit AVX2 profile variable in METEOR_LAKE_COMPLETE_FLAGS.sh

```bash
# AVX2-First Profile (Meteor Lake optimized)
export CFLAGS_AVX2_OPTIMIZED="\
-O2 \
-march=meteorlake \
-mtune=meteorlake \
-mavx2 \
-mfma \
-mavxvnni \
-maes \
-mvaes \
-mpclmul \
-mvpclmulqdq \
-msha \
-mgfni"
```

#### C. CMake Option Descriptions

**Recommendation:** Document why these are set in build_hardened_openvino.sh:

```cmake
# AVX2 is fully supported on Meteor Lake
# VNNI provides neural network acceleration without AVX512
# SSE4.2 provides baseline compatibility
-DENABLE_SSE42=ON      # Baseline for older architectures
-DENABLE_AVX2=ON       # PRIMARY: Full Meteor Lake support
-DENABLE_AVX512F=OFF   # Not available on Meteor Lake P-cores
```

#### D. Build Script Comments Enhancement

**Files to Update:**
- `build_hardened_openvino.sh` - Add comments explaining AVX2 choice
- `build_hardened_oneapi.sh` - Document CPU ISA auto-detection
- `build_all.sh` - Add option for AVX2-specific builds

#### E. Environment Variable Naming

**Recommendation:** Add clarity to flag variables:

```bash
# Current (still valid)
CFLAGS_OPTIMAL              # Best for Meteor Lake (AVX2+VNNI)
CFLAGS_NPU_HARDENED         # With security hardening

# New (for clarity)
CFLAGS_AVX2_LOCKED          # Force AVX2, disable fallback to SSE4.2
CFLAGS_AVX2_PORTABLE        # AVX2 with portable fallback
```

---

## 8. DIRECTORY STRUCTURE OVERVIEW

```
/home/user/HARDVINO/
├── README.md                                     # Main documentation
├── INITIALIZATION_STATUS.md                      # Build status
├── .gitmodules                                   # Git submodule config
├── .git/                                         # Git repository
│
├── build/                                        # Build artifacts (generated)
│   ├── openvino/                                # OpenVINO build directory
│   ├── oneapi-tbb/                              # oneTBB build directory
│   └── oneapi-dnn/                              # oneDNN build directory
│
├── install/                                      # Installation directory (generated)
│   ├── openvino/                                # Installed OpenVINO
│   ├── oneapi-tbb/                              # Installed oneTBB
│   ├── oneapi-dnn/                              # Installed oneDNN
│   └── setupvars.sh                             # Environment setup
│
├── openvino/                                     # OpenVINO submodule (717 MB)
│   └── [37 sub-submodules initialized]
│
├── oneapi-tbb/                                   # oneTBB submodule (17 MB)
├── oneapi-dnn/                                   # oneDNN submodule (74 MB)
│
├── meteor_lake_flags_ultimate/                  # Compiler flags reference
│   ├── METEOR_LAKE_COMPLETE_FLAGS.sh            # Complete flags (14.3 KB)
│   ├── README.md                                # Flags documentation (9.2 KB)
│   ├── QUICK_REFERENCE.txt                      # Quick reference
│   └── install.sh                               # Installation script
│
├── Build Scripts:
│   ├── build_all.sh                             # Master build script
│   ├── build_hardened_openvino.sh               # OpenVINO build
│   ├── build_hardened_oneapi.sh                 # OneAPI build
│   └── kernel_integration.sh                    # Kernel integration setup
│
├── Configuration Scripts:
│   ├── npu_military_config.sh                   # NPU configuration
│   └── verify.sh                                # Build verification
│
├── kernel_config.mk                              # Kernel config (generated)
├── Kbuild.mk                                     # Kernel makefile (generated)
├── KERNEL_INTEGRATION.md                         # Kernel guide (generated)
└── example_module/                               # Example kernel module (generated)
```

---

## 9. KEY FINDINGS & RECOMMENDATIONS

### 9.1 Current AVX2-First Implementation Status

**Status:** ✅ **ALREADY OPTIMIZED FOR AVX2**

The codebase is already designed with AVX2 as the primary target:
1. AVX512F is explicitly disabled
2. AVX2 is enabled
3. AVX-VNNI (AVX2-based) is used for AI acceleration
4. Meteor Lake architecture is primary target
5. Fallback options exist for older CPUs

### 9.2 Why AVX512 is Not Available

**Hardware Limitation:** Meteor Lake's P-cores (Performance cores) are limited to AVX2
- AVX512 is NOT implemented on Meteor Lake P-cores
- AVX512 only appears on Xeon Scalable and some HPC platforms
- Meteor Lake E-cores (Efficiency cores) don't support AVX2

### 9.3 Recommended Actions

#### Immediate (Documentation):
1. Create `AVX2_WORKFLOW.md` explaining design decisions
2. Update build script comments to clarify AVX2 focus
3. Document AVX-VNNI as primary AI acceleration method

#### Short-term (Enhancement):
1. Add `--avx2-only` flag to build scripts for explicit locking
2. Create CMake option for AVX2-first behavior
3. Add build verification to confirm AVX2 features

#### Medium-term (Testing):
1. Create AVX2 benchmark suite
2. Document performance characteristics
3. Test fallback paths (SSE4.2)

#### Long-term (Flexibility):
1. Support for older CPUs with degraded performance
2. Optional AMX (Advanced Matrix Extensions) if kernel supports
3. Conditional NPU support for non-Meteor Lake systems

---

## 10. QUICK REFERENCE

### 10.1 Key Files for AVX2/SIMD Configuration

| File | Purpose | Key Lines |
|------|---------|-----------|
| `build_hardened_openvino.sh` | OpenVINO build | 146-148 (AVX config) |
| `build_hardened_oneapi.sh` | oneDNN/TBB build | 56-63 (ISA config) |
| `METEOR_LAKE_COMPLETE_FLAGS.sh` | Compiler flags | 73-122 (CFLAGS_OPTIMAL) |
| `npu_military_config.sh` | NPU configuration | 123-149 (Hardened flags) |
| `kernel_integration.sh` | Kernel integration | 64-71 (Kernel flags) |

### 10.2 Key CMake Variables for SIMD

| Variable | Current Value | Impact |
|----------|---------------|--------|
| `ENABLE_SSE42` | ON | Baseline x86-64 support |
| `ENABLE_AVX2` | ON | Primary optimization |
| `ENABLE_AVX512F` | OFF | Meteor Lake doesn't have it |
| `DDNNL_ENABLE_MAX_CPU_ISA` | ON | Auto-detect at runtime |
| `DDNNL_ENABLE_CPU_ISA_HINTS` | ON | Use CPU hints for optimization |

### 10.3 Key Compiler Flags for AVX2

| Flag | Purpose | Status |
|------|---------|--------|
| `-mavx2` | AVX2 instructions | ✅ Enabled |
| `-mfma` | Fused Multiply-Add | ✅ Enabled |
| `-mavxvnni` | Vector Neural Networks | ✅ Enabled |
| `-march=meteorlake` | CPU-specific tuning | ✅ Enabled |
| `-O2` | Optimization level | ✅ Enabled |
| `-flto=auto` | Link-Time Optimization | ✅ Enabled |

---

## 11. OPTIMIZATION HIERARCHY

```
CPU: Intel Core Ultra 7 165H (Meteor Lake)
│
├─ AVX-VNNI (Neural Network Instructions, AVX2-based)
│  └─ Best for: AI/ML inference, neural networks
│
├─ AVX2 (256-bit vector, full support)
│  └─ Best for: General SIMD operations
│
├─ SSE4.2 (128-bit vector, fallback)
│  └─ Best for: Legacy compatibility
│
└─ Scalar operations (fallback)
   └─ Best for: Unsupported operations
```

---

## Summary

HARDVINO is a well-designed, hardened build system already optimized for AVX2-first workflow on Meteor Lake. The codebase explicitly disables AVX512 (which isn't available on this platform) and focuses on:

1. **AVX2** - Primary vectorization
2. **AVX-VNNI** - AI/ML acceleration
3. **Security Hardening** - Military-grade protections
4. **NPU Support** - Dedicated hardware acceleration

The current implementation needs **documentation enhancements** rather than code changes to clearly communicate the AVX2-first design philosophy.

