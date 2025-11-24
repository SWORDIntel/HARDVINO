#!/bin/bash
# ============================================================================
# NVIDIA Open GPU Kernel Modules Build Script (Hardened)
# HARDVINO / DSMIL Platform
# ============================================================================
#
# Purpose: Build NVIDIA open-gpu-kernel-modules with HARDVINO security hardening
#
# Usage:
#   ./scripts/build_nvidia.sh [--build] [--sign] [--install] [--dkms] [--verify] [--clean]
#
# Options:
#   --build     Build kernel modules with hardening flags
#   --sign      Sign modules for Secure Boot
#   --install   Install modules to system
#   --dkms      Configure DKMS auto-rebuild
#   --verify    Verify installation
#   --clean     Clean build artifacts
#   --all       Build, sign, install, and configure DKMS
#
# Security Features:
#   - Stack protector (strong + clash protection)
#   - Control-Flow Integrity (CET/CFI)
#   - FORTIFY_SOURCE=3 (buffer overflow detection)
#   - Full RELRO (relocation read-only)
#   - Module signing for Secure Boot
#
# See: docs/NVIDIA_INTEGRATION.md for full documentation
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARDVINO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NVIDIA_SUBMODULE="$HARDVINO_ROOT/submodules/nvidia-stack/drivers/open-gpu-kernel-modules"
KERNEL_VERSION=$(uname -r)
NVIDIA_VERSION=""  # Will be detected from git tag

# MOK key paths (for Secure Boot signing)
MOK_KEY="/var/lib/shim-signed/mok/MOK.priv"
MOK_CERT="/var/lib/shim-signed/mok/MOK.der"

# Build flags
DO_BUILD=0
DO_SIGN=0
DO_INSTALL=0
DO_DKMS=0
DO_VERIFY=0
DO_CLEAN=0

# ============================================================================
# Helper Functions
# ============================================================================

log() {
    local level=$1
    shift
    local message="$*"

    case $level in
        INFO)
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} $message" >&2
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        SUCCESS)
            echo -e "${GREEN}[✓]${NC} $message"
            ;;
        STEP)
            echo -e "${CYAN}[STEP]${NC} $message"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log ERROR "This operation requires root privileges"
        log ERROR "Please run with sudo: sudo $0 $*"
        exit 1
    fi
}

check_dependencies() {
    log STEP "Checking build dependencies..."

    local missing_deps=()

    # Required packages
    local required_packages=(
        "build-essential"
        "linux-headers-$KERNEL_VERSION"
        "kmod"
        "gcc"
        "make"
    )

    for pkg in "${required_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$pkg" 2>/dev/null; then
            if ! command -v gcc &>/dev/null && [[ "$pkg" == "build-essential" ]]; then
                missing_deps+=("$pkg")
            fi
        fi
    done

    # Check for kernel headers
    if [[ ! -d "/lib/modules/$KERNEL_VERSION/build" ]]; then
        missing_deps+=("linux-headers-$KERNEL_VERSION")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log ERROR "Missing dependencies: ${missing_deps[*]}"
        log ERROR "Install with: sudo apt install ${missing_deps[*]}"
        exit 1
    fi

    log SUCCESS "All dependencies found"
}

detect_nvidia_version() {
    log STEP "Detecting NVIDIA driver version..."

    cd "$NVIDIA_SUBMODULE"

    # Get current git tag or commit
    if git describe --tags --exact-match &>/dev/null; then
        NVIDIA_VERSION=$(git describe --tags --exact-match)
    else
        NVIDIA_VERSION=$(git rev-parse --short HEAD)
    fi

    log INFO "NVIDIA version: $NVIDIA_VERSION"
}

# ============================================================================
# Build Functions
# ============================================================================

