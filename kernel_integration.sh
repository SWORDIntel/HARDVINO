#!/bin/bash
# ============================================================================
# HARDVINO - Kernel Integration Script
# Prepares HARDVINO for kernel compilation as submodule
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PREFIX="${SCRIPT_DIR}/install"

# Source configurations
source "${SCRIPT_DIR}/npu_military_config.sh"

# ============================================================================
# COLOR OUTPUT
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_kernel() {
    echo -e "${BLUE}[KERNEL]${NC} $1"
}

# ============================================================================
# KERNEL CONFIGURATION EXPORT
# ============================================================================

export_kernel_config() {
    log_kernel "Exporting kernel configuration..."

    local config_file="${SCRIPT_DIR}/kernel_config.mk"

    cat > "${config_file}" << EOF
# ============================================================================
# HARDVINO Kernel Configuration
# Auto-generated kernel build configuration
# ============================================================================

# Installation paths
HARDVINO_ROOT := ${SCRIPT_DIR}
HARDVINO_INSTALL := ${INSTALL_PREFIX}
OPENVINO_ROOT := \$(HARDVINO_INSTALL)/openvino
ONETBB_ROOT := \$(HARDVINO_INSTALL)/oneapi-tbb
ONEDNN_ROOT := \$(HARDVINO_INSTALL)/oneapi-dnn

# Compiler flags from Meteor Lake configuration
HARDVINO_CFLAGS := ${CFLAGS_NPU_HARDENED}
HARDVINO_LDFLAGS := ${LDFLAGS_NPU_HARDENED}

# Kernel-specific flags
HARDVINO_KCFLAGS := ${KCFLAGS}

# NPU configuration
HARDVINO_NPU_FLAGS := ${NPU_MILITARY_FLAGS}

# Include paths
HARDVINO_INCLUDES := -I\$(OPENVINO_ROOT)/runtime/include \\
                     -I\$(ONETBB_ROOT)/include \\
                     -I\$(ONEDNN_ROOT)/include

# Library paths
HARDVINO_LIBDIRS := -L\$(OPENVINO_ROOT)/runtime/lib/intel64 \\
                    -L\$(OPENVINO_ROOT)/lib \\
                    -L\$(ONETBB_ROOT)/lib \\
                    -L\$(ONEDNN_ROOT)/lib

# Libraries to link
HARDVINO_LIBS := -lopenvino -lopenvino_c -ltbb -ldnnl

# Export for use in kernel Makefile
export HARDVINO_ROOT
export HARDVINO_CFLAGS
export HARDVINO_LDFLAGS
export HARDVINO_KCFLAGS
export HARDVINO_INCLUDES
export HARDVINO_LIBDIRS
export HARDVINO_LIBS

.PHONY: hardvino-info
hardvino-info:
	@echo "HARDVINO Configuration:"
	@echo "  Root: \$(HARDVINO_ROOT)"
	@echo "  Install: \$(HARDVINO_INSTALL)"
	@echo "  OpenVINO: \$(OPENVINO_ROOT)"
	@echo "  Flags: \$(HARDVINO_CFLAGS)"
EOF

    log_info "Kernel configuration exported to ${config_file}"
}

# ============================================================================
# CREATE KERNEL MAKEFILE INTEGRATION
# ============================================================================

