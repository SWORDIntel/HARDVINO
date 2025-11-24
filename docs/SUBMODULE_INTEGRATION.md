# HARDVINO Submodule Integration Guide

This document explains how to integrate HARDVINO as a submodule into larger projects (e.g., DSMIL).

---

## Quick Start

```bash
# In your parent project
git submodule add https://github.com/SWORDIntel/HARDVINO.git hardvino
cd hardvino
./scripts/integrate.sh --init
./scripts/integrate.sh --build
```

---

## Integration Steps

### 1. Add HARDVINO as Submodule

```bash
# From your parent project root
git submodule add https://github.com/SWORDIntel/HARDVINO.git hardvino
```

### 2. Initialize Submodules

```bash
# Initialize HARDVINO and its dependencies
./hardvino/scripts/integrate.sh --init
```

This initializes:
- **Core**: OpenVINO, oneTBB, oneDNN, NUC2.1
- **Extended**: GPU compute, media drivers, QAT, tools (shallow clones)

### 3. Build HARDVINO

```bash
# Build core components
./hardvino/scripts/integrate.sh --build

# Or build everything including extended Intel stack
./hardvino/scripts/integrate.sh --build-all
```

### 4. CMake Integration

Generate CMake configuration for your parent project:

```bash
./hardvino/scripts/integrate.sh --cmake
```

Then in your parent `CMakeLists.txt`:

```cmake
# Include HARDVINO configuration
include(hardvino/cmake/HARDVINOConfig.cmake)

# Link your targets
add_executable(myapp main.cpp)
target_link_hardvino(myapp)
```

### 5. Environment Setup

For shell usage:

```bash
# Source HARDVINO environment
source hardvino/install/setupvars.sh

# Or source the Intel flags
source hardvino/scripts/intel_env.sh
```

---

## Directory Structure

After initialization:

```
parent-project/
├── hardvino/                           # HARDVINO submodule
│   ├── openvino/                       # Core: OpenVINO
│   ├── oneapi-tbb/                     # Core: oneTBB
│   ├── oneapi-dnn/                     # Core: oneDNN
│   ├── NUC2.1/                         # Core: Movidius VPU
│   ├── submodules/
│   │   └── intel-stack/
│   │       ├── runtimes/
│   │       │   ├── gpu-compute/        # compute-runtime, IGC
│   │       │   ├── media/              # media-driver, vaapi
│   │       │   └── qat/                # qatlib, QAT_Engine
│   │       ├── toolchains/
│   │       │   └── oneapi-libs/        # oneDAL
│   │       └── tools/                  # PerfSpect, neural-compressor, etc.
│   ├── scripts/
│   │   ├── intel_env.sh                # Environment flags
│   │   ├── build_intel_stack.sh        # Extended build
│   │   └── integrate.sh                # Integration helper
│   ├── cmake/
│   │   └── HARDVINOConfig.cmake        # CMake config (generated)
│   ├── docs/
│   │   ├── MASTER_PROMPT.md            # AI system prompt
│   │   ├── KERNEL_CONFIG.md            # Kernel config flags
│   │   └── SUBMODULE_INTEGRATION.md    # This file
│   ├── intel_stack.manifest.yml        # Component manifest
│   └── install/                        # Built artifacts
└── CMakeLists.txt                      # Your parent project
```

---

## Available Commands

```bash
./hardvino/scripts/integrate.sh --help
```

| Command | Description |
|---------|-------------|
| `--init` | Initialize all submodules |
| `--build` | Build HARDVINO core |
| `--build-all` | Build core + extended stack |
| `--cmake` | Generate CMake configuration |
| `--env` | Print environment variables |
| `--check` | Check installation status |

---

## Building Extended Components

After core is built, you can optionally build extended Intel components:

```bash
# Build all extended components
./hardvino/scripts/build_intel_stack.sh --all

# Or selectively
./hardvino/scripts/build_intel_stack.sh --gpu      # Level Zero, OpenCL
./hardvino/scripts/build_intel_stack.sh --media    # VAAPI drivers
./hardvino/scripts/build_intel_stack.sh --qat      # QAT crypto/compression
./hardvino/scripts/build_intel_stack.sh --tools    # oneDAL, Open3D
```

---

## CMake Usage Examples

### Basic Usage

```cmake
include(hardvino/cmake/HARDVINOConfig.cmake)

add_executable(inference_app inference.cpp)
target_link_hardvino(inference_app)
```

### Manual Linking

```cmake
include(hardvino/cmake/HARDVINOConfig.cmake)

add_executable(my_npu_app npu_inference.cpp)

# Link specific libraries
if(OpenVINO_FOUND)
    target_link_libraries(my_npu_app PRIVATE openvino::runtime)
endif()

if(TBB_FOUND)
    target_link_libraries(my_npu_app PRIVATE TBB::tbb)
endif()

# Apply Meteor Lake optimization flags
target_compile_options(my_npu_app PRIVATE ${HARDVINO_C_FLAGS})
```

### Using HARDVINO Flags

```cmake
# Meteor Lake optimized flags
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${HARDVINO_C_FLAGS}")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${HARDVINO_CXX_FLAGS}")

# Security hardening
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${HARDVINO_HARDENING_FLAGS}")
```

---

## Environment Variables

After sourcing `scripts/intel_env.sh`:

| Variable | Description |
|----------|-------------|
| `CFLAGS_OPTIMAL` | Meteor Lake optimized C flags |
| `LDFLAGS_OPTIMAL` | Optimized linker flags |
| `CFLAGS` | Optimal + hardening flags |
| `KCFLAGS` | Kernel compilation flags |
| `RUSTFLAGS` | Rust compilation flags |
| `OV_NPU_*` | OpenVINO NPU configuration |

---

## Updating HARDVINO

```bash
cd hardvino
git pull origin main
git submodule update --recursive
./scripts/integrate.sh --build
```

---

## Troubleshooting

### Check Status

```bash
./hardvino/scripts/integrate.sh --check
```

### Rebuild Clean

```bash
cd hardvino
./build_all.sh --clean
```

### Missing Dependencies

```bash
./hardvino/scripts/build_intel_stack.sh --install-deps
```

---

## Related Documentation

- [Master Prompt](MASTER_PROMPT.md) - AI system integration prompt
- [Kernel Config](KERNEL_CONFIG.md) - Kernel configuration flags
- [Component Manifest](../intel_stack.manifest.yml) - Full component list
