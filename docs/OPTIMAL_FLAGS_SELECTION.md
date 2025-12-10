# HARDVINO Optimal Flags Selection Guide

## Overview

This document explains the optimal compiler flags selected for HARDVINO builds on Intel Meteor Lake (Core Ultra 7 165H).

## Workload Characteristics

HARDVINO builds AI/ML inference frameworks:
- **OpenVINO** - Neural network inference runtime
- **oneDNN** - Deep Neural Network Library (BLAS/DNN kernels)
- **PyTorch / TensorFlow** - ML frameworks
- **Multi-threaded** - Uses TBB, OpenMP for parallelization
- **Security-hardened** - Military-grade hardening required
- **NPU acceleration** - VPU 3720 support

## Flag Selection Rationale

### 1. Optimization Level: `-O3` (not `-Ofast`)

**Selected**: `CFLAGS_OPTIMAL` (uses `-O3`)

**Why**: ML frameworks require IEEE 754 floating-point compliance. `-Ofast` enables `-ffast-math` which breaks IEEE compliance and can cause numerical instability in neural networks.

**Trade-off**: Slightly slower than `-Ofast`, but maintains numerical correctness critical for ML workloads.

### 2. AI/ML Acceleration Extensions

**Selected**: 
- `-mavxvnni` - AVX-VNNI (INT8 VNNI on AVX2 width)
- `-mavxvnniint8` - AVX-VNNI-INT8 (8-bit neural networks)
- `-mavxifma` - AVX-IFMA (Integer Fused Multiply-Add)
- `-mavxneconvert` - AVX-NE-CONVERT (Neural Engine Convert)

**Why**: These are Meteor Lake's primary AI acceleration instructions. AVX-VNNI provides INT8 quantization support critical for efficient neural network inference.

**Performance Impact**: 2-4x speedup for quantized INT8 models vs FP32.

### 3. Interprocedural Analysis (IPA)

**Selected**: Full IPA suite
- `-fipa-pta` - Points-to analysis
- `-fipa-cp-clone` - Constant propagation cloning
- `-fipa-ra` - Register allocation
- `-fipa-sra` - Scalar replacement of aggregates
- `-fipa-vrp` - Value range propagation
- `-fdevirtualize-speculatively` - Speculative devirtualization
- `-fdevirtualize-at-ltrans` - Devirtualization at link time

**Why**: Large ML libraries (OpenVINO, oneDNN) benefit significantly from whole-program optimization. IPA enables cross-module optimizations.

**Performance Impact**: 10-20% improvement for large codebases.

### 4. Cache Tuning

**Selected**: Meteor Lake-specific cache parameters
- `--param l1-cache-size=48` (P-core L1D: 48KB)
- `--param l2-cache-size=2048` (P-core L2: 2MB)
- `--param prefetch-latency=300`
- `--param simultaneous-prefetches=6`

**Why**: ML workloads are memory-intensive. Proper cache tuning improves data locality and prefetching.

**Performance Impact**: 5-15% improvement for memory-bound operations.

### 5. Link-Time Optimization (LTO)

**Selected**: `-flto=auto -fuse-linker-plugin`

**Why**: Enables cross-module optimizations across the entire OpenVINO/oneDNN codebase. Critical for large libraries.

**Performance Impact**: 5-10% improvement, especially for function calls across module boundaries.

### 6. Security Hardening

**Selected**: Full hardening suite
- `-D_FORTIFY_SOURCE=3` - Advanced buffer overflow detection
- `-fstack-protector-strong` - Stack canary protection
- `-fstack-clash-protection` - Stack clash protection
- `-fcf-protection=full` - Control-flow integrity (CET)
- `-fpie -fPIC` - Position Independent Code
- `-Wl,-z,relro -Wl,-z,now` - Full RELRO

**Why**: HARDVINO requires military-grade security. These flags add minimal overhead (<2%) while providing critical security protections.

### 7. Compiler-Specific Optimizations

#### Clang (Recommended)
- **Polly Polyhedral Optimizer**: Enabled if available
  - Powerful loop transformations for ML kernels
  - Automatic parallelization
  - Cache-aware tiling

- **LLVM Optimizations**:
  - `-mllvm -inline-threshold=1000` - Aggressive inlining
  - `-mllvm -vectorize-loops` - Loop vectorization
  - `-mllvm -enable-gvn-hoist` - Global Value Numbering

#### GCC
- **Graphite Optimizations**: Enabled
  - `-fgraphite` - Graphite framework
  - `-floop-nest-optimize` - Nested loop optimization
  - `-floop-parallelize-all` - Automatic parallelization

