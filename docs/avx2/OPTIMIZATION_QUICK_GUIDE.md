# AVX2 Optimization Quick Guide

## Quick Reference for HARDVINO AVX2-First Workflow

### TL;DR

```bash
# Meteor Lake supports: AVX2 + AVX-VNNI (NOT AVX-512)
# This configuration is already optimal - no changes needed!

# Build everything
./build_all.sh

# Set up environment
source install/setupvars.sh

# Initialize NPU
init_npu_tactical

# Test
test_npu_military
```

## Configuration Summary

### ✅ What IS Configured (Optimal)

| Component | Setting | Status |
|-----------|---------|--------|
| OpenVINO | `ENABLE_AVX2=ON` | ✅ Optimal |
| OpenVINO | `ENABLE_AVX512F=OFF` | ✅ Correct |
| Compiler | `-mavx2 -mavxvnni` | ✅ Optimal |
| oneDNN | Auto-detect AVX2+VNNI | ✅ Optimal |
| Security | Full hardening enabled | ✅ Optimal |

### ❌ What is NOT Configured (By Design)

| Feature | Why Not |
|---------|---------|
| AVX-512 | Not supported on Meteor Lake |
| `-march=znver*` | AMD-specific |
| `-xCORE-AVX512` | Intel ICC legacy flag |

## Key Files

### 1. OpenVINO Build Configuration
**File**: `build_hardened_openvino.sh` (lines 146-162)

```bash
-DENABLE_SSE42=ON        # Base ISA
-DENABLE_AVX2=ON         # Primary optimization ✓
-DENABLE_AVX512F=OFF     # Disabled (not supported)
```

### 2. Compiler Flags
**File**: `meteor_lake_flags_ultimate/METEOR_LAKE_COMPLETE_FLAGS.sh`

```bash
CFLAGS_OPTIMAL includes:
  -march=meteorlake -mtune=meteorlake
  -mavx -mavx2              # 256-bit SIMD
  -mavxvnni                 # AI acceleration ★
  -mfma -mf16c              # Math acceleration
```

### 3. oneDNN Configuration
**File**: `build_hardened_oneapi.sh` (lines 62-73)

```bash
-DDNNL_ENABLE_MAX_CPU_ISA=ON      # Auto-detect best ISA
-DDNNL_ENABLE_CPU_ISA_HINTS=ON    # Use AVX2+VNNI hints
```

## Performance Tuning Checklist

### ✅ Pre-Build Optimization

```bash
# 1. Ensure correct compiler version
gcc --version  # Should be GCC 11+

# 2. Source optimization flags
source meteor_lake_flags_ultimate/METEOR_LAKE_COMPLETE_FLAGS.sh

# 3. Verify flags work
test_flags  # Should show: ✓ Flags verified working!
```

### ✅ Build-Time Optimization

```bash
# Clean build recommended for architecture changes
./build_all.sh --clean

# Expected build time: ~1 hour on 6P+10E cores
```

### ✅ Runtime Optimization

```bash
# 1. Set CPU governor to performance
for i in {0..5}; do
  echo performance | sudo tee /sys/devices/system/cpu/cpu${i}/cpufreq/scaling_governor
done

# 2. Bind to P-cores (0-5)
export GOMP_CPU_AFFINITY="0-5"
export OMP_NUM_THREADS="6"
export OMP_PROC_BIND="true"
export OMP_PLACES="cores"

# 3. Force AVX2+VNNI in oneDNN (optional, auto-detected)
export DNNL_MAX_CPU_ISA=AVX2_VNNI

# 4. OpenVINO CPU plugin config
export OV_CPU_THREADS_NUM=6
export OV_CPU_BIND_THREAD=YES
export OV_CPU_THROUGHPUT_STREAMS=6
```

## Verification Commands

### Check CPU Capabilities

```bash
# Should show avx2, avx_vnni
lscpu | grep Flags | tr ',' '\n' | grep -E 'avx|vnni'

# Should NOT show avx512f
lscpu | grep Flags | grep avx512f || echo "AVX-512 not present (expected for Meteor Lake)"
```

### Check Build Configuration

