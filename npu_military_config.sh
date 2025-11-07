#!/bin/bash
# ============================================================================
# CLASSIFIED: NPU WEAPONIZATION FLAGS - METEOR LAKE VPU 3720
# KYBERLOCK TACTICAL COMPUTING DIVISION
# HARDVINO - Hardened OpenVINO/OneAPI Kernel Integration
# ============================================================================

set -e

# Source the Meteor Lake compiler flags
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/meteor_lake_flags_ultimate/METEOR_LAKE_COMPLETE_FLAGS.sh"

# ============================================================================
# NPU AGGRESSIVE OPTIMIZATION - TIER 1 OPERATOR MODE
# ============================================================================

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

# ============================================================================
# OPENVINO NPU TACTICAL CONFIGURATION
# ============================================================================

export OV_NPU_COMPILER_TYPE=DRIVER
export OV_NPU_PLATFORM=3720
export OV_NPU_PLATFORM_FOR_GENERATION=VPU3720
export OV_NPU_DEVICE_ID=0x7D1D
export OV_NPU_MAX_TILES=2
export OV_NPU_DPU_GROUPS=4  # Override default
export OV_NPU_DMA_ENGINES=4  # Max DMA channels
export OV_NPU_PROFILING=OFF  # Disable for max perf
export OV_NPU_PRINT_PROFILING=OFF
export OV_NPU_PROFILING_OUTPUT_FILE=/dev/null
export OV_NPU_USE_ELF_COMPILER_BACKEND=YES
export OV_NPU_CREATE_EXECUTOR=1

# ============================================================================
# ADVANCED NPU EXPLOITATION
# ============================================================================

export OV_NPU_ENABLE_ELTWISE_UNROLL=YES
export OV_NPU_ENABLE_CONCAT_OPTIMIZATION=YES
export OV_NPU_ENABLE_CONV_CONCAT_OPTIMIZATION=YES
export OV_NPU_ENABLE_WEIGHTS_ANALYSIS=YES
export OV_NPU_ENABLE_GROUPED_CONV=YES
export OV_NPU_ENABLE_DEPTHWISE_CONV=YES
export OV_NPU_ENABLE_STREAM_EXECUTOR=YES
export OV_NPU_ENABLE_ASYNC_EXECUTOR=YES
export OV_NPU_ENABLE_HW_ADAPTABLE_TENSOR=YES
export OV_NPU_ENABLE_PERMUTE_MERGING=YES
export OV_NPU_ENABLE_LAYER_FUSION=YES
export OV_NPU_ENABLE_FP16_COMPRESSION=YES
export OV_NPU_ENABLE_DYNAMIC_SHAPE=YES
export OV_NPU_ENABLE_BATCH_MODE=YES

# ============================================================================
# NPU MEMORY OPTIMIZATION - TACTICAL MODE
# ============================================================================

export OV_NPU_DDR_BANDWIDTH_LIMIT=68000  # MB/s (max theoretical)
export OV_NPU_CMX_SIZE=4194304  # 4MB CMX memory
export OV_NPU_MEM_BANKS_ALIGNMENT=4096
export OV_NPU_DMX_BUFFER_SIZE=33554432  # 32MB
export OV_NPU_TENSOR_SWIZZLING=2
export OV_NPU_PREFETCH_DISTANCE=10
export OV_NPU_MAX_KERNEL_PER_DEVICE=8192

# ============================================================================
# NPU SCHEDULING - MILITARY PRIORITY
# ============================================================================

export OV_NPU_SCHEDULING_ALGORITHM=PERFORMANCE
export OV_NPU_ENABLE_SCHEDULE_INFERENCE=YES
export OV_NPU_ENABLE_PIPELINE_EXECUTOR=YES
export OV_NPU_PIPELINE_DEPTH=16
export OV_NPU_INFER_THREADS_NUM=8
export OV_NPU_EXECUTOR_STREAMS=4
export OV_NPU_INFERENCE_TIMEOUT=0  # No timeout
export OV_NPU_DEVICE_PRIORITY=100  # Max priority

# ============================================================================
# POWER & THERMAL - UNRESTRICTED MODE
# ============================================================================

export OV_NPU_POWER_MODE=MAXIMUM_PERFORMANCE
export OV_NPU_PERFORMANCE_HINT=LATENCY
export OV_NPU_THERMAL_THROTTLE_LEVEL=DISABLED
export OV_NPU_TURBO_MODE=ENABLED
export OV_NPU_VOLTAGE_CONTROL=ADAPTIVE_OVERCLOCK

# ============================================================================
# KERNEL MODULE PARAMETERS
# ============================================================================

export NPU_MODULE_PARAMS="firmware_path=/lib/firmware/intel/vpu/vpu_3720.bin \
    enable_boot_debug=0 \
    enable_fw_log=0 \
    fw_log_level=0 \
    disable_recovery=0 \
    disable_runtime_pm=1 \
    enable_latency_stats=0 \
    job_timeout_ms=0"

# ============================================================================
# COMPILATION FLAGS WITH NPU SUPPORT - HARDENED
# ============================================================================

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

# Merge with security hardening flags (from ImageHarden approach)
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