create_kernel_makefile() {
    log_kernel "Creating kernel Makefile integration..."

    local makefile="${SCRIPT_DIR}/Kbuild.mk"

    cat > "${makefile}" << 'EOF'
# ============================================================================
# HARDVINO Kernel Build Integration
# Include this in your kernel build system
# ============================================================================

# Include HARDVINO configuration
include $(HARDVINO_ROOT)/kernel_config.mk

# Add HARDVINO flags to kernel build
ccflags-y += $(HARDVINO_INCLUDES)
ccflags-y += -DHARDVINO_ENABLED=1
ccflags-y += -DNPU_VPU3720_SUPPORT=1

# Add to module flags
KBUILD_CFLAGS += $(HARDVINO_KCFLAGS)

# Example module using HARDVINO
# obj-$(CONFIG_HARDVINO) += hardvino_module.o
# hardvino_module-y := hardvino_core.o hardvino_npu.o

.PHONY: hardvino-kernel-help
hardvino-kernel-help:
	@echo "HARDVINO Kernel Integration"
	@echo "=============================="
	@echo ""
	@echo "To use HARDVINO in your kernel build:"
	@echo "  1. Include this file in your kernel Makefile:"
	@echo "     include path/to/HARDVINO/Kbuild.mk"
	@echo ""
	@echo "  2. Set HARDVINO_ROOT environment variable:"
	@echo "     export HARDVINO_ROOT=/path/to/HARDVINO"
	@echo ""
	@echo "  3. Build kernel with HARDVINO flags:"
	@echo "     make -j\$$(nproc) KCFLAGS=\"\$$(HARDVINO_KCFLAGS)\""
	@echo ""
	@echo "Available configurations:"
	@echo "  HARDVINO_INCLUDES: $(HARDVINO_INCLUDES)"
	@echo "  HARDVINO_LIBDIRS:  $(HARDVINO_LIBDIRS)"
	@echo "  HARDVINO_LIBS:     $(HARDVINO_LIBS)"
EOF

    log_info "Kernel Makefile created: ${makefile}"
}

# ============================================================================
# CREATE EXAMPLE KERNEL MODULE
# ============================================================================