build_modules() {
    log STEP "Building NVIDIA kernel modules with HARDVINO hardening..."

    cd "$NVIDIA_SUBMODULE"

    # HARDVINO hardening flags
    export HARDVINO_HARDENING_FLAGS="\
        -fstack-protector-strong \
        -fstack-clash-protection \
        -fcf-protection=full \
        -D_FORTIFY_SOURCE=3"

    # Optimization flags (native architecture)
    export HARDVINO_OPTIMIZATION_FLAGS="\
        -O3 \
        -march=native \
        -mtune=native"

    # Linker hardening flags
    export HARDVINO_LINKER_FLAGS="\
        -Wl,-z,relro,-z,now \
        -Wl,-z,noexecstack"

    # Combine flags
    export CFLAGS_MODULE="$HARDVINO_OPTIMIZATION_FLAGS $HARDVINO_HARDENING_FLAGS"
    export LDFLAGS_MODULE="$HARDVINO_LINKER_FLAGS"

    log INFO "Build flags:"
    log INFO "  CFLAGS: $CFLAGS_MODULE"
    log INFO "  LDFLAGS: $LDFLAGS_MODULE"

    # Clean previous build
    make clean &>/dev/null || true

    # Build kernel modules
    log INFO "Building modules (this may take 5-10 minutes)..."
    if ! make -j$(nproc) modules SYSSRC="/lib/modules/$KERNEL_VERSION/build"; then
        log ERROR "Build failed"
        exit 1
    fi

    log SUCCESS "Build complete"

    # Verify built modules
    log STEP "Verifying built modules..."
    cd kernel-open

    local modules=("nvidia.ko" "nvidia-modeset.ko" "nvidia-uvm.ko" "nvidia-drm.ko")
    for mod in "${modules[@]}"; do
        if [[ -f "$mod" ]]; then
            local size=$(du -h "$mod" | awk '{print $1}')
            log SUCCESS "Built: $mod ($size)"
        else
            log ERROR "Missing module: $mod"
            exit 1
        fi
    done
}

sign_modules() {
    log STEP "Signing NVIDIA kernel modules for Secure Boot..."

    # Check if running as root
    check_root

    # Check if MOK keys exist
    if [[ ! -f "$MOK_KEY" ]] || [[ ! -f "$MOK_CERT" ]]; then
        log WARN "MOK signing keys not found"
        log WARN "Expected locations:"
        log WARN "  Private key: $MOK_KEY"
        log WARN "  Certificate: $MOK_CERT"
        log WARN ""
        log WARN "Generate keys with:"
        log WARN "  sudo mkdir -p /var/lib/shim-signed/mok"
        log WARN "  sudo openssl req -new -x509 -newkey rsa:2048 \\"
        log WARN "    -keyout $MOK_KEY \\"
        log WARN "    -outform DER -out $MOK_CERT \\"
        log WARN "    -days 36500 -subj '/CN=HARDVINO Module Signing/' -nodes"
        log WARN "  sudo mokutil --import $MOK_CERT"
        log WARN "  sudo reboot  # Enroll key in MOK Manager"
        log WARN ""
        log WARN "Skipping module signing..."
        return 0
    fi

    cd "$NVIDIA_SUBMODULE/kernel-open"

    # Sign each module
    local sign_script="/lib/modules/$KERNEL_VERSION/build/scripts/sign-file"

    if [[ ! -f "$sign_script" ]]; then
        log ERROR "Kernel signing script not found: $sign_script"
        log ERROR "Install kernel headers: sudo apt install linux-headers-$KERNEL_VERSION"
        exit 1
    fi

    local modules=("nvidia.ko" "nvidia-modeset.ko" "nvidia-uvm.ko" "nvidia-drm.ko")
    for mod in "${modules[@]}"; do
        if [[ -f "$mod" ]]; then
            log INFO "Signing: $mod"
            if ! "$sign_script" sha256 "$MOK_KEY" "$MOK_CERT" "$mod"; then
                log ERROR "Failed to sign: $mod"
                exit 1
            fi

            # Verify signature
            if modinfo "$mod" | grep -q "sig_id"; then
                log SUCCESS "Signed: $mod"
            else
                log WARN "Signature not detected in: $mod (may still work)"
            fi
        fi
    done

    log SUCCESS "Module signing complete"
}

