# HARDVINO

**Intel Acceleration Stack for DSMIL - Supersedes OpenVINO**

HARDVINO is a hardened, security-first build of the complete Intel AI compute stack, optimized for Intel Core Ultra 7 165H (Meteor Lake) with NPU VPU 3720 support. It provides a single entrypoint for building 35 Intel components with military-grade security hardening.

---

## Key Features

- **Supersedes OpenVINO**: HARDVINO replaces upstream OpenVINO with hardened builds
- **Single Entrypoint**: `./install.sh --all` builds the complete Intel AI stack
- **35 Submodules**: Complete Intel ecosystem (oneAPI, GPU, NPU, QAT, ML frameworks)
- **Meteor Lake Optimized**: AVX2/AVX-VNNI tuning for Core Ultra 7 165H
- **Security Hardened**: CET/CFI, RELRO, FORTIFY=3, stack protection
- **DSMIL Integration**: Ready for submodule import into DSMIL framework
- **MCM-1000 NPU Abstraction**: 32 virtual NPU devices with 96 registers

---

## Quick Start

### Standalone Installation

```bash
git clone https://github.com/SWORDIntel/HARDVINO.git
cd HARDVINO
./install.sh --init --deps --all
source install/setup_hardvino.sh
```

### As DSMIL Submodule

```bash
# In your DSMIL project root
git submodule add https://github.com/SWORDIntel/HARDVINO.git hardvino
cd hardvino
./install.sh --init --deps --all
```

---

## Single Entrypoint: `install.sh`

```bash
./install.sh [options]

Options:
  --init          Initialize all 35 submodules (shallow clone)
  --deps          Install system dependencies
  --core          Build core components (HARDVINO, oneDNN, oneTBB)
  --extended      Build extended stack (GPU, media, QAT, tools)
  --platform      Install PLATFORM AI framework
  --all           Build everything (core + extended + platform)
  --clean         Clean build directories before building
  --jobs N        Parallel jobs (default: nproc)
  --help          Show help
```

### Build Stages

The build system uses a 9-stage dependency-resolved architecture:

| Stage | Components | Dependencies |
|-------|------------|--------------|
| 1 | Toolchains (xetla) | None |
| 2 | oneAPI (TBB, DNN, MKL, DAL, CCL, DPL) | Stage 1 |
| 3 | **HARDVINO Core** (supersedes OpenVINO) | Stage 2 |
| 4 | Runtimes (GPU, NPU, Level Zero) | Stage 3 |
| 5 | Media (VAAPI drivers) | Stage 4 |
| 6 | QAT (crypto, compression) | None |
| 7 | ML Frameworks (PyTorch, TF, HuggingFace) | Stage 3-4 |
| 8 | Tools (Open3D, XeSS, ROS2, Containers) | Stage 7 |
| 9 | **PLATFORM** | All |

---

## CMake Integration

### Method 1: Include Config

```cmake
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

---

## Environment Setup

```bash
# Source the unified setup
source hardvino/install/setup_hardvino.sh

# Or source individual components
source hardvino/scripts/intel_env.sh   # Compiler flags
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `HARDVINO_ROOT` | HARDVINO installation root |
| `CFLAGS_OPTIMAL` | Meteor Lake optimized C flags |
| `LDFLAGS_OPTIMAL` | Optimized linker flags |
| `KCFLAGS` | Kernel compilation flags |
| `RUSTFLAGS` | Rust compilation flags |
| `OV_NPU_*` | OpenVINO NPU configuration |

---

## Target Hardware

### Intel Core Ultra 7 165H (Meteor Lake)

| Accelerator | Description | Driver |
|-------------|-------------|--------|
| **NPU** | VPU 3720 (Intel AI Boost) | `intel_vpu` |
| **iGPU** | Xe-LPG integrated graphics | `xe` |
| **CPU** | AVX2, AVX-VNNI | - |
| **QAT** | Crypto/compression offload | `qat_*` |

### MCM-1000 DSMIL NPU Abstraction

HARDVINO supports the MCM-1000 DSMIL driver abstraction:

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

---

## Security Hardening

HARDVINO builds with comprehensive security hardening:

```bash
# Compiler flags
-D_FORTIFY_SOURCE=3
-fstack-protector-strong
-fstack-clash-protection
-fcf-protection=full

# Linker flags
-Wl,-z,relro,-z,now
-Wl,-z,noexecstack
-Wl,-z,separate-code
```

