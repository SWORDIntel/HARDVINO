# NVIDIA Open GPU Kernel Modules Integration Guide

## Overview

This guide provides a **hardened, production-ready** build and installation procedure for NVIDIA's open-source GPU kernel modules on Debian-based Linux systems. HARDVINO integrates NVIDIA GPU support with the same military-grade security hardening applied to Intel and Qualcomm accelerators.

**Target Platform**: Debian-based Linux (Ubuntu 22.04+), kernel 6.1+
**NVIDIA Driver Version**: 550+ (open-gpu-kernel-modules)
**Security Level**: Production-hardened (FORTIFY=3, CET/CFI, RELRO)
**Supported GPUs**: NVIDIA Turing (RTX 20 series) and newer

---

## Architecture Integration

NVIDIA GPU modules integrate into HARDVINO as an optional multi-vendor AI accelerator:

```
HARDVINO Multi-Vendor Stack
├── Intel AI Stack (oneDNN, OpenVINO, NPU Driver Layer)
├── Intel QAT (Crypto/Compression Offload)
├── Qualcomm AI Stack (QNN SDK - optional)
└── NVIDIA GPU Stack (Open Kernel Modules + CUDA)
    ├── nvidia.ko (Core kernel module)
    ├── nvidia-modeset.ko (Display/mode setting)
    ├── nvidia-uvm.ko (Unified Virtual Memory)
    ├── nvidia-drm.ko (DRM/KMS integration)
    └── CUDA Runtime (userspace - separate install)
```

**Use Cases**:
- Multi-vendor AI inference (Intel NPU + NVIDIA GPU + Qualcomm accelerators)
- CUDA-accelerated ML training and inference
- GPU compute offload for scientific workloads
- Hybrid rendering (Intel iGPU + NVIDIA dGPU)
- Heterogeneous computing research

---

## Security Hardening Strategy

### Kernel Module Hardening

NVIDIA open-gpu-kernel-modules are built with HARDVINO's security profile:

```bash
# Compile-time hardening flags
CFLAGS="-O3 -march=native \
    -fstack-protector-strong \
    -fstack-clash-protection \
    -fcf-protection=full \
    -D_FORTIFY_SOURCE=3 \
    -fPIE \
    -Wl,-z,relro,-z,now \
    -Wl,-z,noexecstack"
```

### Module Signing

All NVIDIA kernel modules are signed with the system MOK (Machine Owner Key):

```bash
# Generate MOK key pair (one-time)
openssl req -new -x509 -newkey rsa:2048 -keyout MOK.priv -outform DER -out MOK.der -days 36500 -subj "/CN=HARDVINO Module Signing/"

# Sign modules
/usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 MOK.priv MOK.der nvidia.ko
```

### Runtime Protections

| Protection | Mechanism | Rationale |
|------------|-----------|-----------|
| Module Signing | CONFIG_MODULE_SIG_FORCE=y | Prevent unsigned module loading |
| Lockdown | CONFIG_SECURITY_LOCKDOWN_LSM=y | Kernel lockdown mode |
| IOMMU | intel_iommu=on | DMA attack protection |
| Secure Boot | MOK enrollment | UEFI Secure Boot compatibility |

---

## Prerequisites

### System Requirements

**Hardware**:
- NVIDIA GPU: Turing (RTX 20 series) or newer
  - Supported: RTX 20/30/40 series, A-series, H100/H200
  - NOT supported: GTX 16 series and older (use proprietary driver)
- x86_64 or ARM64 architecture
- Minimum 8GB system RAM (16GB recommended for ML workloads)

**Software**:
- Debian-based Linux (Ubuntu 22.04+, Debian 12+)
- Kernel 6.1+ (6.6+ recommended)
- GCC 13+ or Clang 17+ (GCC 15 recommended for CET/CFI)
- DKMS 3.0+ (for automatic module rebuilds)
- Secure Boot (optional, but recommended with MOK)

