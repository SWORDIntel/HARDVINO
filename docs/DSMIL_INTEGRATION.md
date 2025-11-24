# HARDVINO - DSMIL Integration Guide

Complete guide for integrating HARDVINO into the DSMIL framework.

---

## Overview

**HARDVINO supersedes upstream OpenVINO** with:
- Hardened build (CET/CFI, RELRO, FORTIFY=3)
- Meteor Lake optimization (AVX2, AVX-VNNI)
- Integrated oneDNN, oneTBB
- NPU VPU 3720 support
- 34 Intel stack submodules

---

## Quick Start

```bash
# In DSMIL project root
git submodule add https://github.com/SWORDIntel/HARDVINO.git hardvino
cd hardvino
./install.sh --init --deps --all
```

---

## Single Entrypoint: `install.sh`

```bash
./install.sh [options]

Options:
  --init          Initialize all 34 submodules
  --deps          Install system dependencies
  --core          Build HARDVINO core (stages 1-3)
  --extended      Build extended stack (stages 4-8)
  --platform      Build PLATFORM (stage 9)
  --all           Build everything
  --clean         Clean before building
  --jobs N        Parallel jobs (default: nproc)
```

### Build Stages

| Stage | Components | Dependencies |
|-------|------------|--------------|
| 1 | Toolchains (xetla) | None |
| 2 | oneAPI (TBB, DNN, MKL, DAL, CCL, DPL) | Stage 1 |
| 3 | **HARDVINO Core** (supersedes OpenVINO) | Stage 2 |
| 4 | Runtimes (GPU, NPU, Level Zero) | Stage 3 |
| 5 | Media (VAAPI drivers) | Stage 4 |
| 6 | QAT (crypto, compression) | None |
| 7 | ML Frameworks (PyTorch, TF, HF) | Stage 3-4 |
| 8 | Tools (Open3D, XeSS, ROS2) | Stage 7 |
| 9 | **PLATFORM** | All |

---

## CMake Integration

### Method 1: Include Config

```cmake
# CMakeLists.txt
include(hardvino/cmake/HARDVINOConfig.cmake)

add_executable(my_inference main.cpp)
target_link_hardvino(my_inference)
```

### Method 2: Find Package

```cmake
set(CMAKE_PREFIX_PATH "${CMAKE_SOURCE_DIR}/hardvino/install" ${CMAKE_PREFIX_PATH})

find_package(OpenVINO REQUIRED)
find_package(TBB REQUIRED)
find_package(dnnl REQUIRED)

target_link_libraries(my_app
    openvino::runtime
    TBB::tbb
    DNNL::dnnl
)
```

### Method 3: Manual Flags

```cmake
include(hardvino/cmake/HARDVINOConfig.cmake)

# Apply Meteor Lake optimized flags
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${HARDVINO_C_FLAGS}")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${HARDVINO_CXX_FLAGS}")

# Security hardening
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${HARDVINO_HARDENING_FLAGS}")
```

---

## Shell Environment

```bash
# Source the unified setup
source hardvino/install/setup_hardvino.sh

# Or source individual components
source hardvino/scripts/intel_env.sh   # Compiler flags
```

### Environment Variables Set

| Variable | Description |
|----------|-------------|
| `HARDVINO_ROOT` | HARDVINO installation root |
| `CFLAGS_OPTIMAL` | Meteor Lake optimized C flags |
| `LDFLAGS_OPTIMAL` | Optimized linker flags |
| `KCFLAGS` | Kernel compilation flags |
| `RUSTFLAGS` | Rust compilation flags |
| `OV_NPU_*` | OpenVINO NPU configuration |

---

## Kernel Integration

### Required Kernel Config

```text
# NPU
CONFIG_ACCEL=y
CONFIG_DRM_ACCEL=y
CONFIG_DRM_ACCEL_IVPU=m

# iGPU
CONFIG_DRM_XE=m

# QAT
CONFIG_CRYPTO_DEV_QAT=m

# Security
CONFIG_LSM="lockdown,yama,bpf,apparmor"
CONFIG_BPF_LSM=y
```

### Build Kernel with HARDVINO Flags

