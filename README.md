# HARDVINO

**Hardened OpenVINO/OneAPI Build System for Intel Meteor Lake with NPU VPU 3720 Support + Multi-Vendor AI Stack**

HARDVINO is a hardened, security-first build of the complete Intel AI compute stack, optimized for Intel Core Ultra 7 165H (Meteor Lake) with NPU VPU 3720 support. It provides a single entrypoint for building 35 Intel components with military-grade security hardening.

**Multi-Vendor Support**: HARDVINO now supports both Qualcomm AI Engine Direct (QNN SDK) and NVIDIA open-gpu-kernel-modules for heterogeneous AI deployments combining Intel + Qualcomm + NVIDIA accelerators. See [QNN_INTEGRATION.md](docs/QNN_INTEGRATION.md) and [NVIDIA_INTEGRATION.md](docs/NVIDIA_INTEGRATION.md) for details.

## 🎯 AVX2-First Architecture

**IMPORTANT**: HARDVINO uses an **AVX2-first workflow** optimized for Meteor Lake processors.

- ✅ **Optimized for**: AVX2 + AVX-VNNI (AI/ML acceleration)
- ❌ **NOT using**: AVX-512 (not supported on Meteor Lake hardware)
- ⚡ **Performance**: Optimal power efficiency and thermal characteristics
- 📚 **Documentation**: See `AVX2_FIRST_WORKFLOW.md` for complete details

### Why AVX2-First?

Intel Meteor Lake (Core Ultra 7 165H) provides **AVX-VNNI** on AVX2 width, delivering:
- INT8 VNNI operations for neural network acceleration
- Better sustained performance (no thermal throttling)
- Lower power consumption vs hypothetical AVX-512
- Optimal for 6P+10E hybrid architecture

**Quick Start**: The default configuration is already optimal - no changes needed!

## Features

### Security Hardening (ImageHarden-Inspired)

- **Compile-Time Hardening**
  - `_FORTIFY_SOURCE=3` - Advanced buffer overflow detection
  - Stack protectors (strong + clash protection)
  - Control-Flow Integrity (CFI) with CET - Spectre/Meltdown mitigation
  - Full RELRO + PIE
  - Position Independent Code (PIC)

- **Runtime Hardening**
  - Kernel-space sandboxing ready
  - Secure NPU device access
  - DMA isolation
  - Firmware validation

### Performance Optimization (AVX2-First)

- **Meteor Lake Specific**
  - Native `-march=meteorlake` tuning
  - Hybrid core awareness (6P + 10E)
  - **AVX2 + AVX-VNNI** optimizations (primary SIMD path)
  - AES-NI, SHA, GFNI cryptographic acceleration
  - BMI, BMI2 bit manipulation
  - Link-Time Optimization (LTO)
  - **AVX-512 explicitly disabled** (not supported on Meteor Lake)

- **NPU VPU 3720 Military Mode**
  - 1.85 GHz turbo frequency
  - 2 Neural Compute Engines
  - 4MB CMX memory optimization
  - 68 GB/s DDR bandwidth
  - 4 DPU groups, 4 DMA engines
  - INT4/FP8 quantization support
  - Batch size override: 256
  - Async inference queue: 64

### Components

#### Intel AI Stack (Core)

- **OpenVINO** - AI inference framework with NPU support
- **oneTBB** - Threading Building Blocks
- **oneDNN** - Deep Neural Network Library
- **Level-Zero** - Low-level GPU/NPU interface (optional)

#### Multi-Vendor AI Stack (Optional)

- **Qualcomm QNN SDK** - AI Engine Direct for Qualcomm NPUs, Hexagon DSPs, and Cloud AI 100 accelerators
  - **Installation**: Manual (closed-source, requires Qualcomm Developer Portal access)
  - **Documentation**: [docs/QNN_INTEGRATION.md](docs/QNN_INTEGRATION.md)
  - **Security**: Hardened installation with systemd confinement and service account isolation
  - **Use Cases**: Multi-vendor inference, Snapdragon edge devices, Cloud AI 100 accelerators

- **NVIDIA GPU Modules** - Open-source kernel drivers for NVIDIA GPUs (Turing and newer)
  - **Installation**: Git submodule (open-source, built with HARDVINO hardening)
  - **Documentation**: [docs/NVIDIA_INTEGRATION.md](docs/NVIDIA_INTEGRATION.md)
  - **Security**: CET/CFI, FORTIFY=3, module signing for Secure Boot, IOMMU isolation
  - **Use Cases**: CUDA ML training, GPU compute, hybrid rendering, heterogeneous AI

