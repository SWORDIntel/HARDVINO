# Qualcomm AI Engine Direct (QNN) Integration Guide

## Overview

This guide provides a **hardened, production-ready** installation procedure for the Qualcomm Neural Network (QNN) SDK on Debian-based Linux systems (kernel 6.17+). Given QNN's closed-source nature, this specification focuses on defense-in-depth through:

- Least-privilege service accounts
- Filesystem permission hardening
- Systemd security restrictions
- Network isolation
- Cryptographic verification

**Target Platform**: Debian 6.17, x86_64 or ARM64
**QNN SDK Version**: 2.x+ (adjust paths for your version)
**Security Level**: Production-hardened

---

## Architecture Integration

QNN SDK integrates into HARDVINO as an optional AI accelerator alongside Intel NPU, GPU, and QAT:

```
HARDVINO Stack
├── Intel AI Stack (oneDNN, OpenVINO, NPU Driver Layer)
├── Intel QAT (Crypto/Compression Offload)
└── Qualcomm AI Stack (QNN SDK)
    ├── QNN Runtime (libQnn*.so)
    ├── Backend Targets: CPU, GPU, DSP, HTP (Hexagon Tensor Processor)
    └── Model Converters (ONNX, TensorFlow, PyTorch → QNN)
```

**Use Cases**:
- Multi-vendor AI inference (Intel + Qualcomm SoCs)
- Qualcomm Cloud AI 100 accelerator cards
- Mobile/edge deployments with Snapdragon NPUs
- Heterogeneous compute research

---

## Installation Procedure

### 1. System Preparation (Root, One-Time)

#### 1.1 Install Base Dependencies

```bash
# Update package list
apt update

# Install compiler toolchain and Python 3.10
apt install -y \
    python3.10 \
    python3.10-venv \
    python3.10-dev \
    build-essential \
    cmake \
    unzip \
    libstdc++6 \
    ca-certificates \
    curl \
    gnupg

# Verify Python version
python3.10 --version  # Must be ≥3.10
```

#### 1.2 Create Service Account

Create a dedicated non-login user for QNN runtime isolation:

```bash
# Create group
groupadd --system qnnsvc

# Create user (no home directory, no shell access)
useradd \
    --system \
    --gid qnnsvc \
    --no-create-home \
    --shell /usr/sbin/nologin \
    qnnsvc

# Verify creation
id qnnsvc
# Expected: uid=xxx(qnnsvc) gid=xxx(qnnsvc) groups=xxx(qnnsvc)
```

#### 1.3 Network Security

**During Installation**: Allow outbound HTTPS to Qualcomm servers:
```bash
# Example with UFW (adjust for your firewall)
ufw allow out to any port 443 proto tcp comment 'QNN SDK download'
```

**Post-Installation**: Block unnecessary outbound traffic for the QNN service (configure in systemd unit later).

---

### 2. SDK Acquisition (Root)

#### 2.1 Install Qualcomm Package Manager

