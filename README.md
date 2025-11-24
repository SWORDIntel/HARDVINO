# HARDVINO

**Hardened OpenVINO/OneAPI Build System for Intel Meteor Lake with NPU VPU 3720 Support + Multi-Vendor AI Stack**

HARDVINO is a comprehensive, security-hardened build system for OpenVINO and OneAPI libraries, specifically optimized for the Intel Core Ultra 7 165H (Meteor Lake) with military-grade NPU support. This repository is designed to be integrated as a submodule into kernel compilation suites, providing hardened AI inference capabilities directly in kernel space.

**Multi-Vendor Support**: HARDVINO now supports Qualcomm AI Engine Direct (QNN SDK) for heterogeneous AI deployments combining Intel + Qualcomm accelerators. See [QNN_INTEGRATION.md](docs/QNN_INTEGRATION.md) for details.

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

## Multi-Vendor AI Support

HARDVINO supports heterogeneous AI deployments combining Intel and Qualcomm accelerators:

- **Intel NPU (VPU 3720)** - Primary on-die accelerator for Meteor Lake
- **Intel iGPU (Xe-LPG)** - Integrated graphics for compute workloads
- **Qualcomm QNN** - Optional external SDK for Qualcomm AI hardware

**Setup**:
```bash
# 1. Build Intel stack (standard)
./build_all.sh

# 2. Install Qualcomm QNN SDK (manual - see docs)
# Follow: docs/QNN_INTEGRATION.md for hardened installation

# 3. Verify QNN installation
./scripts/build_qnn.sh --verbose

# 4. Use both accelerators in your application
# Intel: via OpenVINO
# Qualcomm: via QNN SDK APIs
```

**Security Note**: QNN SDK is closed-source. HARDVINO provides hardened installation procedures with:
- Service account isolation (`qnnsvc:qnnsvc`)
- Filesystem permissions (`0750 root:qnnsvc`)
- Systemd hardening (`NoNewPrivileges`, `ProtectSystem=strict`, `MemoryDenyWriteExecute`)
- Network isolation (optional `IPAddressDeny`)

See [docs/QNN_INTEGRATION.md](docs/QNN_INTEGRATION.md) for complete security hardening guide.

## System Requirements

### Hardware
- Intel Core Ultra 7 165H (Meteor Lake) or compatible
- NPU VPU 3720 (Intel AI Boost)
- Minimum 16GB RAM
- 50GB free disk space for build

### Software
- Debian-based Linux (Ubuntu 22.04+ recommended)
- Kernel 6.2+ (for NPU support)
- GCC 13+ or Clang 14+ (GCC 15 recommended, auto-installed if missing)
- CMake 3.20+
- Python 3.8+
- Git

### Build Dependencies
```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    git \
    cmake \
    ninja-build \
    python3 \
    python3-pip \
    python3-dev \
    pkg-config \
    autoconf \
    automake \
    libtool \
    libssl-dev \
    libusb-1.0-0-dev \
    checksec
```

**Note:** GCC 15 will be automatically installed during the build if not already present. Alternatively, you can pre-install:
```bash
sudo apt-get install -y gcc-15 g++-15 gcc-ar-15 gcc-nm-15 gcc-ranlib-15
```

## Quick Start

### Standalone Build

```bash
# Clone the repository
git clone https://github.com/SWORDIntel/HARDVINO.git
cd HARDVINO

# Initialize submodules
git submodule update --init --recursive

# Build everything
./build_all.sh

# Set up environment
source install/setupvars.sh

# Initialize NPU
init_npu_tactical

# Test NPU
test_npu_military
```

### As Kernel Submodule

```bash
# In your kernel source directory
git submodule add https://github.com/SWORDIntel/HARDVINO.git hardvino
cd hardvino
git submodule update --init --recursive

# Build HARDVINO
./build_all.sh

# Integrate with kernel build
export HARDVINO_ROOT=$(pwd)
# See KERNEL_INTEGRATION.md for detailed instructions
```

## Build System

### Master Build Script

`./build_all.sh` - Builds complete HARDVINO suite

**Options:**
- `--clean` - Clean build (remove existing build directories)
- `--skip-oneapi` - Skip OneAPI build
- `--skip-openvino` - Skip OpenVINO build
- `--skip-kernel` - Skip kernel integration setup
- `--verbose` - Verbose output

**Examples:**
```bash
./build_all.sh                # Build everything
./build_all.sh --clean        # Clean build
./build_all.sh --skip-oneapi  # Build only OpenVINO
```

### Individual Build Scripts

- `build_hardened_oneapi.sh` - Build oneTBB and oneDNN
- `build_hardened_openvino.sh` - Build OpenVINO with NPU support
- `kernel_integration.sh` - Set up kernel integration files

### Configuration Scripts