```bash
# After building, verify OpenVINO CMake cache
grep "AVX" build/openvino/CMakeCache.txt

# Expected output:
# ENABLE_AVX2:BOOL=ON
# ENABLE_AVX512F:BOOL=OFF
```

### Check Runtime ISA Selection

```bash
# Run with oneDNN verbose mode
export DNNL_VERBOSE=1
python3 << 'EOF'
import openvino as ov
core = ov.Core()
print("CPU Capabilities:", core.get_property("CPU", "OPTIMIZATION_CAPABILITIES"))
EOF

# Look for:
# - FP32, FP16, INT8 capabilities
# - AVX2 kernels in verbose output (jit:avx2)
```

### Check Binary Instructions

```bash
# Verify AVX2 instructions in binary
objdump -d install/openvino/lib/libopenvino.so | grep -E 'vfmadd|vpdpbusd' | head -5

# vfmadd*   = AVX2+FMA instructions ✓
# vpdpbusd  = AVX-VNNI instructions ✓
```

## Common Optimization Patterns

### 1. OpenVINO Python

```python
import openvino as ov
import openvino.properties as props

core = ov.Core()

# CPU configuration for AVX2+VNNI
cpu_config = {
    props.inference_num_threads: 6,        # 6 P-cores
    props.affinity: props.Affinity.CORE,   # Core affinity
    props.hint.performance_mode: props.PerformanceMode.LATENCY,
    props.hint.inference_precision: "f32",
}

compiled_model = core.compile_model(model, "CPU", cpu_config)
```

### 2. NPU + CPU Hybrid

```python
# Use HETERO or AUTO for NPU+CPU
config = {
    "PERFORMANCE_HINT": "LATENCY",
    "HETERO_DEVICE_PRIORITIES": "NPU,CPU"
}

compiled_model = core.compile_model(model, "HETERO:NPU,CPU", config)
```

### 3. C/C++ Compilation

```bash
# Use the optimal flags
source npu_military_config.sh

# Compile your application
g++ -o myapp myapp.cpp \
    $CFLAGS_NPU_HARDENED \
    -I${OPENVINO_INSTALL_DIR}/runtime/include \
    -L${OPENVINO_INSTALL_DIR}/runtime/lib/intel64 \
    -lopenvino \
    $LDFLAGS_NPU_HARDENED
```

## Performance Expectations

### AVX2+VNNI vs Other ISAs

| Workload | SSE4.2 | AVX2 | AVX2+VNNI |
|----------|--------|------|-----------|
| FP32 Inference | 1.0x | 2.5x | 2.8x |
| INT8 Inference | 1.0x | 2.0x | **4.0x** |
| Matrix Multiply | 1.0x | 2.5x | 3.0x |
| Convolution | 1.0x | 2.2x | **4.5x** |

### Meteor Lake Performance Targets

| Model Type | Target FPS | Device |
|------------|-----------|---------|
| ResNet-50 (INT8) | 120+ | NPU |
| MobileNet-v2 (INT8) | 250+ | NPU |
| BERT-base (FP32) | 40+ | CPU (AVX2) |
| YOLOv5s (INT8) | 60+ | NPU |

## Troubleshooting

### Issue: Slow Performance

**Check 1**: Verify AVX2 is being used
```bash
export DNNL_VERBOSE=1
# Run inference and look for "jit:avx2" in output
```

**Check 2**: Check CPU frequency
```bash
watch -n1 "grep MHz /proc/cpuinfo | head -6"
# P-cores should boost to ~4.9 GHz
```

**Check 3**: Verify thread affinity
```bash
taskset -cp $$
# Should show CPUs 0-5 if bound to P-cores
```

### Issue: Illegal Instruction

**Cause**: Binary compiled with AVX-512 flags

**Fix**:
```bash
# Explicitly disable AVX-512
export CFLAGS="$CFLAGS -mno-avx512f"
./build_all.sh --clean
```

### Issue: oneDNN Not Using AVX2

**Check**: oneDNN ISA selection
```bash
export DNNL_VERBOSE=1
# Look for "isa:avx2" or "isa:avx2_vnni" in verbose output
```

**Fix**: Force AVX2+VNNI
```bash
export DNNL_MAX_CPU_ISA=AVX2_VNNI
```

