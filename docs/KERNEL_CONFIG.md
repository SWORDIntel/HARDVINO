# DSMIL Kernel Configuration

This document provides the kernel configuration flags required for the Intel Acceleration Stack on the DSMIL platform.

---

## Quick Reference

Add these to your DSMIL kernel defconfig or use `make menuconfig` to enable them.

---

## Intel Accelerator Drivers

### NPU / Accel Subsystem

```text
# Intel accelerators (accel subsystem)
CONFIG_ACCEL=y
CONFIG_DRM_ACCEL=y
CONFIG_DRM_ACCEL_IVPU=m        # Meteor Lake NPU (intel_vpu / ivpu)
```

### Intel Xe iGPU

```text
# Xe graphics driver
CONFIG_DRM_XE=m                # Xe iGPU
```

### Movidius / NUC2.1 Support

```text
# Movidius NUC2.1 support
CONFIG_VFIO_PCI=m
CONFIG_USB_XHCI_HCD=y
```

### QuickAssist Technology (QAT)

```text
# QAT crypto/compression
CONFIG_CRYPTO_DEV_QAT=m
CONFIG_CRYPTO_DEV_QAT_DH895xCC=m
CONFIG_CRYPTO_DEV_QAT_DH895xCCVF=m
```

### Data Streaming / Analytics Accelerators

```text
# DSA / IAA
CONFIG_INTEL_IDXD=m
CONFIG_INTEL_IDXD_COMPAT=m

# I/OAT DMA
CONFIG_INTEL_IOATDMA=m
```

---

## Security / HIPS Stack

The DSMIL kernel uses BPF LSM and AppArmor (no SELinux).

### LSM Configuration

```text
# Security framework
CONFIG_SECURITY=y
CONFIG_LSM="lockdown,yama,bpf,apparmor"
```

### AppArmor

```text
# AppArmor MAC
CONFIG_SECURITY_APPARMOR=y
CONFIG_SECURITY_APPARMOR_BOOTPARAM_VALUE=1
```

### BPF LSM

```text
# BPF security
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_BPF_JIT_ALWAYS_ON=y
CONFIG_BPF_LSM=y
CONFIG_DEBUG_INFO_BTF=y
```

### Integrity Measurement

```text
# IMA / EVM
CONFIG_IMA=y
CONFIG_IMA_APPRAISE=y
CONFIG_IMA_LSM_RULES=y
CONFIG_EVM=y
```

### Module Signing

```text
# Kernel module signing enforcement
CONFIG_MODULE_SIG=y
CONFIG_MODULE_SIG_ALL=y
CONFIG_MODULE_SIG_FORCE=y
CONFIG_MODULE_SIG_SHA256=y
CONFIG_SYSTEM_TRUSTED_KEYS="dsmil_kmod_signing.pem"
```

### Lockdown

```text
# Kernel lockdown
CONFIG_LOCK_DOWN_KERNEL_FORCE_CONFIDENTIALITY=y
```

---

## Complete Defconfig Fragment

Copy this entire block into a fragment file (e.g., `dsmil_intel.config`):

```text
# ============================================================================
# DSMIL Intel Acceleration Stack - Kernel Config Fragment
# ============================================================================

# --- Intel Accelerators ---
CONFIG_ACCEL=y
CONFIG_DRM_ACCEL=y
CONFIG_DRM_ACCEL_IVPU=m
CONFIG_DRM_XE=m

# --- Movidius NUC2.1 Support ---
CONFIG_VFIO_PCI=m
CONFIG_USB_XHCI_HCD=y

# --- QAT / DSA / IOAT ---
CONFIG_CRYPTO_DEV_QAT=m
CONFIG_CRYPTO_DEV_QAT_DH895xCC=m
CONFIG_CRYPTO_DEV_QAT_DH895xCCVF=m
CONFIG_INTEL_IDXD=m
CONFIG_INTEL_IDXD_COMPAT=m
CONFIG_INTEL_IOATDMA=m

# --- Security / HIPS Stack (no SELinux) ---
CONFIG_SECURITY=y
CONFIG_LSM="lockdown,yama,bpf,apparmor"
CONFIG_SECURITY_APPARMOR=y
CONFIG_SECURITY_APPARMOR_BOOTPARAM_VALUE=1
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_BPF_JIT_ALWAYS_ON=y
CONFIG_BPF_LSM=y
CONFIG_DEBUG_INFO_BTF=y
CONFIG_IMA=y
CONFIG_IMA_APPRAISE=y
CONFIG_IMA_LSM_RULES=y
CONFIG_EVM=y
CONFIG_MODULE_SIG=y
CONFIG_MODULE_SIG_ALL=y
CONFIG_MODULE_SIG_FORCE=y
CONFIG_MODULE_SIG_SHA256=y
CONFIG_SYSTEM_TRUSTED_KEYS="dsmil_kmod_signing.pem"
CONFIG_LOCK_DOWN_KERNEL_FORCE_CONFIDENTIALITY=y
```

---

## Applying the Config Fragment

### Method 1: Merge with existing config

```bash
cd /path/to/kernel
scripts/kconfig/merge_config.sh .config /path/to/dsmil_intel.config
```

### Method 2: Use as defconfig base

```bash
cd /path/to/kernel
cp /path/to/dsmil_intel.config arch/x86/configs/dsmil_defconfig
make dsmil_defconfig
```

---

## Building with LLVM

Use the LLVM toolchain for kernel compilation:

```bash
# Source the Intel environment
source /path/to/HARDVINO/scripts/intel_env.sh

# Build kernel with LLVM
make LLVM=1 LLVM_IAS=1 \
     CC=clang HOSTCC=clang HOSTCXX=clang++ \
     KCFLAGS="${KCFLAGS}" KCPPFLAGS="${KCPPFLAGS}" \
     -j"$(nproc)"
```

---

## Verification

After boot, verify accelerators are available:

```bash
# NPU
ls -la /dev/accel/accel0
cat /sys/class/accel/accel0/device/device

# QAT
lsmod | grep qat

# DSA/IAA
ls /sys/bus/dsa/devices/

# Module signatures
cat /proc/sys/kernel/modules_disabled
dmesg | grep -i "module verification"
```

---

## Related Documentation

- [Master Prompt](MASTER_PROMPT.md) - AI system integration prompt
- [Intel Environment](../scripts/intel_env.sh) - Compiler and build flags
- [Component Manifest](../intel_stack.manifest.yml) - Full component list