### Verify GPU Compatibility

```bash
# Check for NVIDIA GPU
lspci | grep -i nvidia

# Expected output (example):
# 01:00.0 VGA compatible controller: NVIDIA Corporation GA102 [GeForce RTX 3090] (rev a1)
# 01:00.1 Audio device: NVIDIA Corporation GA102 High Definition Audio Controller (rev a1)

# Check GPU architecture
nvidia-smi --query-gpu=name,compute_cap --format=csv

# Open modules require compute capability ≥ 7.5 (Turing or newer)
```

---

## Installation Procedure

### 1. System Preparation

#### 1.1 Install Build Dependencies

```bash
# Update package lists
sudo apt update

# Install kernel headers and build tools
sudo apt install -y \
    linux-headers-$(uname -r) \
    build-essential \
    gcc-13 \
    g++-13 \
    dkms \
    git \
    cmake \
    libelf-dev \
    libssl-dev \
    bc \
    kmod \
    mokutil \
    openssl

# Set GCC 13 as default (if multiple versions installed)
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 100
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 100
```

#### 1.2 Blacklist Nouveau Driver

```bash
# Create blacklist configuration
sudo tee /etc/modprobe.d/blacklist-nouveau.conf > /dev/null << 'EOF'
# Blacklist open-source Nouveau driver (conflicts with NVIDIA)
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off
EOF

# Update initramfs
sudo update-initramfs -u

# Reboot required for nouveau blacklist to take effect
sudo reboot
```

**After Reboot**: Verify nouveau is not loaded:
```bash
lsmod | grep nouveau
# Should return no output
```

---

### 2. Build NVIDIA Open Kernel Modules (HARDVINO Method)

#### 2.1 Navigate to Submodule

```bash
cd /path/to/HARDVINO/submodules/nvidia-stack/drivers/open-gpu-kernel-modules
```

#### 2.2 Select Driver Version

```bash
# List available versions
git tag | grep -E '^[0-9]+\.[0-9]+' | sort -V | tail -10

# Checkout latest stable (example: 560.35.03)
git checkout 560.35.03

# Or use latest development
git checkout main
```

#### 2.3 Build with HARDVINO Hardening

Use the HARDVINO build script (creates `scripts/build_nvidia.sh`):

```bash
# From HARDVINO root
./scripts/build_nvidia.sh --build --sign

# Manual build (advanced):
cd submodules/nvidia-stack/drivers/open-gpu-kernel-modules

# Set HARDVINO hardening flags
export HARDVINO_HARDENING_FLAGS="-fstack-protector-strong -fstack-clash-protection -fcf-protection=full -D_FORTIFY_SOURCE=3"
export HARDVINO_OPTIMIZATION_FLAGS="-O3 -march=native -mtune=native"
export CFLAGS="$HARDVINO_OPTIMIZATION_FLAGS $HARDVINO_HARDENING_FLAGS"
export LDFLAGS="-Wl,-z,relro,-z,now -Wl,-z,noexecstack"

# Build kernel modules
make -j$(nproc) modules

# Expected output:
# Building NVIDIA kernel modules...
# CC [M]  nvidia/nv-frontend.o
# CC [M]  nvidia/nv-mmap.o
# ...
# LD [M]  nvidia.ko
# LD [M]  nvidia-modeset.ko
# LD [M]  nvidia-uvm.ko
# LD [M]  nvidia-drm.ko
```

#### 2.4 Sign Kernel Modules (Secure Boot)

If using Secure Boot, sign all modules:

```bash
# Navigate to kernel modules directory
cd kernel-open

# Sign each module
for module in nvidia.ko nvidia-modeset.ko nvidia-uvm.ko nvidia-drm.ko nvidia-peermem.ko; do
    if [[ -f "$module" ]]; then
        sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file \
            sha256 \
            /var/lib/shim-signed/mok/MOK.priv \
            /var/lib/shim-signed/mok/MOK.der \
            "$module"
        echo "Signed: $module"
    fi
done

# Verify signature
modinfo nvidia.ko | grep "sig_id\|signer"
```