install_modules() {
    log STEP "Installing NVIDIA kernel modules..."

    # Check if running as root
    check_root

    cd "$NVIDIA_SUBMODULE"

    # Install modules
    if ! make modules_install SYSSRC="/lib/modules/$KERNEL_VERSION/build"; then
        log ERROR "Module installation failed"
        exit 1
    fi

    # Update module dependencies
    log INFO "Updating module dependencies..."
    depmod -a

    log SUCCESS "Modules installed to /lib/modules/$KERNEL_VERSION/kernel/drivers/video/"

    # Create persistent load configuration
    log STEP "Configuring persistent module loading..."

    cat > /etc/modules-load.d/nvidia.conf << 'EOF'
# NVIDIA GPU kernel modules (HARDVINO)
nvidia
nvidia-modeset
nvidia-uvm
nvidia-drm
EOF

    log SUCCESS "Created /etc/modules-load.d/nvidia.conf"

    # Set module parameters
    cat > /etc/modprobe.d/nvidia.conf << 'EOF'
# NVIDIA GPU module parameters (HARDVINO)
# Enable DRM kernel mode setting
options nvidia-drm modeset=1

# Enable GPU firmware loading
options nvidia NVreg_EnableGpuFirmware=1

# Preserve video memory across suspend
options nvidia NVreg_PreserveVideoMemoryAllocations=1

# Enable S0ix power management
options nvidia NVreg_EnableS0ixPowerManagement=1
EOF

    log SUCCESS "Created /etc/modprobe.d/nvidia.conf"

    # Update initramfs
    log INFO "Updating initramfs..."
    update-initramfs -u

    log SUCCESS "Installation complete"
}