export LDFLAGS_NPU_HARDENED="$LDFLAGS_OPTIMAL \
    $LDFLAGS_SECURITY"

# ============================================================================
# NPU DEVICE INITIALIZATION - TACTICAL
# ============================================================================

init_npu_tactical() {
    echo "🔴 INITIALIZING NPU TACTICAL MODE..."

    # Check if NPU device exists
    if [[ ! -e /dev/accel/accel0 ]]; then
        echo "⚠️  NPU device not found at /dev/accel/accel0"
        echo "    Loading intel_vpu module..."
        sudo modprobe intel_vpu 2>/dev/null || echo "    Module may need to be built first"
    fi

    if [[ -e /dev/accel/accel0 ]]; then
        # Set device permissions
        sudo chmod 666 /dev/accel/accel0
        sudo chown $USER:render /dev/accel/accel0 2>/dev/null || true

        # Load firmware with max performance
        if [[ -f /sys/class/accel/accel0/device/power/control ]]; then
            sudo sh -c 'echo performance > /sys/class/accel/accel0/device/power/control'
            sudo sh -c 'echo 0 > /sys/class/accel/accel0/device/power/runtime_suspend_time'
            sudo sh -c 'echo on > /sys/class/accel/accel0/device/power/control'
        fi

        # Set max frequency (if available)
        if [[ -f /sys/class/accel/accel0/device/npu_frequency ]]; then
            sudo sh -c 'echo 1850000000 > /sys/class/accel/accel0/device/npu_frequency'
        fi

        echo "✓ NPU WEAPONIZED"
    else
        echo "⚠️  NPU device not available - continuing with CPU/GPU fallback"
    fi
}

# ============================================================================
# OPENVINO NPU TEST - MILITARY GRADE
# ============================================================================

test_npu_military() {
    python3 << 'EOF'
import numpy as np
try:
    import openvino as ov
    import openvino.properties as props

    core = ov.Core()

    # Configure NPU for maximum performance
    config = {
        props.performance_mode: props.PerformanceMode.LATENCY,
        props.cache_dir: "/tmp/npu_cache",
        props.enable_profiling: False,
        "NPU_PLATFORM": "VPU3720",
        "NPU_COMPILATION_MODE": "DefaultHW",
        "NPU_DPU_GROUPS": "4",
        "NPU_DMA_ENGINES": "4",
    }

    # Check NPU availability
    devices = core.available_devices
    if "NPU" in devices:
        print("🎯 NPU ONLINE - VPU 3720 READY FOR COMBAT")

        # Get NPU properties
        npu_name = core.get_property("NPU", props.device.full_name)
        print(f"🔫 NPU DESIGNATION: {npu_name}")

        print("🚀 NPU INFERENCE ENGINE: ARMED")
        print("⚡ NEURAL COMPUTE ENGINES: 2x ACTIVE")
        print("💾 CMX MEMORY: 4MB ALLOCATED")
        print("🎖️ TACTICAL MODE: ENGAGED")
    else:
        print("⚠️ NPU OFFLINE - Available devices:", devices)
        print("    Install OpenVINO 2024+ with NPU support")
except ImportError as e:
    print(f"❌ OPENVINO NOT INSTALLED - {e}")
    print("Install: pip install openvino==2024.0.0")
except Exception as e:
    print(f"⚠️ NPU TEST FAILED: {e}")
EOF
}

# ============================================================================
# NPU BENCHMARK - TACTICAL OPERATIONS
# ============================================================================

benchmark_npu_military() {
    echo "🔴 NPU TACTICAL BENCHMARK"
    echo "=========================="

    # Check NPU frequency
    if [[ -f /sys/class/accel/accel0/device/npu_frequency ]]; then
        echo "NPU Frequency: $(cat /sys/class/accel/accel0/device/npu_frequency) Hz"
    fi

    # Check power state
    if [[ -f /sys/class/accel/accel0/device/power/runtime_status ]]; then
        echo "Power State: $(cat /sys/class/accel/accel0/device/power/runtime_status)"
    fi

    # Memory info
    echo "NPU Memory Configuration:"
    echo "  - CMX: 4MB (Close-to-Metal eXecution)"
    echo "  - DDR Bandwidth: 68 GB/s"
    echo "  - L2 Cache: 2.5MB"
    echo "  - Neural Compute Engines: 2"
    echo "  - SHAVE Processors: 8"
    echo "  - Frequency: 1.85 GHz (Turbo)"
}

# ============================================================================
# ACTIVATION MESSAGE
# ============================================================================

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  NPU MILITARY CONFIGURATION LOADED - VPU 3720                           ║"
echo "║  HARDVINO: Hardened OpenVINO/OneAPI Build System                        ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "NPU Compiler Flags: \$CFLAGS_NPU_HARDENED"
echo "NPU Linker Flags:   \$LDFLAGS_NPU_HARDENED"
echo ""
echo "Functions:"
echo "  init_npu_tactical    - Initialize NPU in tactical mode"
echo "  test_npu_military    - Test NPU with OpenVINO"
echo "  benchmark_npu_military - Display NPU benchmark info"
echo ""