create_example_module() {
    log_kernel "Creating example kernel module..."

    local module_dir="${SCRIPT_DIR}/example_module"
    mkdir -p "${module_dir}"

    # Create module source
    cat > "${module_dir}/hardvino_example.c" << 'EOF'
/*
 * HARDVINO Example Kernel Module
 * Demonstrates integration of hardened OpenVINO in kernel space
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>

#ifdef HARDVINO_ENABLED
#include <linux/accel.h>  // For NPU device access
#endif

MODULE_LICENSE("GPL");
MODULE_AUTHOR("HARDVINO");
MODULE_DESCRIPTION("Hardened OpenVINO Kernel Integration Example");
MODULE_VERSION("1.0");

static int __init hardvino_init(void)
{
    printk(KERN_INFO "HARDVINO: Initializing hardened OpenVINO module\n");

#ifdef NPU_VPU3720_SUPPORT
    printk(KERN_INFO "HARDVINO: NPU VPU 3720 support enabled\n");
#endif

    printk(KERN_INFO "HARDVINO: Module loaded successfully\n");
    return 0;
}

static void __exit hardvino_exit(void)
{
    printk(KERN_INFO "HARDVINO: Module unloaded\n");
}

module_init(hardvino_init);
module_exit(hardvino_exit);
EOF

    # Create module Makefile
    cat > "${module_dir}/Makefile" << 'EOF'
# HARDVINO Example Module Makefile

obj-m += hardvino_example.o

KDIR ?= /lib/modules/$(shell uname -r)/build

# Include HARDVINO configuration
HARDVINO_ROOT ?= $(PWD)/..
include $(HARDVINO_ROOT)/kernel_config.mk

# Add HARDVINO flags
ccflags-y += $(HARDVINO_INCLUDES)
ccflags-y += -DHARDVINO_ENABLED=1
ccflags-y += -DNPU_VPU3720_SUPPORT=1

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules KCFLAGS="$(HARDVINO_KCFLAGS)"

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

install:
	$(MAKE) -C $(KDIR) M=$(PWD) modules_install

load:
	sudo insmod hardvino_example.ko

unload:
	sudo rmmod hardvino_example

.PHONY: all clean install load unload
EOF

    # Create README for the module
    cat > "${module_dir}/README.md" << 'EOF'
# HARDVINO Example Kernel Module

This is an example kernel module demonstrating HARDVINO integration.

## Building

```bash
cd example_module
make
```

## Loading

```bash
make load
```

## Checking logs

```bash
dmesg | tail -20
```

## Unloading

```bash
make unload
```

## Integration in Your Kernel

To integrate HARDVINO into your custom kernel:

1. Add HARDVINO as a submodule to your kernel source
2. Include the Kbuild.mk file in your kernel Makefile
3. Build your kernel with HARDVINO flags enabled

See parent directory's kernel_integration.sh for details.
EOF

    log_info "Example module created in ${module_dir}"
}

# ============================================================================
# CREATE INTEGRATION GUIDE
# ============================================================================

create_integration_guide() {
    log_kernel "Creating kernel integration guide..."

    local guide="${SCRIPT_DIR}/KERNEL_INTEGRATION.md"

    cat > "${guide}" << 'EOF'
# HARDVINO Kernel Integration Guide

This guide explains how to integrate HARDVINO as a submodule in your kernel compilation suite.

## Overview

HARDVINO provides a hardened build of OpenVINO and OneAPI libraries optimized for:
- Intel Meteor Lake architecture (VPU 3720 NPU)
- Military-grade security hardening
- Kernel-space integration
- Maximum performance with security

## Integration Steps

### 1. Add as Submodule to Kernel Source

```bash
cd /path/to/your/kernel/source
git submodule add https://github.com/SWORDIntel/HARDVINO.git hardvino
git submodule update --init --recursive
```

### 2. Build HARDVINO Libraries

```bash
cd hardvino
./build_all.sh
```

This will build:
- OpenVINO with NPU support
- oneTBB (Threading Building Blocks)
- oneDNN (Deep Neural Network Library)

All libraries are built with:
- Meteor Lake optimization flags
- NPU VPU 3720 support
- Security hardening (FORTIFY_SOURCE=3, stack protectors, CFI, etc.)

### 3. Include in Kernel Build

#### Option A: Makefile Integration

Add to your kernel's top-level Makefile:

```makefile
# HARDVINO Integration
HARDVINO_ROOT := $(srctree)/hardvino
export HARDVINO_ROOT

include $(HARDVINO_ROOT)/kernel_config.mk

# Add HARDVINO flags to kernel build
KBUILD_CFLAGS += $(HARDVINO_KCFLAGS)
```

#### Option B: Kconfig Integration

Add to your kernel configuration:

```kconfig
config HARDVINO
    bool "Enable HARDVINO (Hardened OpenVINO)"
    depends on X86_64
    help
      Enable hardened OpenVINO libraries with NPU support.
      This adds OpenVINO inference capabilities to the kernel
      with military-grade security hardening.
```

### 4. Use HARDVINO in Kernel Modules

```c
#include <linux/module.h>

#ifdef CONFIG_HARDVINO
#include <openvino/c/openvino.h>
#endif

static int __init my_module_init(void)
{
#ifdef CONFIG_HARDVINO
    // Use OpenVINO inference in kernel space
    ov_core_t* core;
    ov_core_create(&core);
    // ... your inference code ...
    ov_core_free(core);
#endif
    return 0;
}
```

## Security Hardening Features

HARDVINO applies the following hardening measures (based on ImageHarden principles):

### Compile-Time Hardening
- `-D_FORTIFY_SOURCE=3` - Buffer overflow protection
- `-fstack-protector-strong` - Stack canaries
- `-fstack-clash-protection` - Stack clash protection
- `-fcf-protection=full` - Control-flow integrity and Spectre v2 mitigation via CET
- `-fPIE -pie` - Position independent executable
- Full RELRO (`-Wl,-z,relro,-z,now`)

### Architecture Optimization
- Meteor Lake specific tuning (`-march=meteorlake`)
- AVX2, AVX-VNNI, AES-NI, SHA extensions
- NPU VPU 3720 optimizations
- 6P+10E core awareness

### NPU Security
- Firmware validation
- DMA isolation
- CMX memory protection
- Secure command queues

## NPU Configuration

The NPU is configured for maximum performance with security:

```bash
# Initialize NPU in tactical mode
source hardvino/install/setupvars.sh
init_npu_tactical

# Test NPU functionality
test_npu_military
```

## Environment Variables

Set these before kernel compilation:

```bash
export HARDVINO_ROOT=/path/to/hardvino
source $HARDVINO_ROOT/npu_military_config.sh
```

Key variables:
- `CFLAGS_NPU_HARDENED` - Complete compilation flags
- `LDFLAGS_NPU_HARDENED` - Linker flags
- `HARDVINO_KCFLAGS` - Kernel-specific flags
- `OV_NPU_*` - NPU runtime configuration

## Example: Custom Kernel with HARDVINO

```bash
#!/bin/bash
# build_custom_kernel.sh

# Set up environment
export HARDVINO_ROOT=/path/to/kernel/source/hardvino
source $HARDVINO_ROOT/npu_military_config.sh

# Configure kernel
make menuconfig
# Enable CONFIG_HARDVINO in "Device Drivers" -> "AI Accelerators"

# Build with HARDVINO flags
make -j$(nproc) \
    KCFLAGS="$HARDVINO_KCFLAGS" \
    HARDVINO_ROOT="$HARDVINO_ROOT"

# Install
sudo make modules_install
sudo make install
```

## Runtime Usage

After booting the kernel with HARDVINO:

```bash
# Load NPU module
sudo modprobe intel_vpu

# Initialize NPU
sudo /opt/hardvino/init_npu.sh

# Verify
dmesg | grep -i "npu\|vpu\|openvino"
```

## Performance Tuning

### P-Core Affinity
```bash
export GOMP_CPU_AFFINITY="0-5"  # Use P-cores only
export OMP_NUM_THREADS="6"
```

### NPU Optimization
```bash
export OV_NPU_POWER_MODE=MAXIMUM_PERFORMANCE
export OV_NPU_PERFORMANCE_HINT=LATENCY
export OV_NPU_DPU_GROUPS=4
```

## Troubleshooting

### NPU Not Detected
```bash
# Check device
ls -la /dev/accel/accel0

# Check module
lsmod | grep intel_vpu

# Check firmware
ls -la /lib/firmware/intel/vpu/
```

### Build Errors
```bash
# Verify submodule initialization
git submodule status

# Rebuild HARDVINO
cd hardvino
./build_all.sh --clean
```

## References

- OpenVINO Documentation: https://docs.openvino.ai/
- Intel NPU Documentation: https://intel.github.io/intel-npu-acceleration-library/
- ImageHarden Security Principles: See parent README.md

## Support

For issues related to HARDVINO integration, see the main repository README.md
EOF

    log_info "Integration guide created: ${guide}"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║  HARDVINO - Kernel Integration Setup                                    ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo ""

    export_kernel_config
    create_kernel_makefile
    create_example_module
    create_integration_guide

    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║  KERNEL INTEGRATION SETUP COMPLETE                                       ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Generated files:"
    echo "  - kernel_config.mk      : Kernel build configuration"
    echo "  - Kbuild.mk            : Kernel Makefile integration"
    echo "  - example_module/      : Example kernel module"
    echo "  - KERNEL_INTEGRATION.md: Integration guide"
    echo ""
    echo "To use in your kernel:"
    echo "  1. Add HARDVINO as submodule to your kernel source"
    echo "  2. Build HARDVINO: ./build_all.sh"
    echo "  3. Include in kernel: include \$(HARDVINO_ROOT)/Kbuild.mk"
    echo "  4. Build kernel: make KCFLAGS=\"\$(HARDVINO_KCFLAGS)\""
    echo ""
    echo "See KERNEL_INTEGRATION.md for detailed instructions"
    echo ""
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