- `npu_military_config.sh` - NPU tactical configuration
- `meteor_lake_flags_ultimate/` - Complete compiler optimization flags

## NPU Configuration

### Tactical Mode Initialization

```bash
# Source environment
source install/setupvars.sh

# Initialize NPU in tactical mode
init_npu_tactical

# Output:
# 🔴 INITIALIZING NPU TACTICAL MODE...
# ✓ NPU WEAPONIZED
```

### NPU Testing

```bash
# Test NPU with OpenVINO
test_npu_military

# Expected output:
# 🎯 NPU ONLINE - VPU 3720 READY FOR COMBAT
# 🔫 NPU DESIGNATION: Intel(R) AI Boost
# 🚀 NPU INFERENCE ENGINE: ARMED
# ⚡ NEURAL COMPUTE ENGINES: 2x ACTIVE
# 💾 CMX MEMORY: 4MB ALLOCATED
# 🎖️ TACTICAL MODE: ENGAGED
```

### NPU Benchmarking

```bash
# Display NPU benchmark info
benchmark_npu_military
```

## Kernel Integration

HARDVINO is designed to be integrated into kernel compilation suites. See [KERNEL_INTEGRATION.md](KERNEL_INTEGRATION.md) for comprehensive guide.

### Quick Integration

```makefile
# In your kernel Makefile
HARDVINO_ROOT := $(srctree)/hardvino
export HARDVINO_ROOT

include $(HARDVINO_ROOT)/Kbuild.mk

KBUILD_CFLAGS += $(HARDVINO_KCFLAGS)
```

### Example Kernel Module

See `example_module/` for a complete example of using HARDVINO in kernel space.

```bash
cd example_module
make
sudo insmod hardvino_example.ko
dmesg | tail
```

## Security Features

### Compile-Time Hardening Flags

Based on ImageHarden security principles:

```bash
# Complete hardening flags
-D_FORTIFY_SOURCE=3
-fstack-protector-strong
-fstack-clash-protection
-fcf-protection=full
-fPIE -pie
-Wl,-z,relro,-z,now
-Wl,-z,noexecstack
-Wl,-z,separate-code
```

### Binary Verification

```bash
# Check security hardening in built libraries
checksec --file=install/openvino/lib/libopenvino.so

# Expected output:
# RELRO:    FULL RELRO
# Stack:    Canary found
# NX:       NX enabled
# PIE:      PIE enabled
# FORTIFY:  Enabled
```

### NPU Security

- Firmware path validation
- Secure DMA access
- CMX memory isolation
- Kernel bypass prevention (controlled)
- Device permission management

## Architecture Optimization

### Meteor Lake Features

```bash
# Architecture flags
-march=meteorlake -mtune=meteorlake

# Or fallback
-march=alderlake -mtune=alderlake

# Or native detection
-march=native -mtune=native
```

### Instruction Set Extensions (AVX2-First)

- **SSE/AVX**: SSE4.2, AVX, AVX2, FMA, F16C
- **AI/ML**: **AVX-VNNI** (Vector Neural Network Instructions) ⭐ Primary ML acceleration
- **Cryptographic**: AES, VAES, PCLMUL, VPCLMULQDQ, SHA, GFNI
- **Bit Manipulation**: BMI, BMI2, LZCNT, POPCNT
- **Memory**: MOVBE, MOVDIRI, MOVDIR64B, CLFLUSHOPT, CLWB, CLDEMOTE
- **Advanced**: ADX, RDRND, RDSEED, FSGSBASE, XSAVE family
- **Control Flow**: WAITPKG, UINTR, SERIALIZE, TSXLDTRK
- **Security**: CET, SHSTK (Control-flow Enforcement Technology)
- **NOT SUPPORTED**: AVX-512F, AVX-512BW, AVX-512DQ (not available on Meteor Lake)

## Performance Tuning

### P-Core Affinity (6 Performance Cores)

```bash
export GOMP_CPU_AFFINITY="0-5"
export OMP_NUM_THREADS="6"
export OMP_PROC_BIND="true"
export OMP_PLACES="cores"
```

### NPU Power Mode

```bash
export OV_NPU_POWER_MODE=MAXIMUM_PERFORMANCE
export OV_NPU_PERFORMANCE_HINT=LATENCY
export OV_NPU_THERMAL_THROTTLE_LEVEL=DISABLED
export OV_NPU_TURBO_MODE=ENABLED
```

### Memory Optimization

```bash
export MALLOC_ARENA_MAX="4"
export MALLOC_MMAP_THRESHOLD_="131072"
export OV_NPU_MEMORY_POOL_SIZE=2048MB
```

## Environment Variables

### Compiler Flags (Auto-configured)