**First-Time MOK Setup** (if keys don't exist):
```bash
# Generate MOK key pair
sudo mkdir -p /var/lib/shim-signed/mok
cd /var/lib/shim-signed/mok

sudo openssl req -new -x509 -newkey rsa:2048 \
    -keyout MOK.priv \
    -outform DER \
    -out MOK.der \
    -days 36500 \
    -subj "/CN=HARDVINO NVIDIA Module Signing/" \
    -nodes

# Enroll MOK key
sudo mokutil --import MOK.der

# System will prompt for a password - remember it!
# Reboot and enroll key in MOK Manager
sudo reboot
```

#### 2.5 Install Kernel Modules

```bash
# Install modules to system
cd kernel-open
sudo make modules_install

# Expected install locations:
# /lib/modules/$(uname -r)/kernel/drivers/video/nvidia.ko
# /lib/modules/$(uname -r)/kernel/drivers/video/nvidia-modeset.ko
# /lib/modules/$(uname -r)/kernel/drivers/video/nvidia-uvm.ko
# /lib/modules/$(uname -r)/kernel/drivers/video/nvidia-drm.ko

# Update module dependencies
sudo depmod -a

# Verify installation
modinfo nvidia | head -20
```

---

### 3. Install NVIDIA Userspace Components

The kernel modules alone are not sufficient - you need matching userspace libraries.

#### 3.1 Install NVIDIA CUDA Toolkit (Optional)

```bash
# Add NVIDIA CUDA repository
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt update

# Install CUDA toolkit (matches kernel module version)
sudo apt install -y cuda-toolkit-12-6

# Install cuDNN (for deep learning)
sudo apt install -y libcudnn9-cuda-12
```

#### 3.2 Install NVIDIA Container Toolkit (For Docker/Podman)

```bash
# Add NVIDIA container repository
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt update
sudo apt install -y nvidia-container-toolkit

# Configure Docker
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

---

### 4. Load and Verify Modules

#### 4.1 Load NVIDIA Modules

```bash
# Load nvidia kernel module
sudo modprobe nvidia

# Load additional modules
sudo modprobe nvidia-modeset
sudo modprobe nvidia-uvm
sudo modprobe nvidia-drm

# Verify loaded modules
lsmod | grep nvidia

# Expected output:
# nvidia_uvm           1576960  0
# nvidia_drm             94208  0
# nvidia_modeset       1310720  1 nvidia_drm
# nvidia              62390272  2 nvidia_uvm,nvidia_modeset
# drm_kms_helper        311296  1 nvidia_drm
# drm                   622592  4 drm_kms_helper,nvidia,nvidia_drm
```

#### 4.2 Verify GPU Detection

```bash
# Check NVIDIA SMI (System Management Interface)
nvidia-smi

# Expected output:
# +-----------------------------------------------------------------------------------------+
# | NVIDIA-SMI 560.35.03              Driver Version: 560.35.03      CUDA Version: 12.6     |
# |-----------------------------------------+------------------------+----------------------+
# | GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
# | Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
# |                                         |                        |               MIG M. |
# |=========================================+========================+======================|
# |   0  NVIDIA GeForce RTX 3090      Off |   00000000:01:00.0  On |                  N/A |
# | 30%   45C    P8             29W /  350W |     512MiB /  24576MiB |      0%      Default |
# |                                         |                        |                  N/A |
# +-----------------------------------------+------------------------+----------------------+

# Check CUDA device
nvidia-smi --query-gpu=name,driver_version,cuda_version --format=csv
```

#### 4.3 Test CUDA (If Installed)

```bash
# Compile CUDA sample
cd /usr/local/cuda/samples/1_Utilities/deviceQuery
sudo make

# Run device query
./deviceQuery

# Expected output:
# Device 0: "NVIDIA GeForce RTX 3090"
#   CUDA Driver Version / Runtime Version          12.6 / 12.6
#   CUDA Capability Major/Minor version number:    8.6
#   Total amount of global memory:                 24576 MBytes
#   ...
#   Result = PASS
```

---

### 5. Persistent Module Loading

#### 5.1 Create systemd Module Loader

```bash
sudo tee /etc/modules-load.d/nvidia.conf > /dev/null << 'EOF'
# NVIDIA GPU kernel modules (open-source)
nvidia
nvidia-modeset
nvidia-uvm
nvidia-drm
EOF

# Verify configuration
cat /etc/modules-load.d/nvidia.conf
```

#### 5.2 Set Module Parameters

```bash
sudo tee /etc/modprobe.d/nvidia.conf > /dev/null << 'EOF'
# NVIDIA GPU module parameters
# Enable DRM kernel mode setting
options nvidia-drm modeset=1

# Enable unified memory
options nvidia NVreg_EnableGpuFirmware=1

# Preserve video memory allocations across suspend
options nvidia NVreg_PreserveVideoMemoryAllocations=1

# Enable power management
options nvidia NVreg_EnableS0ixPowerManagement=1
EOF

# Update initramfs
sudo update-initramfs -u
```

#### 5.3 Create NVIDIA Persistence Daemon

```bash
# Install nvidia-persistenced (comes with CUDA)
sudo apt install -y nvidia-persistenced

# Enable persistence daemon
sudo systemctl enable nvidia-persistenced
sudo systemctl start nvidia-persistenced

# Verify
sudo systemctl status nvidia-persistenced
```

---

### 6. Security Hardening (Production)

#### 6.1 Restrict GPU Device Permissions

```bash
# Create udev rule for GPU device access
sudo tee /etc/udev/rules.d/70-nvidia-gpu.rules > /dev/null << 'EOF'
# NVIDIA GPU device permissions
# Allow only render group to access GPU
KERNEL=="nvidia*", GROUP="render", MODE="0660"
SUBSYSTEM=="drm", KERNEL=="card*", GROUP="render", MODE="0660"
SUBSYSTEM=="drm", KERNEL=="renderD*", GROUP="render", MODE="0660"
EOF

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Add users to render group
sudo usermod -aG render $USER
```

#### 6.2 Enable GPU Compute Isolation (Systemd)

For containerized GPU workloads, create a hardened service:

```bash
sudo tee /etc/systemd/system/nvidia-compute.service > /dev/null << 'EOF'
[Unit]
Description=NVIDIA GPU Compute Service (Hardened)
After=nvidia-persistenced.service

[Service]
Type=simple
User=nobody
Group=render

# Security hardening
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RestrictNamespaces=yes
LockPersonality=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes

# Allow GPU device access
DeviceAllow=/dev/nvidia* rw
DeviceAllow=/dev/dri/* rw

# Resource limits
MemoryMax=16G
CPUQuota=400%

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=nvidia-compute

[Install]
WantedBy=multi-user.target
EOF
```

#### 6.3 IOMMU Isolation

Enable IOMMU for DMA attack protection:

```bash
# Add to GRUB configuration
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="intel_iommu=on iommu=pt /' /etc/default/grub

# Update GRUB
sudo update-grub

# Reboot required
sudo reboot

# After reboot, verify IOMMU
dmesg | grep -i iommu
# Expected: "DMAR: IOMMU enabled"
```

---

### 7. Integration with HARDVINO

#### 7.1 Environment Variables

Add NVIDIA paths to HARDVINO environment:

```bash
# In ~/.profile or HARDVINO setup script
export CUDA_HOME=/usr/local/cuda
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# NVIDIA runtime library path
export NVIDIA_DRIVER_CAPABILITIES=compute,utility
export NVIDIA_VISIBLE_DEVICES=all
```

#### 7.2 CMake Integration

Add NVIDIA GPU detection to HARDVINO CMake:

```cmake
# In cmake/HARDVINOConfig.cmake
find_package(CUDA)
if(CUDA_FOUND)
    set(HARDVINO_NVIDIA_AVAILABLE TRUE)
    message(STATUS "NVIDIA CUDA found: ${CUDA_VERSION}")

    # Apply HARDVINO hardening flags to CUDA code
    set(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -O3 -use_fast_math")
    set(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -Xcompiler=-fstack-protector-strong")
endif()

# Function to link NVIDIA CUDA with hardening
function(target_link_nvidia target)
    if(HARDVINO_NVIDIA_AVAILABLE)
        target_link_libraries(${target} PRIVATE ${CUDA_LIBRARIES})
        target_include_directories(${target} PRIVATE ${CUDA_INCLUDE_DIRS})

        # Apply hardening flags
        target_compile_options(${target} PRIVATE ${HARDVINO_HARDENING_FLAGS})
    endif()
endfunction()
```

#### 7.3 Multi-Vendor AI Workflow

Use Intel NPU + NVIDIA GPU together:

```python
# Example: PyTorch with Intel + NVIDIA
import torch
import openvino as ov

# Intel NPU for lightweight inference
core = ov.Core()
npu_model = core.compile_model("model.xml", "NPU")

# NVIDIA GPU for heavy training
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model = MyModel().to(device)
model.train()

# Hybrid inference: light models on NPU, heavy on GPU
if input_size < threshold:
    result = npu_model(input)  # Intel NPU
else:
    result = model(input)      # NVIDIA GPU
```

---

## 8. DKMS Integration (Auto-Rebuild on Kernel Updates)

### 8.1 Create DKMS Configuration

```bash
# Create DKMS config for NVIDIA modules
sudo tee /usr/src/nvidia-560.35.03/dkms.conf > /dev/null << 'EOF'
PACKAGE_NAME="nvidia"
PACKAGE_VERSION="560.35.03"
AUTOINSTALL="yes"

# Kernel modules
BUILT_MODULE_NAME[0]="nvidia"
BUILT_MODULE_LOCATION[0]="kernel-open"
DEST_MODULE_LOCATION[0]="/kernel/drivers/video"

BUILT_MODULE_NAME[1]="nvidia-modeset"
BUILT_MODULE_LOCATION[1]="kernel-open"
DEST_MODULE_LOCATION[1]="/kernel/drivers/video"

BUILT_MODULE_NAME[2]="nvidia-uvm"
BUILT_MODULE_LOCATION[2]="kernel-open"
DEST_MODULE_LOCATION[2]="/kernel/drivers/video"

BUILT_MODULE_NAME[3]="nvidia-drm"
BUILT_MODULE_LOCATION[3]="kernel-open"
DEST_MODULE_LOCATION[3]="/kernel/drivers/video"

# Build commands with HARDVINO hardening
MAKE[0]="make -j$(nproc) \
    CFLAGS_MODULE='-fstack-protector-strong -fstack-clash-protection -fcf-protection=full -D_FORTIFY_SOURCE=3' \
    modules"
CLEAN="make clean"
EOF

# Add to DKMS
sudo dkms add -m nvidia -v 560.35.03

# Build with DKMS
sudo dkms build -m nvidia -v 560.35.03

# Install with DKMS
sudo dkms install -m nvidia -v 560.35.03
```

### 8.2 Verify DKMS Status

```bash
# Check DKMS status
sudo dkms status

# Expected output:
# nvidia/560.35.03, 6.8.0-48-generic, x86_64: installed

# Modules will auto-rebuild on kernel updates
```

---

## 9. Troubleshooting

### Issue: Module signing error "Required key not available"

**Cause**: Secure Boot enabled without enrolled MOK key.

**Fix**:
```bash
# Disable Secure Boot signature verification (temporary)
sudo mokutil --disable-validation

# Or properly enroll MOK key
sudo mokutil --import /var/lib/shim-signed/mok/MOK.der
sudo reboot
```

### Issue: `nvidia-smi` shows "Failed to initialize NVML"

**Cause**: Kernel module not loaded or version mismatch.

**Fix**:
```bash
# Check if module is loaded
lsmod | grep nvidia

# If not loaded:
sudo modprobe nvidia

# Check for version mismatch
dmesg | grep nvidia | tail -20

# Reinstall userspace to match kernel version
sudo apt install --reinstall nvidia-utils-560
```

### Issue: CUDA applications fail with "no CUDA-capable device"

**Cause**: GPU not visible to CUDA runtime.

**Fix**:
```bash
# Check GPU visibility
nvidia-smi -L

# Verify CUDA installation
nvcc --version

# Check device permissions
ls -la /dev/nvidia*

# Add user to render group
sudo usermod -aG render $USER
newgrp render
```

### Issue: Build fails with "btf_encoder__new: 'pahole' not found"

**Cause**: Missing BTF (BPF Type Format) tools.

**Fix**:
```bash
sudo apt install -y dwarves
```

---

## 10. Performance Tuning

### 10.1 Enable GPU Persistence Mode

```bash
# Enable persistence mode (reduces latency)
sudo nvidia-smi -pm 1

# Set power management mode
sudo nvidia-smi -pl 350  # Max power limit (example for RTX 3090)

# Enable auto-boost
sudo nvidia-smi -ac 1215,1800  # Memory,Graphics clock (example)
```

### 10.2 Optimize for AI Workloads

```bash
# Set compute mode (exclusive process)
sudo nvidia-smi -c 3

# Enable MIG (Multi-Instance GPU) if supported
sudo nvidia-smi mig -cgi 9,9,9,9  # Example: 4x 1g.5gb instances

# Disable ECC (if not needed, for higher performance)
sudo nvidia-smi -e 0
```

---

## 11. Verification Checklist

Run the HARDVINO NVIDIA verification script:

```bash
./scripts/build_nvidia.sh --verify

# Manual verification:
✓ lsmod | grep nvidia               # Modules loaded
✓ nvidia-smi                        # GPU detected
✓ cat /proc/driver/nvidia/version   # Driver version
✓ modinfo nvidia | grep sig_id      # Module signed (if Secure Boot)
✓ dkms status | grep nvidia         # DKMS configured
✓ nvidia-smi -L                     # GPU list
✓ nvcc --version                    # CUDA compiler
✓ systemctl status nvidia-persistenced  # Persistence daemon
```

---

## 12. Security Best Practices

1. **Always sign kernel modules** with MOK if Secure Boot is enabled
2. **Restrict device access** to render group only
3. **Use IOMMU** for DMA attack prevention
4. **Enable kernel lockdown** mode for production systems
5. **Monitor GPU usage** via systemd journals and nvidia-smi
6. **Keep drivers updated** but test in staging first
7. **Use container isolation** for multi-tenant GPU workloads
8. **Disable unused features** (ECC, MIG) if not required

---

## 13. References

- **NVIDIA Open GPU Kernel Modules**: [https://github.com/NVIDIA/open-gpu-kernel-modules](https://github.com/NVIDIA/open-gpu-kernel-modules)
- **NVIDIA Driver Documentation**: [https://docs.nvidia.com/](https://docs.nvidia.com/)
- **CUDA Toolkit**: [https://developer.nvidia.com/cuda-toolkit](https://developer.nvidia.com/cuda-toolkit)
- **DKMS Documentation**: [https://github.com/dell/dkms](https://github.com/dell/dkms)
- **Kernel Module Signing**: [https://www.kernel.org/doc/html/latest/admin-guide/module-signing.html](https://www.kernel.org/doc/html/latest/admin-guide/module-signing.html)
- **HARDVINO Security Profile**: `docs/MASTER_PROMPT.md`

---

**Document Version**: 1.0
**Last Updated**: 2025-11-24
**Maintained By**: HARDVINO Integration Team