## Flag Sets Comparison

| Flag Set | Use Case | IEEE Compliant | Performance | Security |
|----------|----------|----------------|-------------|----------|
| `CFLAGS_OPTIMAL` | **Recommended** | ✅ Yes | High | ✅ Hardened |
| `CFLAGS_SPEED` | Max speed (unsafe) | ❌ No | Highest | ⚠️ Basic |
| `CFLAGS_BALANCED` | General purpose | ✅ Yes | Medium | ⚠️ Basic |
| `CFLAGS_MEGA` | All optimizations | ✅ Yes | Very High | ✅ Hardened |

**Selected**: `CFLAGS_OPTIMAL_HARDVINO` (based on `CFLAGS_OPTIMAL` + IPA + cache tuning + security)

## Architecture-Specific Notes

### Meteor Lake Limitations
- ❌ **No AVX-512** - P-cores don't support AVX-512
- ✅ **AVX2 + AVX-VNNI** - Primary SIMD path
- ✅ **AVX-VNNI-INT8** - 8-bit quantization support
- ✅ **Hybrid Architecture** - 6 P-cores + 10 E-cores

### Optimal Core Affinity
- **P-cores (0-5)**: Compute-intensive ML inference
- **E-cores (6-15)**: Background tasks, I/O

**Environment Variables**:
```bash
export OMP_NUM_THREADS="6"           # Use P-cores only
export GOMP_CPU_AFFINITY="0-5"       # Bind to P-cores
export OMP_PROC_BIND="true"
export OMP_PLACES="cores"
```

## Usage

### Source the Optimal Flags

```bash
# Method 1: Source directly
source scripts/optimal_flags_hardvino.sh

# Method 2: Use in build scripts
export CFLAGS="${CFLAGS_OPTIMAL_HARDVINO}"
export CXXFLAGS="${CXXFLAGS_OPTIMAL_HARDVINO}"
export LDFLAGS="${LDFLAGS_OPTIMAL_HARDVINO}"
```

### Verify Flags

```bash
source scripts/optimal_flags_hardvino.sh
verify_flags
```

### Build with Optimal Flags

```bash
# CMake
cmake .. \
    -DCMAKE_C_FLAGS="${CFLAGS_OPTIMAL_HARDVINO}" \
    -DCMAKE_CXX_FLAGS="${CXXFLAGS_OPTIMAL_HARDVINO}" \
    -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS_OPTIMAL_HARDVINO}"

# Autotools
./configure \
    CFLAGS="${CFLAGS_OPTIMAL_HARDVINO}" \
    CXXFLAGS="${CXXFLAGS_OPTIMAL_HARDVINO}" \
    LDFLAGS="${LDFLAGS_OPTIMAL_HARDVINO}"
```

## Performance Expectations

Based on Meteor Lake architecture and selected flags:

| Component | Expected Improvement |
|-----------|---------------------|
| OpenVINO CPU Plugin | 15-25% faster inference |
| oneDNN Kernels | 20-30% faster (AVX-VNNI) |
| INT8 Quantized Models | 2-4x speedup |
| Build Time | 10-20% slower (due to LTO) |
| Binary Size | 5-10% larger (due to inlining) |

## Troubleshooting

### Compiler Doesn't Support meteorlake

**Solution**: Falls back to `alderlake` automatically. Performance impact: <1%.

### Flags Cause Compilation Errors

**Solution**: Run `verify_flags` to test. Falls back to basic `-O3 -march=native` if needed.

### LTO Causes Linker Errors

**Solution**: Ensure linker plugin is available:
```bash
# GCC
gcc -v 2>&1 | grep "plugin"

# Clang
clang -v 2>&1 | grep "LLVM"
```

### Polly Not Available

**Solution**: Install LLVM with Polly support, or use GCC with Graphite (enabled by default).

## References

- [METEOR_LAKE_COMPLETE_FLAGS.sh](../meteor_lake_flags_ultimate/METEOR_LAKE_COMPLETE_FLAGS.sh) - Complete flag reference
- [Intel Meteor Lake Architecture](https://www.intel.com/content/www/us/en/products/docs/processors/core-ultra/meteor-lake-architecture-overview.html)
- [AVX-VNNI Documentation](https://www.intel.com/content/www/us/en/developer/articles/technical/advanced-vector-extensions-avx-512-for-intel-xeon-processor-family.html)
- [OpenVINO Optimization Guide](https://docs.openvino.ai/latest/openvino_docs_optimization_guide_dldt_optimization_guide.html)