```bash
source hardvino/scripts/intel_env.sh

make LLVM=1 LLVM_IAS=1 \
     CC=clang HOSTCC=clang HOSTCXX=clang++ \
     KCFLAGS="$KCFLAGS" \
     -j$(nproc)
```

---

## MCM-1000 DSMIL NPU Abstraction

HARDVINO documents the MCM-1000 abstraction layer:

```yaml
mcm_1000:
  device: "MCM-1000 (DSMIL NPU Abstraction)"
  driver: "dsmil_mcm / intel_vpu"
  hardware: "Intel Meteor Lake NPU (VPU 3720)"
  virtual_devices: 32
  device_range: "31-62"
  tokens_per_device: 3
  total_registers: 96
```

The MCM-1000 creates 32 virtual NPU devices, enabling multi-process access to the physical NPU.

---

## Directory Structure

```
DSMIL/
├── hardvino/                          # HARDVINO submodule
│   ├── install.sh                     # Single entrypoint
│   ├── oneapi-tbb/                    # Threading
│   ├── oneapi-dnn/                    # DNN kernels
│   ├── NUC2.1/                        # Movidius VPU
│   ├── submodules/
│   │   ├── PLATFORM/                  # AI Platform
│   │   └── intel-stack/
│   │       ├── runtimes/              # GPU, NPU, media, QAT
│   │       ├── toolchains/            # oneAPI libs
│   │       └── tools/                 # PyTorch, TF, etc.
│   ├── scripts/
│   │   ├── intel_env.sh               # Compiler flags
│   │   ├── build_order.sh             # Build stages
│   │   └── integrate.sh               # Integration helper
│   ├── cmake/
│   │   └── HARDVINOConfig.cmake       # CMake config
│   ├── docs/
│   │   ├── MASTER_PROMPT.md           # AI system prompt
│   │   ├── KERNEL_CONFIG.md           # Kernel flags
│   │   └── DSMIL_INTEGRATION.md       # This file
│   ├── intel_stack.manifest.yml       # Component manifest
│   └── install/                       # Built artifacts
│       └── setup_hardvino.sh          # Environment setup
├── kernel/                            # DSMIL kernel
└── CMakeLists.txt                     # DSMIL build
```

---

## Submodule Update

```bash
cd hardvino
git pull origin main
git submodule update --recursive --depth 1
./install.sh --clean --all
```

---

## Verification

### Check Installation

```bash
./hardvino/scripts/integrate.sh --check
```

### Test NPU

```bash
source hardvino/install/setup_hardvino.sh
python3 -c "from openvino.runtime import Core; print(Core().available_devices)"
```

### Benchmark

```bash
# NPU benchmark (create your own based on workload)
./hardvino/scripts/benchmark_npu.sh

# GPU benchmark
./hardvino/scripts/benchmark_gpu.sh
```

---

## Troubleshooting

### NPU Not Found

```bash
# Check device
ls -la /dev/accel/accel0

# Load driver
sudo modprobe intel_vpu

# Check firmware
ls /lib/firmware/intel/vpu/
```

### Build Failures

```bash
# Clean rebuild
./install.sh --clean --init --all

# Check dependencies
./install.sh --deps
```

### Library Not Found

```bash
# Re-source environment
source hardvino/install/setup_hardvino.sh

# Check paths
echo $LD_LIBRARY_PATH
```

---

## Component Reference

| Component | Purpose | Build Stage |
|-----------|---------|-------------|
| oneTBB | Threading | 2 |
| oneDNN | DNN kernels | 2 |
| oneMKL | Math kernels | 2 |
| **HARDVINO** | OpenVINO (hardened) | 3 |
| NUC2.1 | Movidius VPU | 3 |
| compute-runtime | GPU OpenCL/L0 | 4 |
| level-zero | Low-level GPU | 4 |
| media-driver | VAAPI | 5 |
| qatlib | QAT crypto | 6 |
| IPEX | PyTorch accel | 7 |
| ITEX | TensorFlow accel | 7 |
| neural-speed | LLM inference | 7 |
| Open3D | 3D perception | 8 |
| **PLATFORM** | AI platform | 9 |

---

## Support

- GitHub: https://github.com/SWORDIntel/HARDVINO
- DSMIL: https://github.com/SWORDIntel/DSMILSystem
- PLATFORM: https://github.com/SWORDIntel/PLATFORM