## Multi-Vendor AI Support

HARDVINO supports heterogeneous AI deployments combining Intel, Qualcomm, and NVIDIA accelerators:

- **Intel NPU (VPU 3720)** - Primary on-die accelerator for Meteor Lake
- **Intel iGPU (Xe-LPG)** - Integrated graphics for compute workloads
- **Qualcomm QNN** - Optional external SDK for Qualcomm AI hardware
- **NVIDIA GPU** - Optional CUDA-capable GPUs (RTX 20/30/40 series, A100, H100, etc.)

**Setup**:
```bash
# 1. Build Intel stack (standard)
./build_all.sh

# 2. Build NVIDIA GPU drivers (if you have NVIDIA GPU)
./scripts/build_nvidia.sh --all

# 3. Install Qualcomm QNN SDK (manual - see docs)
# Follow: docs/QNN_INTEGRATION.md for hardened installation

# 4. Verify installations
./scripts/build_nvidia.sh --verify
./scripts/build_qnn.sh --verbose

# 5. Use all accelerators in your application
# Intel NPU: via OpenVINO NPU backend
# Intel iGPU: via OpenVINO GPU backend
# NVIDIA GPU: via CUDA/PyTorch
# Qualcomm: via QNN SDK APIs
```

**Security Notes**:
- **QNN SDK** (closed-source): Service account isolation, systemd hardening, network isolation
- **NVIDIA Modules** (open-source): CET/CFI hardening, module signing (MOK), IOMMU isolation, render group restrictions

See [docs/QNN_INTEGRATION.md](docs/QNN_INTEGRATION.md) and [docs/NVIDIA_INTEGRATION.md](docs/NVIDIA_INTEGRATION.md) for complete security hardening guides.

## System Requirements

### Hardware
- Intel Core Ultra 7 165H (Meteor Lake) or compatible
- NPU VPU 3720 (Intel AI Boost)
- Minimum 16GB RAM
- 50GB free disk space for build

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

This build system follows the licenses of its components:
- OpenVINO: Apache 2.0
- oneTBB: Apache 2.0
- oneDNN: Apache 2.0

Build scripts and configuration: MIT License

## References

### Intel Stack Documentation

- [OpenVINO Documentation](https://docs.openvino.ai/)
- [Intel NPU Acceleration Library](https://intel.github.io/intel-npu-acceleration-library/)
- [oneAPI Documentation](https://www.intel.com/content/www/us/en/developer/tools/oneapi/overview.html)
- [Intel Meteor Lake Architecture](https://www.intel.com/content/www/us/en/products/docs/processors/core-ultra/meteor-lake-architecture-overview.html)

### Multi-Vendor AI Documentation

- [Qualcomm AI Engine Direct (QNN SDK)](https://developer.qualcomm.com/software/qualcomm-ai-engine-direct-sdk)
- [QNN Integration Guide (HARDVINO)](docs/QNN_INTEGRATION.md)
- [NVIDIA Open GPU Kernel Modules](https://github.com/NVIDIA/open-gpu-kernel-modules)
- [NVIDIA Integration Guide (HARDVINO)](docs/NVIDIA_INTEGRATION.md)
- [NVIDIA Driver Documentation](https://docs.nvidia.com/)
- [CUDA Toolkit](https://developer.nvidia.com/cuda-toolkit)
- [Intel Stack Manifest](intel_stack.manifest.yml)

### Security & Hardening

- [ImageHarden Security Principles](https://github.com/yourusername/ImageHarden)
- [Systemd Security Hardening](https://www.freedesktop.org/software/systemd/man/systemd.exec.html)

## Support & Contributing

For issues, questions, or contributions:
- GitHub Issues: https://github.com/SWORDIntel/HARDVINO/issues
- Pull Requests welcome

## Security Disclosure

For security vulnerabilities, please contact privately before public disclosure.

## Acknowledgments

- Based on ImageHarden security hardening principles
- Intel OpenVINO team for NPU support
- NVIDIA for open-source GPU kernel modules
- Qualcomm for AI Engine Direct SDK
- Meteor Lake optimization research by KYBERLOCK Tactical Computing Division

---

**HARDVINO** - Hardened multi-vendor AI inference for mission-critical applications.

Built with military-grade security for Intel Meteor Lake NPU VPU 3720 + NVIDIA GPUs + Qualcomm accelerators.