## Optimization Tips

### 1. Memory Allocation

```bash
# Use jemalloc or tcmalloc for better memory performance
export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2
```

### 2. Huge Pages

```bash
# Enable transparent huge pages
echo madvise | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
```

### 3. NUMA Configuration

```bash
# Meteor Lake is typically single-socket, but set for clarity
export OMP_PROC_BIND=close
export OMP_PLACES=cores
```

### 4. Compiler Optimization Levels

```bash
# For maximum performance (less safe)
export CFLAGS_OPTIMAL="$CFLAGS_OPTIMAL -Ofast -ffast-math"

# For balanced (recommended)
export CFLAGS_OPTIMAL="$CFLAGS_OPTIMAL -O2"  # Default

# For debugging
export CFLAGS_DEBUG="$CFLAGS_DEBUG -Og -g3 -fno-omit-frame-pointer"
```

## Quick Validation Script

Save this as `validate_avx2.sh`:

```bash
#!/bin/bash
echo "=== HARDVINO AVX2-First Validation ==="
echo

echo "1. CPU Capabilities:"
lscpu | grep "Model name"
echo -n "   AVX2: "
grep avx2 /proc/cpuinfo > /dev/null && echo "✓ Present" || echo "✗ Missing"
echo -n "   AVX-512: "
grep avx512f /proc/cpuinfo > /dev/null && echo "⚠ Present (unexpected)" || echo "✓ Not present (correct)"

echo
echo "2. Build Configuration:"
if [ -f "build/openvino/CMakeCache.txt" ]; then
    echo -n "   AVX2: "
    grep "ENABLE_AVX2:BOOL=ON" build/openvino/CMakeCache.txt > /dev/null && echo "✓ Enabled" || echo "✗ Disabled"
    echo -n "   AVX512F: "
    grep "ENABLE_AVX512F:BOOL=OFF" build/openvino/CMakeCache.txt > /dev/null && echo "✓ Disabled" || echo "⚠ Enabled"
else
    echo "   ⚠ Not built yet - run ./build_all.sh"
fi

echo
echo "3. Compiler Flags:"
source meteor_lake_flags_ultimate/METEOR_LAKE_COMPLETE_FLAGS.sh
echo -n "   AVX2 in CFLAGS: "
echo "$CFLAGS_OPTIMAL" | grep "mavx2" > /dev/null && echo "✓ Present" || echo "✗ Missing"
echo -n "   AVX-VNNI in CFLAGS: "
echo "$CFLAGS_OPTIMAL" | grep "mavxvnni" > /dev/null && echo "✓ Present" || echo "✗ Missing"

echo
echo "4. Runtime Environment:"
if [ -f "install/setupvars.sh" ]; then
    echo "   ✓ Installation found"
    source install/setupvars.sh 2>/dev/null
    if command -v python3 &> /dev/null; then
        echo -n "   OpenVINO: "
        python3 -c "import openvino; print('✓ Installed')" 2>/dev/null || echo "⚠ Not in Python path"
    fi
else
    echo "   ⚠ Not installed yet - run ./build_all.sh"
fi

echo
echo "=== Validation Complete ==="
```

Make it executable:
```bash
chmod +x validate_avx2.sh
./validate_avx2.sh
```

## Summary

### ✅ Current Status: OPTIMAL

HARDVINO is **already configured** for AVX2-first workflow:
- ✅ AVX2 + AVX-VNNI enabled
- ✅ AVX-512 disabled (not supported on Meteor Lake)
- ✅ Optimal compiler flags configured
- ✅ oneDNN auto-detection enabled
- ✅ Security hardening applied

### No Changes Needed

The current configuration is optimal for Meteor Lake. Simply:
1. Build: `./build_all.sh`
2. Use: `source install/setupvars.sh`
3. Test: `test_npu_military`

### For More Details

- **Complete workflow**: See `AVX2_FIRST_WORKFLOW.md`
- **Architecture docs**: See `README.md`
- **Security hardening**: See `npu_military_config.sh`

---

**HARDVINO** - Optimized for AVX2+VNNI on Intel Meteor Lake
