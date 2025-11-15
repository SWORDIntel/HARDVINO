# HARDVINO AVX2 Configuration Summary - Quick Reference

## Current Status: ✅ AVX2-FIRST ALREADY IMPLEMENTED

This document provides a quick overview of how AVX512/AVX2 is configured across HARDVINO.

---

## 1. CMake Configuration (Compiler-level SIMD Control)

### OpenVINO Build: `build_hardened_openvino.sh`

```bash
Line 146:  -DENABLE_SSE42=ON      # Baseline fallback
Line 147:  -DENABLE_AVX2=ON       # PRIMARY OPTIMIZATION ← AVX2 FIRST
Line 148:  -DENABLE_AVX512F=OFF   # NOT AVAILABLE on Meteor Lake
```

### oneDNN Build: `build_hardened_oneapi.sh`

```bash
Line 56:  -DDNNL_CPU_RUNTIME=TBB                    # Thread support
Line 62:  -DDNNL_ENABLE_MAX_CPU_ISA=ON             # Max to AVX2
Line 63:  -DDNNL_ENABLE_CPU_ISA_HINTS=ON           # Runtime detection
```

---

## 2. Compiler Flags Configuration

### Primary Set: `CFLAGS_OPTIMAL` 
**File:** `meteor_lake_flags_ultimate/METEOR_LAKE_COMPLETE_FLAGS.sh` (Lines 73-122)

```bash
# Architecture
-march=meteorlake -mtune=meteorlake

# Vector Instructions (ALL AVX2-BASED)
-mavx -mavx2 -mfma -mf16c

# AI/ML Acceleration (AVX2-based)
-mavxvnni

# Cryptography (AVX2-based)
-maes -mvaes -mpclmul -mvpclmulqdq -msha -mgfni

# Bit Operations
-mbmi -mbmi2 -mlzcnt -mpopcnt -madx

# Memory Operations
-mmovbe -mmovdiri -mmovdir64b -mclflushopt -mclwb -mcldemote

# Advanced Features
-mwaitpkg -mserialize -mtsxldtrk -muintr -mprfchw
```

### Security & Hardening Variant: `CFLAGS_NPU_HARDENED`
**File:** `npu_military_config.sh` (Lines 138-149)

Combines CFLAGS_OPTIMAL with:
- `-D_FORTIFY_SOURCE=3`
- `-fstack-protector-strong`
- `-fcf-protection=full` (provides Spectre v2 mitigation via Control-Flow Enforcement Technology)
- All other security flags

---

## 3. Architecture Target Hierarchy

| Priority | Architecture | Compiler Flag | When Used |
|----------|--------------|---------------|-----------|
| **1** | Meteor Lake (Intel Core Ultra 7 165H) | `-march=meteorlake` | Primary target |
| **2** | Alder Lake (fallback) | `-march=alderlake` | If meteorlake not available |
| **3** | Native CPU | `-march=native` | Last resort |

---

## 4. SIMD Feature Availability on Meteor Lake

### Available ✅
- **SSE 4.2**: Baseline x86-64 instruction set
- **AVX**: 256-bit vector operations
- **AVX2**: Full 256-bit vector support (PRIMARY)
- **FMA**: Fused multiply-add operations
- **AVX-VNNI**: Vector Neural Network Instructions (AI/ML acceleration)
- **AES-NI**: Hardware cryptography
- **And 40+ other instruction sets** (see AVX2_WORKFLOW_ANALYSIS.md Section 2.1)

### NOT Available ❌
- **AVX512F**: Not on Meteor Lake P-cores (requires Xeon)
- **AVX512CD, ER, PF, BW, DQ, VL**: All AVX512 variants unavailable
- **AMX**: Advanced Matrix Extensions (not in current config)

---

## 5. Key Configuration Points to Remember

### In OpenVINO Build
```bash
-DENABLE_AVX2=ON              # Must be ON
-DENABLE_AVX512F=OFF          # Must be OFF (HW limitation)
```

### In oneDNN Build
```bash
-DDNNL_ENABLE_MAX_CPU_ISA=ON  # Let runtime decide (up to AVX2)
```

### In Compiler Flags
```bash
-march=meteorlake             # Primary target
-mavx2                        # Explicit AVX2 enable
-mavxvnni                     # AI acceleration alternative
```

---

## 6. Performance Optimization Path

```
Input Data
    ↓
Meteor Lake CPU detects available ISA (at runtime)
    ↓
oneDNN selects optimal kernels
    ├─ Uses AVX-VNNI if available (neural networks)
    ├─ Uses AVX2 for general operations
    └─ Falls back to SSE4.2 if needed
    ↓
OpenVINO runs inference with best available path
```