### Verify Hardening

```bash
checksec --file=install/openvino/lib/libopenvino.so
# Expected: FULL RELRO, Canary, NX, PIE, FORTIFY enabled
```

---

## Component Summary (35 Submodules)

### Core (3)
- **HARDVINO** - Hardened OpenVINO (supersedes upstream)
- **oneTBB** - Threading Building Blocks
- **oneDNN** - Deep Neural Network Library
- **NUC2.1** - Movidius VPU support

### oneAPI Libraries (5)
- oneMKL, oneDAL, oneCCL, oneDPL, xetla

### GPU/NPU Runtimes (7)
- compute-runtime, intel-graphics-compiler, level-zero
- linux-npu-driver, intel-npu-acceleration-library
- Model-References (Gaudi), vllm-habana

### Media & QAT (5)
- media-driver, intel-vaapi-driver
- qatlib, QAT_Engine, QAT-ZSTD-Plugin

### ML Frameworks & Tools (14)
- intel-extension-for-pytorch, intel-extension-for-tensorflow
- torch-xpu-ops, neural-speed, neural-compressor, optimum-intel
- Open3D, XeSS, ros2_openvino_toolkit, openvino-rs
- PerfSpect, intel-ai-catalog, openvino_contrib, ai-containers

### Platform (1)
- **PLATFORM** - SWORDIntel AI Platform

---

## Kernel Configuration

Required kernel options for full accelerator support:

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

See [docs/KERNEL_CONFIG.md](docs/KERNEL_CONFIG.md) for complete configuration.

---

## Directory Structure

```
HARDVINO/
├── install.sh                     # Single entrypoint
├── intel_stack.manifest.yml       # Component manifest (v3.2.0)
├── oneapi-tbb/                    # Threading
├── oneapi-dnn/                    # DNN kernels
├── NUC2.1/                        # Movidius VPU
├── submodules/
│   ├── PLATFORM/                  # AI Platform
│   └── intel-stack/
│       ├── runtimes/              # GPU, NPU, media, QAT
│       ├── toolchains/            # oneAPI libs
│       └── tools/                 # PyTorch, TF, etc.
├── scripts/
│   ├── intel_env.sh               # Compiler flags
│   ├── build_order.sh             # Build stages
│   └── integrate.sh               # Integration helper
├── cmake/
│   └── HARDVINOConfig.cmake       # CMake config
├── docs/
│   ├── INDEX.md                   # Documentation index
│   ├── MASTER_PROMPT.md           # AI system prompt
│   ├── KERNEL_CONFIG.md           # Kernel flags
│   ├── DSMIL_INTEGRATION.md       # DSMIL guide
│   └── avx2/                      # AVX2 optimization docs
└── install/                       # Built artifacts
    └── setup_hardvino.sh          # Environment setup
```

---

## Verification

### Check Installation

```bash
./scripts/integrate.sh --check
```

### Test NPU

```bash
source install/setup_hardvino.sh
python3 -c "from openvino.runtime import Core; print(Core().available_devices)"
```

### Benchmark

```bash
# NPU benchmark
./scripts/benchmark_npu.sh

# GPU benchmark
./scripts/benchmark_gpu.sh
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

---

## Documentation

See [docs/INDEX.md](docs/INDEX.md) for the complete documentation index.

| Document | Description |
|----------|-------------|
| [DSMIL_INTEGRATION.md](docs/DSMIL_INTEGRATION.md) | DSMIL framework integration |
| [MASTER_PROMPT.md](docs/MASTER_PROMPT.md) | AI system prompt |
| [KERNEL_CONFIG.md](docs/KERNEL_CONFIG.md) | Kernel configuration |
| [avx2/](docs/avx2/) | AVX2-first optimization guides |

---

## Support

- GitHub: https://github.com/SWORDIntel/HARDVINO
- DSMIL: https://github.com/SWORDIntel/DSMILSystem
- PLATFORM: https://github.com/SWORDIntel/PLATFORM

---

## License

Components follow their respective licenses (Apache 2.0 for OpenVINO, oneTBB, oneDNN).
Build scripts and configuration: MIT License.

---

**HARDVINO** - Hardened Intel AI stack for mission-critical applications.