configure_dkms() {
    log STEP "Configuring DKMS for automatic rebuilds..."

    # Check if running as root
    check_root

    # Check if DKMS is installed
    if ! command -v dkms &>/dev/null; then
        log ERROR "DKMS not installed"
        log ERROR "Install with: sudo apt install dkms"
        exit 1
    fi

    detect_nvidia_version

    local dkms_dir="/usr/src/nvidia-$NVIDIA_VERSION"

    # Copy source to DKMS directory
    log INFO "Copying source to $dkms_dir..."
    mkdir -p "$dkms_dir"
    cp -r "$NVIDIA_SUBMODULE"/* "$dkms_dir/"

    # Create DKMS configuration
    log INFO "Creating DKMS configuration..."
    cat > "$dkms_dir/dkms.conf" << EOF
PACKAGE_NAME="nvidia"
PACKAGE_VERSION="$NVIDIA_VERSION"
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

# Build with HARDVINO hardening
MAKE[0]="make -j\$(nproc) modules SYSSRC=/lib/modules/\$kernelver/build \
    CFLAGS_MODULE='-fstack-protector-strong -fstack-clash-protection -fcf-protection=full -D_FORTIFY_SOURCE=3 -O3 -march=native' \
    LDFLAGS_MODULE='-Wl,-z,relro,-z,now -Wl,-z,noexecstack'"

CLEAN="make clean"
EOF

    # Add to DKMS
    log INFO "Adding nvidia/$NVIDIA_VERSION to DKMS..."
    dkms add -m nvidia -v "$NVIDIA_VERSION" || log WARN "Already added to DKMS"

    # Build with DKMS
    log INFO "Building with DKMS..."
    dkms build -m nvidia -v "$NVIDIA_VERSION"

    # Install with DKMS
    log INFO "Installing with DKMS..."
    dkms install -m nvidia -v "$NVIDIA_VERSION"

    log SUCCESS "DKMS configuration complete"
    log INFO "Modules will auto-rebuild on kernel updates"
}

verify_installation() {
    log STEP "Verifying NVIDIA installation..."

    local errors=0

    # Check if modules exist
    log INFO "Checking installed modules..."
    local modules=("nvidia" "nvidia-modeset" "nvidia-uvm" "nvidia-drm")
    for mod in "${modules[@]}"; do
        if modinfo "$mod" &>/dev/null; then
            local version=$(modinfo "$mod" | grep "^version:" | awk '{print $2}')
            log SUCCESS "Module found: $mod (version: $version)"
        else
            log ERROR "Module not found: $mod"
            ((errors++))
        fi
    done

    # Check if modules can be loaded
    log INFO "Checking if modules can be loaded..."
    for mod in "${modules[@]}"; do
        if lsmod | grep -q "^$mod"; then
            log INFO "$mod is already loaded"
        else
            log INFO "Attempting to load: $mod"
            if modprobe "$mod" 2>/dev/null; then
                log SUCCESS "Loaded: $mod"
            else
                log WARN "Could not load: $mod (may require reboot or GPU present)"
            fi
        fi
    done

    # Check nvidia-smi (if installed)
    if command -v nvidia-smi &>/dev/null; then
        log INFO "Testing nvidia-smi..."
        if nvidia-smi &>/dev/null; then
            log SUCCESS "nvidia-smi working"
            nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
        else
            log WARN "nvidia-smi failed (GPU may not be present or userspace mismatch)"
        fi
    else
        log WARN "nvidia-smi not found (install CUDA toolkit for userspace components)"
    fi

    # Check DKMS status
    if command -v dkms &>/dev/null; then
        log INFO "Checking DKMS status..."
        if dkms status | grep -q nvidia; then
            log SUCCESS "DKMS configured"
            dkms status | grep nvidia
        else
            log WARN "DKMS not configured (run with --dkms to enable)"
        fi
    fi

    # Summary
    echo ""
    if [[ $errors -eq 0 ]]; then
        log SUCCESS "All verification checks passed"
        return 0
    else
        log ERROR "Verification completed with $errors errors"
        return 1
    fi
}

clean_build() {
    log STEP "Cleaning build artifacts..."

    cd "$NVIDIA_SUBMODULE"

    make clean &>/dev/null || true

    log SUCCESS "Clean complete"
}

# ============================================================================
# Main Script
# ============================================================================

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build NVIDIA open-gpu-kernel-modules with HARDVINO security hardening.

OPTIONS:
  --build       Build kernel modules with hardening flags
  --sign        Sign modules for Secure Boot (requires root)
  --install     Install modules to system (requires root)
  --dkms        Configure DKMS auto-rebuild (requires root)
  --verify      Verify installation
  --clean       Clean build artifacts
  --all         Build, sign, install, and configure DKMS

  --help        Show this help message

EXAMPLES:
  # Build only
  $0 --build

  # Build and verify
  $0 --build --verify

  # Complete installation (requires root)
  sudo $0 --all

  # Manual step-by-step
  $0 --build
  sudo $0 --sign --install --dkms
  $0 --verify

See docs/NVIDIA_INTEGRATION.md for full documentation.
EOF
}

main() {
    # Parse arguments
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 0
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --build)
                DO_BUILD=1
                shift
                ;;
            --sign)
                DO_SIGN=1
                shift
                ;;
            --install)
                DO_INSTALL=1
                shift
                ;;
            --dkms)
                DO_DKMS=1
                shift
                ;;
            --verify)
                DO_VERIFY=1
                shift
                ;;
            --clean)
                DO_CLEAN=1
                shift
                ;;
            --all)
                DO_BUILD=1
                DO_SIGN=1
                DO_INSTALL=1
                DO_DKMS=1
                DO_VERIFY=1
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log ERROR "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    echo "============================================================================"
    echo "NVIDIA Open GPU Kernel Modules - HARDVINO Build System"
    echo "============================================================================"
    echo ""

    # Check if submodule exists
    if [[ ! -d "$NVIDIA_SUBMODULE" ]]; then
        log ERROR "NVIDIA submodule not found: $NVIDIA_SUBMODULE"
        log ERROR "Initialize with: git submodule update --init --recursive"
        exit 1
    fi

    # Execute operations
    if [[ $DO_CLEAN -eq 1 ]]; then
        clean_build
    fi

    if [[ $DO_BUILD -eq 1 ]]; then
        check_dependencies
        detect_nvidia_version
        build_modules
    fi

    if [[ $DO_SIGN -eq 1 ]]; then
        sign_modules
    fi

    if [[ $DO_INSTALL -eq 1 ]]; then
        install_modules
    fi

    if [[ $DO_DKMS -eq 1 ]]; then
        configure_dkms
    fi

    if [[ $DO_VERIFY -eq 1 ]]; then
        verify_installation
    fi

    echo ""
    echo "============================================================================"
    log SUCCESS "NVIDIA build script complete"
    echo "============================================================================"
    echo ""
    log INFO "Next steps:"
    echo "  1. Reboot to load new modules: sudo reboot"
    echo "  2. Verify GPU: nvidia-smi"
    echo "  3. Install CUDA toolkit (if needed): sudo apt install cuda-toolkit-12-6"
    echo "  4. See docs/NVIDIA_INTEGRATION.md for full integration guide"
}

# Run main
main "$@"