1. Download `qualcomm-qpm-cli_<version>.deb` from [Qualcomm Developer Portal](https://developer.qualcomm.com/)
2. Verify GPG signature (if provided by Qualcomm)
3. Install:

```bash
dpkg -i qualcomm-qpm-cli_*.deb
apt-get install -f  # Fix any dependency issues

# Verify installation
qpm-cli --version
```

#### 2.2 Authenticate and Activate License

```bash
# Login with Qualcomm Developer ID
qpm-cli --login <your-qualcomm-id>

# Activate QNN license
qpm-cli --license-activate qualcomm_ai_engine_direct

# Verify license status
qpm-cli --license-status
```

#### 2.3 Download and Verify SDK

```bash
# Download QNN SDK (.qik or .zip format)
qpm-cli download qualcomm_ai_engine_direct

# ⚠️ CRITICAL: Verify SHA-256 hash against Qualcomm portal
cd ~/Downloads
sha256sum qualcomm_ai_engine_direct_*.zip

# Compare with hash from Qualcomm website
# If mismatch: DO NOT PROCEED - contact Qualcomm support
```

#### 2.4 Extract to Secured Location

```bash
# Create installation directory
mkdir -p /opt/qcom/aistack/qnn

# Extract SDK (adjust version number)
# Example: qnn-v2.18.0-linux-x86_64.zip
qpm-cli --extract qualcomm_ai_engine_direct_*.zip \
    --install-dir /opt/qcom/aistack/qnn/2.18.0

# Alternative: Manual extraction if qpm-cli doesn't support --install-dir
unzip -q qualcomm_ai_engine_direct_*.zip -d /opt/qcom/aistack/qnn/2.18.0
```

#### 2.5 Harden Filesystem Permissions

```bash
# Set ownership: root owns files, qnnsvc group can read/execute
chown -R root:qnnsvc /opt/qcom/aistack/qnn

# Restrict permissions: owner=rwx, group=rx, others=none
chmod -R 0750 /opt/qcom/aistack/qnn

# Protect libraries specifically (no write access)
chmod -R 0555 /opt/qcom/aistack/qnn/*/lib

# Ensure no world-writable files exist
find /opt/qcom/aistack/qnn -perm -o+w -exec chmod o-w {} \;

# Verify permissions
ls -la /opt/qcom/aistack/qnn/
# Expected: drwxr-x--- root qnnsvc
```

#### 2.6 Create Version Symlink

```bash
# Symlink 'current' to active version for easy upgrades
ln -sf /opt/qcom/aistack/qnn/2.18.0 /opt/qcom/aistack/qnn/current

# Verify
readlink -f /opt/qcom/aistack/qnn/current
```

#### 2.7 Record Installation Metadata

```bash
cat > /opt/qcom/aistack/qnn/INSTALL_RECORD.txt << EOF
Installation Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
QNN SDK Version: 2.18.0
Installed By: $(whoami)
Host: $(hostname)
Kernel: $(uname -r)
SHA256 (SDK Archive): $(sha256sum ~/Downloads/qualcomm_ai_engine_direct_*.zip | awk '{print $1}')
Installation Path: /opt/qcom/aistack/qnn/2.18.0
EOF

chmod 0640 /opt/qcom/aistack/qnn/INSTALL_RECORD.txt
```

---

### 3. Developer Environment Setup (Non-Root Users)

Each developer using QNN should configure their environment:

#### 3.1 Add to Shell Profile

Edit `~/.profile` (or `~/.bashrc` for interactive shells):

```bash
# Qualcomm QNN SDK
export QNN_SDK_ROOT=/opt/qcom/aistack/qnn/current
export LD_LIBRARY_PATH=$QNN_SDK_ROOT/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
export PATH=$QNN_SDK_ROOT/bin:$PATH

# Optional: Python bindings (if available)
export PYTHONPATH=$QNN_SDK_ROOT/lib/python:$PYTHONPATH
```

Reload configuration:
```bash
source ~/.profile
```

#### 3.2 Create Python Virtual Environment

```bash
# Create isolated venv for QNN projects
python3.10 -m venv ~/venv/qnn

# Activate
source ~/venv/qnn/bin/activate

# Upgrade pip
pip install --upgrade pip setuptools wheel
```

#### 3.3 Install Framework Dependencies (Minimal)

**Only install frameworks you actually need:**

```bash
# For ONNX model conversion
pip install onnx onnxruntime-cpu

# For PyTorch model conversion
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# For TensorFlow model conversion
pip install tensorflow-cpu

# QNN Python API (if SDK provides a wheel)
pip install $QNN_SDK_ROOT/lib/python/qnn*.whl
```

---

### 4. Dependency Verification (Root, One-Time)

Run QNN's built-in dependency checkers:

#### 4.1 Python Dependencies

```bash
$QNN_SDK_ROOT/bin/check-python-dependency
```

**Expected Output**: All required Python packages installed ✓
**Action if Failed**: Install missing packages via pip in the venv.

#### 4.2 System Libraries

```bash
bash $QNN_SDK_ROOT/bin/check-linux-dependency.sh
```

**Expected Output**: All required system libraries found ✓
**Common Missing Libraries**:
- `libstdc++.so.6` → `apt install libstdc++6`
- `libgomp.so.1` → `apt install libgomp1`
- `libz.so.1` → `apt install zlib1g`

---

### 5. Runtime Hardening (Production Deployments)

#### 5.1 Systemd Service Configuration

Create `/etc/systemd/system/qnn-inference.service`:

```ini
[Unit]
Description=QNN Inference Service (Hardened)
Documentation=https://developer.qualcomm.com/qnn
After=network.target

[Service]
Type=simple
User=qnnsvc
Group=qnnsvc

# Working directory
WorkingDirectory=/opt/qcom/aistack/qnn/current

# Environment
Environment="QNN_SDK_ROOT=/opt/qcom/aistack/qnn/current"
Environment="LD_LIBRARY_PATH=/opt/qcom/aistack/qnn/current/lib/x86_64-linux-gnu"

# Application command (replace with your QNN application)
ExecStart=/opt/qcom/aistack/qnn/current/bin/qnn-net-run \
    --backend cpu \
    --model /var/lib/qnn/models/production.qnn

# Security Hardening
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RestrictNamespaces=yes
LockPersonality=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
MemoryDenyWriteExecute=yes
SystemCallFilter=@system-service
SystemCallFilter=~@privileged @resources
CapabilityBoundingSet=
AmbientCapabilities=

# Resource limits
MemoryMax=4G
CPUQuota=200%

# Network isolation (enable if inference doesn't need network)
# IPAddressDeny=any
# IPAddressAllow=localhost

# Filesystem access (read-only SDK, read/write for models)
ReadOnlyPaths=/opt/qcom/aistack/qnn
ReadWritePaths=/var/lib/qnn/models

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=qnn-inference

[Install]
WantedBy=multi-user.target
```

#### 5.2 Enable and Start Service

```bash
# Reload systemd configuration
systemctl daemon-reload

# Enable on boot
systemctl enable qnn-inference.service

# Start service
systemctl start qnn-inference.service

# Check status
systemctl status qnn-inference.service

# View logs
journalctl -u qnn-inference.service -f
```

#### 5.3 Additional Hardening Measures

**AppArmor Profile** (Optional, Advanced):
```bash
# Create /etc/apparmor.d/opt.qcom.aistack.qnn.bin.qnn-net-run
# Define allowed file access, network, and capabilities
# Example:
# /opt/qcom/aistack/qnn/** r,
# /var/lib/qnn/models/** rw,
# deny network inet,
# deny capability sys_admin,
```

**Seccomp Filter** (Already applied via SystemCallFilter in systemd unit)

**SELinux Policy** (If using SELinux instead of AppArmor):
```bash
# Create custom SELinux policy for qnnsvc_t domain
# Confine QNN processes to minimal required permissions
```

---

### 6. Verification and Testing

#### 6.1 SDK Installation Test (Non-Root)

```bash
# Activate developer environment
source ~/venv/qnn/bin/activate
source ~/.profile

# Run QNN profile tool on example model
$QNN_SDK_ROOT/bin/qnn-profile \
    --backend cpu \
    --model $QNN_SDK_ROOT/examples/models/mobilenet_v2/model.qnn

# Expected: Performance metrics printed, no errors
```

#### 6.2 Security Audit

```bash
# As root: Check for world-writable files
find /opt/qcom/aistack/qnn -perm -o+w

# Expected: No output (no world-writable files)

# Verify service account has no login shell
getent passwd qnnsvc | grep nologin

# Verify systemd hardening active
systemctl show qnn-inference.service | grep -E "(NoNewPrivileges|ProtectSystem|MemoryDenyWriteExecute)"
# Expected:
# NoNewPrivileges=yes
# ProtectSystem=strict
# MemoryDenyWriteExecute=yes
```

#### 6.3 Model Inference Test

```bash
# Convert a test model to QNN format (example: ONNX → QNN)
qnn-onnx-converter \
    --input_network model.onnx \
    --output_path model.qnn

# Run inference
qnn-net-run \
    --backend cpu \
    --model model.qnn \
    --input_list inputs.txt

# Expected: Inference results printed, no segfaults
```

---

## 7. Updates and Rollback

### 7.1 Side-by-Side Version Management

Install new QNN versions alongside existing ones:

```bash
# Install new version
unzip qnn-v2.19.0-linux-x86_64.zip -d /opt/qcom/aistack/qnn/2.19.0
chown -R root:qnnsvc /opt/qcom/aistack/qnn/2.19.0
chmod -R 0750 /opt/qcom/aistack/qnn/2.19.0

# Test new version in dev environment
export QNN_SDK_ROOT=/opt/qcom/aistack/qnn/2.19.0
$QNN_SDK_ROOT/bin/qnn-profile --backend cpu --model test.qnn

# If successful, update symlink
ln -sfn /opt/qcom/aistack/qnn/2.19.0 /opt/qcom/aistack/qnn/current

# Restart production service
systemctl restart qnn-inference.service
```

### 7.2 Rollback Procedure

```bash
# Revert to previous version
ln -sfn /opt/qcom/aistack/qnn/2.18.0 /opt/qcom/aistack/qnn/current

# Restart service
systemctl restart qnn-inference.service

# Verify rollback
readlink -f /opt/qcom/aistack/qnn/current
systemctl status qnn-inference.service
```

### 7.3 Post-Update Verification

After kernel or Python minor version upgrades:

```bash
# Re-run dependency checks
$QNN_SDK_ROOT/bin/check-python-dependency
bash $QNN_SDK_ROOT/bin/check-linux-dependency.sh

# Smoke test with profile tool
$QNN_SDK_ROOT/bin/qnn-profile \
    --backend cpu \
    --model $QNN_SDK_ROOT/examples/models/mobilenet_v2/model.qnn

# Record update in install log
echo "Updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC") - Kernel $(uname -r)" \
    >> /opt/qcom/aistack/qnn/INSTALL_RECORD.txt
```

---

## 8. Integration with HARDVINO Build System

### 8.1 Environment Variables

Add QNN variables to HARDVINO environment setup:

```bash
# In scripts/qualcomm_env.sh (create new file):
export QNN_SDK_ROOT=/opt/qcom/aistack/qnn/current
export QNN_LIB_PATH=$QNN_SDK_ROOT/lib/x86_64-linux-gnu
export LD_LIBRARY_PATH=$QNN_LIB_PATH:$LD_LIBRARY_PATH

# Compiler flags for QNN-accelerated projects
export QNN_CFLAGS="-I$QNN_SDK_ROOT/include"
export QNN_LDFLAGS="-L$QNN_LIB_PATH -lQnnCpu -lQnnSystem"
```

### 8.2 CMake Integration

Add QNN detection to HARDVINO CMake configuration:

```cmake
# In cmake/HARDVINOConfig.cmake:
if(DEFINED ENV{QNN_SDK_ROOT})
    set(QNN_SDK_ROOT $ENV{QNN_SDK_ROOT})
    set(QNN_INCLUDE_DIR ${QNN_SDK_ROOT}/include)
    set(QNN_LIB_DIR ${QNN_SDK_ROOT}/lib/x86_64-linux-gnu)

    # Find QNN libraries
    find_library(QNN_CPU_LIB QnnCpu PATHS ${QNN_LIB_DIR})
    find_library(QNN_SYSTEM_LIB QnnSystem PATHS ${QNN_LIB_DIR})

    if(QNN_CPU_LIB AND QNN_SYSTEM_LIB)
        set(HARDVINO_QNN_AVAILABLE TRUE)
        message(STATUS "Qualcomm QNN SDK found: ${QNN_SDK_ROOT}")
    endif()
endif()

# Function to link QNN with hardening
function(target_link_qnn target)
    if(HARDVINO_QNN_AVAILABLE)
        target_include_directories(${target} PRIVATE ${QNN_INCLUDE_DIR})
        target_link_libraries(${target} PRIVATE ${QNN_CPU_LIB} ${QNN_SYSTEM_LIB})

        # Apply HARDVINO hardening flags
        target_compile_options(${target} PRIVATE ${HARDVINO_HARDENING_FLAGS})
        target_link_options(${target} PRIVATE
            -Wl,-z,relro,-z,now
            -Wl,-z,noexecstack
        )
    else()
        message(WARNING "QNN SDK not found, ${target} will not use QNN acceleration")
    endif()
endfunction()
```

### 8.3 Build Stage Integration

QNN should be built in Stage 6.5 (after QAT, before ML frameworks) in `scripts/build_order.sh`:

```bash
# Stage 6.5: Qualcomm QNN SDK (verification only - SDK is pre-installed)
build_stage "6.5" "Qualcomm QNN SDK" "none" "" "qnn-sdk-verify" "OPTIONAL"

function qnn-sdk-verify() {
    log "INFO" "Verifying Qualcomm QNN SDK installation..."

    if [[ ! -d /opt/qcom/aistack/qnn/current ]]; then
        log "WARN" "QNN SDK not found at /opt/qcom/aistack/qnn/current"
        log "WARN" "Follow docs/QNN_INTEGRATION.md for installation"
        return 0  # Non-fatal for optional component
    fi

    if [[ ! -f /opt/qcom/aistack/qnn/current/bin/qnn-profile ]]; then
        log "ERROR" "QNN SDK incomplete - missing qnn-profile tool"
        return 1
    fi

    log "INFO" "QNN SDK verified: $(readlink -f /opt/qcom/aistack/qnn/current)"
    return 0
}
```

---

## 9. Security Considerations

### 9.1 Closed-Source Risk Mitigation

**Given QNN is closed-source, we cannot audit the binary code.** Mitigations:

1. **Isolation**: Run QNN processes in restricted systemd units with minimal capabilities
2. **Network Denial**: Block outbound network unless required for inference
3. **Filesystem Sandboxing**: Mount SDK as read-only, isolate writable directories
4. **Monitoring**: Log all QNN process activity via systemd journal and auditd
5. **Principle of Least Privilege**: Service account has no shell, no sudo, no home directory

### 9.2 Supply Chain Security

1. **Verification**: Always verify SHA-256 hashes from Qualcomm portal
2. **Trusted Source**: Only download from official Qualcomm Developer Network
3. **License Validation**: Ensure `qpm-cli --license-status` shows active license
4. **Audit Trail**: Maintain INSTALL_RECORD.txt with checksums and dates

### 9.3 Runtime Protections

| Protection | Mechanism | Rationale |
|------------|-----------|-----------|
| Stack Canary | `-fstack-protector-strong` | Detect buffer overflows |
| DEP (NX) | `-Wl,-z,noexecstack` | Prevent shellcode execution |
| ASLR | `-fPIE -pie` | Randomize memory layout |
| RELRO | `-Wl,-z,relro,-z,now` | Harden GOT/PLT |
| CFI | `-fcf-protection=full` | Prevent ROP attacks |
| Fortify | `-D_FORTIFY_SOURCE=3` | Enhanced bounds checking |

### 9.4 Incident Response

If suspicious activity is detected:

```bash
# 1. Immediately stop service
systemctl stop qnn-inference.service

# 2. Capture process state
ps auxf | grep qnn > /tmp/qnn-incident-$(date +%s).txt
lsof -p $(pgrep -f qnn) >> /tmp/qnn-incident-$(date +%s).txt

# 3. Check for unauthorized file modifications
find /opt/qcom/aistack/qnn -type f -mtime -1 -ls

# 4. Review logs
journalctl -u qnn-inference.service --since "1 hour ago" > /tmp/qnn-logs-$(date +%s).txt

# 5. Verify SDK integrity
sha256sum -c /opt/qcom/aistack/qnn/INSTALL_RECORD.txt

# 6. Contact security team with collected evidence
```

---

## 10. Performance Optimization

### 10.1 Backend Selection

QNN supports multiple backends:

| Backend | Use Case | Command Flag |
|---------|----------|--------------|
| `cpu` | Development, debugging | `--backend cpu` |
| `gpu` | Qualcomm Adreno GPUs | `--backend gpu` |
| `dsp` | Hexagon DSP (mobile SoCs) | `--backend dsp` |
| `htp` | Hexagon Tensor Processor (latest) | `--backend htp` |

**Production Recommendation**: Use `htp` for best performance on supported hardware.

### 10.2 Model Optimization

```bash
# Quantize model to INT8 for faster inference
qnn-onnx-converter \
    --input_network model.onnx \
    --output_path model_quantized.qnn \
    --quantization_overrides quantization_config.json

# Benchmark different backends
for backend in cpu gpu htp; do
    qnn-profile \
        --backend $backend \
        --model model_quantized.qnn \
        --iterations 100
done
```

### 10.3 Compiler Flags for QNN-Accelerated Applications

When building applications that use QNN, apply HARDVINO hardening + optimization:

```bash
gcc \
    -O3 -march=native \
    -fstack-protector-strong \
    -D_FORTIFY_SOURCE=3 \
    -fcf-protection=full \
    -I$QNN_SDK_ROOT/include \
    -L$QNN_SDK_ROOT/lib/x86_64-linux-gnu \
    -lQnnCpu -lQnnSystem \
    -Wl,-z,relro,-z,now \
    -o qnn_app main.c
```

---

## 11. Troubleshooting

### Issue: `libQnnCpu.so: cannot open shared object file`

**Cause**: LD_LIBRARY_PATH not set correctly.

**Fix**:
```bash
export LD_LIBRARY_PATH=/opt/qcom/aistack/qnn/current/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
ldconfig  # As root, if you want persistent changes
```

### Issue: `qpm-cli: command not found`

**Cause**: Qualcomm Package Manager not installed.

**Fix**:
```bash
dpkg -i qualcomm-qpm-cli_*.deb
apt-get install -f
```

### Issue: `Permission denied` when running QNN tools

**Cause**: User not in `qnnsvc` group or insufficient file permissions.

**Fix**:
```bash
# Add user to group
sudo usermod -aG qnnsvc $USER

# Re-login or start new shell
newgrp qnnsvc

# Verify group membership
groups
```

### Issue: Systemd service fails with `MemoryDenyWriteExecute=yes`

**Cause**: QNN SDK may use JIT compilation internally.

**Fix** (reduce security if necessary):
```ini
# In /etc/systemd/system/qnn-inference.service
# Comment out or remove:
# MemoryDenyWriteExecute=yes

# Restart service
systemctl daemon-reload
systemctl restart qnn-inference.service
```

**Security Note**: Only disable MemoryDenyWriteExecute if QNN fails to run with it enabled. Document this exception in INSTALL_RECORD.txt.

---

## 12. References

- **Qualcomm QNN Documentation**: [https://developer.qualcomm.com/qnn](https://developer.qualcomm.com/qnn)
- **Systemd Hardening**: [https://www.freedesktop.org/software/systemd/man/systemd.exec.html](https://www.freedesktop.org/software/systemd/man/systemd.exec.html)
- **HARDVINO Build System**: See `docs/DSMIL_INTEGRATION.md`
- **Debian Security Manual**: [https://www.debian.org/doc/manuals/securing-debian-manual/](https://www.debian.org/doc/manuals/securing-debian-manual/)

---

## Appendix A: Automated Installation Script

**WARNING**: Review and customize before running in production.

```bash
#!/bin/bash
# qnn_install.sh - Automated QNN SDK hardened installation
set -euo pipefail

QNN_VERSION="2.18.0"
QNN_ARCHIVE="qualcomm_ai_engine_direct_${QNN_VERSION}.zip"
INSTALL_ROOT="/opt/qcom/aistack/qnn"

echo "[*] Installing Qualcomm QNN SDK ${QNN_VERSION}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "[!] This script must be run as root"
    exit 1
fi

# Install dependencies
echo "[*] Installing dependencies..."
apt update
apt install -y python3.10 python3.10-venv build-essential cmake unzip libstdc++6

# Create service account
echo "[*] Creating qnnsvc service account..."
if ! getent group qnnsvc > /dev/null; then
    groupadd --system qnnsvc
fi
if ! getent passwd qnnsvc > /dev/null; then
    useradd --system --gid qnnsvc --no-create-home --shell /usr/sbin/nologin qnnsvc
fi

# Verify SDK archive
echo "[*] Verifying SDK archive SHA-256..."
if [[ ! -f "$QNN_ARCHIVE" ]]; then
    echo "[!] Archive not found: $QNN_ARCHIVE"
    echo "[!] Download from Qualcomm portal and place in current directory"
    exit 1
fi

# TODO: Replace with actual hash from Qualcomm portal
# EXPECTED_HASH="abcdef1234567890..."
# ACTUAL_HASH=$(sha256sum "$QNN_ARCHIVE" | awk '{print $1}')
# if [[ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]]; then
#     echo "[!] SHA-256 mismatch! Aborting."
#     exit 1
# fi

# Extract SDK
echo "[*] Extracting SDK to ${INSTALL_ROOT}/${QNN_VERSION}..."
mkdir -p "${INSTALL_ROOT}/${QNN_VERSION}"
unzip -q "$QNN_ARCHIVE" -d "${INSTALL_ROOT}/${QNN_VERSION}"

# Harden permissions
echo "[*] Hardening filesystem permissions..."
chown -R root:qnnsvc "${INSTALL_ROOT}/${QNN_VERSION}"
chmod -R 0750 "${INSTALL_ROOT}/${QNN_VERSION}"
chmod -R 0555 "${INSTALL_ROOT}/${QNN_VERSION}"/lib

# Create symlink
echo "[*] Creating version symlink..."
ln -sf "${INSTALL_ROOT}/${QNN_VERSION}" "${INSTALL_ROOT}/current"

# Create install record
echo "[*] Recording installation metadata..."
cat > "${INSTALL_ROOT}/INSTALL_RECORD.txt" << EOF
Installation Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
QNN SDK Version: ${QNN_VERSION}
Installed By: $(whoami)
Host: $(hostname)
Kernel: $(uname -r)
SHA256: $(sha256sum "$QNN_ARCHIVE" | awk '{print $1}')
EOF

chmod 0640 "${INSTALL_ROOT}/INSTALL_RECORD.txt"

echo "[✓] QNN SDK installation complete!"
echo ""
echo "Next steps:"
echo "  1. Add to ~/.profile: export QNN_SDK_ROOT=${INSTALL_ROOT}/current"
echo "  2. Run dependency checks: \$QNN_SDK_ROOT/bin/check-python-dependency"
echo "  3. Configure systemd service: /etc/systemd/system/qnn-inference.service"
echo "  4. See docs/QNN_INTEGRATION.md for full configuration"
```

---

## Appendix B: Example QNN Application

Minimal C application using QNN CPU backend:

```c
// qnn_hello.c - Minimal QNN inference example
#include <stdio.h>
#include <stdlib.h>
#include "QnnInterface.h"
#include "QnnTypes.h"

int main() {
    Qnn_Version_t qnnVersion;

    // Initialize QNN backend
    QnnInterface_t* qnnInterface = NULL;
    Qnn_ErrorHandle_t err = QnnInterface_getProviders(
        (const QnnInterface_t***)&qnnInterface,
        (uint32_t*)&qnnVersion
    );

    if (err != QNN_SUCCESS) {
        fprintf(stderr, "Failed to get QNN providers: %d\n", err);
        return 1;
    }

    printf("QNN SDK Version: %u.%u.%u\n",
        qnnVersion.major,
        qnnVersion.minor,
        qnnVersion.patch
    );

    // TODO: Load model, run inference, get results

    return 0;
}
```

**Compile with**:
```bash
gcc -O3 \
    -fstack-protector-strong \
    -D_FORTIFY_SOURCE=3 \
    -I$QNN_SDK_ROOT/include \
    -L$QNN_SDK_ROOT/lib/x86_64-linux-gnu \
    -lQnnCpu -lQnnSystem \
    -Wl,-z,relro,-z,now \
    -o qnn_hello qnn_hello.c
```

---

**Document Version**: 1.0
**Last Updated**: 2025-11-24
**Maintained By**: HARDVINO Integration Team