- `CFLAGS_OPTIMAL` - Optimal C flags
- `CXXFLAGS_OPTIMAL` - Optimal C++ flags
- `LDFLAGS_OPTIMAL` - Optimal linker flags
- `CFLAGS_NPU_HARDENED` - NPU + hardening flags
- `KCFLAGS` - Kernel compilation flags

### OpenVINO NPU Runtime

- `OV_NPU_COMPILER_TYPE=DRIVER`
- `OV_NPU_PLATFORM=3720`
- `OV_NPU_DEVICE_ID=0x7D1D`
- `OV_NPU_MAX_TILES=2`
- `OV_NPU_DPU_GROUPS=4`
- `OV_NPU_DMA_ENGINES=4`

### Build System

- `HARDVINO_ROOT` - HARDVINO installation path
- `OPENVINO_INSTALL_DIR` - OpenVINO installation
- `TBB_DIR` - oneTBB directory
- `DNNL_DIR` - oneDNN directory

## Troubleshooting

### NPU Not Detected

```bash
# Check NPU device
ls -la /dev/accel/accel0

# Load NPU module
sudo modprobe intel_vpu

# Check module loaded
lsmod | grep intel_vpu

# Check firmware
ls -la /lib/firmware/intel/vpu/vpu_3720.bin
```

### Build Failures

```bash
# Clean rebuild
./build_all.sh --clean

# Verify submodules
git submodule status
git submodule update --init --recursive

# Check dependencies
gcc --version  # Should be 11+
cmake --version  # Should be 3.20+
```

### Permission Issues

```bash
# NPU device permissions
sudo chmod 666 /dev/accel/accel0
sudo chown $USER:render /dev/accel/accel0

# Or add user to render group
sudo usermod -a -G render $USER
```

## Directory Structure

```
HARDVINO/
├── build/                          # Build artifacts (generated)
├── install/                        # Installation directory (generated)
│   ├── openvino/                  # OpenVINO installation
│   ├── oneapi-tbb/                # oneTBB installation
│   ├── oneapi-dnn/                # oneDNN installation
│   └── setupvars.sh               # Environment setup script
├── openvino/                      # OpenVINO submodule
├── oneapi-tbb/                    # oneTBB submodule
├── oneapi-dnn/                    # oneDNN submodule
├── meteor_lake_flags_ultimate/    # Compiler optimization flags (AVX2-first)
├── example_module/                # Example kernel module (generated)
├── build_all.sh                   # Master build script
├── build_hardened_openvino.sh     # OpenVINO build script (AVX2-first)
├── build_hardened_oneapi.sh       # OneAPI build script (AVX2-first)
├── kernel_integration.sh          # Kernel integration setup
├── npu_military_config.sh         # NPU configuration
├── AVX2_FIRST_WORKFLOW.md         # ⭐ AVX2-first architecture guide
├── AVX2_OPTIMIZATION_QUICK_GUIDE.md  # ⭐ Quick optimization reference
├── kernel_config.mk               # Kernel build config (generated)
├── Kbuild.mk                      # Kernel Makefile integration (generated)
├── KERNEL_INTEGRATION.md          # Kernel integration guide (generated)
└── README.md                      # This file
```

## Use Cases

### 1. AI-Accelerated Kernel Module

Build kernel modules that leverage OpenVINO inference with NPU acceleration:

```c
#include <linux/module.h>
#include <openvino/c/openvino.h>

// AI inference in kernel space
```

### 2. Hardened AI Inference

Run AI models with military-grade security hardening:

```python
import openvino as ov
core = ov.Core()
# Hardened inference with NPU
```

### 3. Embedded Kernel AI

Integrate HARDVINO into custom embedded kernels for edge AI:

```bash
# In custom kernel build
export HARDVINO_ROOT=/path/to/hardvino
make -j$(nproc) KCFLAGS="$(HARDVINO_KCFLAGS)"
```

## Performance Characteristics

### NPU VPU 3720 Specifications

- **Frequency**: 1.85 GHz (Turbo)
- **Compute Engines**: 2 Neural Compute Engines
- **SHAVE Processors**: 8
- **CMX Memory**: 4MB
- **L2 Cache**: 2.5MB
- **DDR Bandwidth**: 68 GB/s
- **Supported Operations**:
  - INT4, INT8, FP16, FP8 (experimental)
  - Convolution, Pooling, Activation
  - Batch normalization, Element-wise ops
  - Multi-stream: 16 concurrent

### Build Times (6P+10E Cores)

- oneTBB: ~5 minutes
- oneDNN: ~10 minutes
- OpenVINO: ~45-60 minutes (full build)
- Total: ~1 hour (clean build)

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
- Meteor Lake optimization research by KYBERLOCK Tactical Computing Division

---

**HARDVINO** - Hardened AI inference for mission-critical applications.

Built with military-grade security for Intel Meteor Lake NPU VPU 3720.