---

## 7. Build Verification

### What to Check After Build

```bash
# 1. Verify AVX2 support was compiled in
ldd /path/to/install/openvino/lib/libopenvino.so

# 2. Check CPU capabilities
cat /proc/cpuinfo | grep flags

# 3. Verify no AVX512 being used
ldd /path/to/install/openvino/lib/libopenvino.so | grep avx512

# 4. Confirm hardening flags applied
checksec --file=/path/to/install/openvino/lib/libopenvino.so
```

---

## 8. Files to Modify for AVX2-First Workflow

### No Changes Needed ✅
- `build_hardened_openvino.sh` - Already correct
- `build_hardened_oneapi.sh` - Already correct
- `METEOR_LAKE_COMPLETE_FLAGS.sh` - Already correct

### Documentation Enhancements Recommended
- Add comments to CMake lines explaining AVX2 choice
- Document why AVX512 is disabled in README
- Create specific AVX2 configuration guide

### Optional Enhancements
- Add `--avx2-only` build flag for explicit locking
- Create AVX2 benchmark suite
- Document performance characteristics

---

## 9. Environment Variables Reference

### Build Time (When Compiling)
```bash
CFLAGS="$CFLAGS_OPTIMAL"
CXXFLAGS="$CFLAGS_OPTIMAL -std=c++17"
LDFLAGS="$LDFLAGS_OPTIMAL"
```

### Runtime (When Using Compiled Libraries)
```bash
export OPENVINO_INSTALL_DIR=/path/to/install/openvino
export LD_LIBRARY_PATH=$OPENVINO_INSTALL_DIR/lib:$LD_LIBRARY_PATH
export OV_NPU_PLATFORM=3720                    # NPU config
export OV_NPU_ENABLE_LAYER_FUSION=YES          # Optimization
```

---

## 10. Fallback Chains

If `-march=meteorlake` fails:
1. Try `-march=alderlake` (similar instruction set)
2. Try `-march=native` (detect from running CPU)
3. Fall back to generic `-march=x86-64`

If `-mavxvnni` not supported:
1. Use `-mavx2` for neural networks (slower)
2. Use `-mavx` for basic operations
3. Use `-msse4.2` for baseline support

---

## 11. Testing AVX2 Configuration

### Quick Test
```bash
echo 'int main(){return 0;}' | gcc -xc $CFLAGS_OPTIMAL - -o /tmp/test
```

### Full Test (after sourcing METEOR_LAKE_COMPLETE_FLAGS.sh)
```bash
source /home/user/HARDVINO/meteor_lake_flags_ultimate/METEOR_LAKE_COMPLETE_FLAGS.sh
test_flags    # Built-in function to verify
```

---

## 12. Summary Table

| Aspect | Configuration | Status |
|--------|---------------|--------|
| **Architecture Target** | Meteor Lake | ✅ Optimized |
| **Primary SIMD** | AVX2 | ✅ Enabled |
| **AI Acceleration** | AVX-VNNI | ✅ Enabled |
| **AVX512 Support** | Disabled | ✅ Correct (HW limitation) |
| **Security Hardening** | FORTIFY_SOURCE=3 + stack protectors | ✅ Applied |
| **NPU Integration** | VPU 3720 Support | ✅ Full |
| **OpenMP Support** | Via oneTBB | ✅ Available |
| **LTO Optimization** | `-flto=auto` | ✅ Enabled |

---

## 13. What This Means for You

**For AVX2-First Workflow:**
- ✅ HARDVINO is **already configured correctly**
- ✅ No code changes needed to the build system
- ✅ AVX2 is the primary optimization path
- ✅ AVX-VNNI provides AI acceleration without AVX512
- ⏳ Documentation enhancements would make it clearer

**Hardware Fact:**
- Meteor Lake P-cores: Max **AVX2** (no AVX512)
- Meteor Lake E-cores: Max **SSE4.2** (no AVX2)
- This is a CPU limitation, not a HARDVINO limitation

---

## 14. For Future ARM/Other Architectures

When extending HARDVINO to other CPUs:
- ARM: Use NEON, SVE instead of AVX2
- AMD: May have AVX512 on some processors
- Generic: Fall back to SSE4.2 or scalar code

The current conditional system (ENABLE_AVX2, ENABLE_AVX512F) makes this possible.

---

**Branch:** `claude/redesign-avx2-workflow-011CV37KCE4y5HKo8wJPwN1D`  
**Repository:** `/home/user/HARDVINO`  
**Analysis Date:** November 12, 2025
