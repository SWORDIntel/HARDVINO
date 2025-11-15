#!/bin/bash
# ============================================================================
# HARDVINO - Master Build Script
# Builds complete hardened OpenVINO/OneAPI suite with NPU support
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# COLOR OUTPUT
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
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

log_build() {
    echo -e "${BLUE}[BUILD]${NC} $1"
}

log_success() {
    echo -e "${CYAN}[SUCCESS]${NC} $1"
}

# ============================================================================
# BANNER
# ============================================================================

print_banner() {
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║  ██   ██  █████  ██████  ██████  ██    ██ ██ ███    ██  ██████          ║
║  ██   ██ ██   ██ ██   ██ ██   ██ ██    ██ ██ ████   ██ ██    ██         ║
║  ███████ ███████ ██████  ██   ██ ██    ██ ██ ██ ██  ██ ██    ██         ║
║  ██   ██ ██   ██ ██   ██ ██   ██  ██  ██  ██ ██  ██ ██ ██    ██         ║
║  ██   ██ ██   ██ ██   ██ ██████    ████   ██ ██   ████  ██████          ║
║                                                                          ║
║  Hardened OpenVINO/OneAPI Build System                                  ║
║  NPU VPU 3720 Support + Military-Grade Security                         ║
║  Intel Meteor Lake Optimized                                            ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
EOF
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

CLEAN_BUILD=0
SKIP_ONEAPI=0
SKIP_OPENVINO=0
SKIP_KERNEL_INTEGRATION=0
VERBOSE=0

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build the complete HARDVINO suite with hardening and NPU support.

OPTIONS:
    --clean                 Clean build (remove existing build directories)
    --skip-oneapi          Skip OneAPI build
    --skip-openvino        Skip OpenVINO build
    --skip-kernel          Skip kernel integration setup
    --verbose              Verbose output
    -h, --help             Show this help message

EXAMPLES:
    $0                     # Build everything
    $0 --clean             # Clean build
    $0 --skip-oneapi       # Build only OpenVINO
    $0 --verbose           # Verbose build output

EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN_BUILD=1
            shift
            ;;
        --skip-oneapi)
            SKIP_ONEAPI=1
            shift
            ;;
        --skip-openvino)
            SKIP_OPENVINO=1
            shift
            ;;
        --skip-kernel)
            SKIP_KERNEL_INTEGRATION=1
            shift
            ;;
        --verbose)
            VERBOSE=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# ============================================================================
# CLEAN BUILD
# ============================================================================

clean_build() {
    log_warn "Cleaning previous build..."
    rm -rf "${SCRIPT_DIR}/build"
    rm -rf "${SCRIPT_DIR}/install"
    log_info "Clean complete"
}

# ============================================================================
# DEPENDENCY CHECK
# ============================================================================

check_system_dependencies() {
    log_info "Checking system dependencies..."

    local deps=(
        "git:git"
        "cmake:cmake"
        "ninja:ninja-build"
        "gcc:gcc"
        "g++:g++"
        "python3:python3"
        "pip3:python3-pip"
        "pkg-config:pkg-config"
        "autoconf:autoconf"
        "automake:automake"
        "libtoolize:libtool"
    )

    local missing_cmds=()
    local missing_pkgs=()

    for dep in "${deps[@]}"; do
        IFS=':' read -r cmd pkg <<< "$dep"
        if ! command -v "$cmd" &> /dev/null; then
            missing_cmds+=("$cmd")
            missing_pkgs+=("$pkg")
        fi
    done

    if [ ${#missing_cmds[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_cmds[*]}"
        echo ""
        echo "Install with:"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install -y ${missing_pkgs[*]}"
        echo ""
        exit 1
    fi

    log_success "All dependencies satisfied"
}

# ============================================================================
# SUBMODULE INITIALIZATION
# ============================================================================

init_submodules() {
    log_info "Initializing git submodules..."

    cd "${SCRIPT_DIR}"

    # Check if we're in a git repository
    if [ ! -d ".git" ]; then
        log_error "Not a git repository. Cannot initialize submodules."
        exit 1
    fi

    # Initialize and update submodules
    git submodule update --init --recursive --depth 1

    # Verify critical submodules
    local critical_submodules=(
        "oneapi-tbb"
        "oneapi-dnn"
    )

    if [ $SKIP_OPENVINO -eq 0 ]; then
        critical_submodules+=("openvino")
    fi

    for submodule in "${critical_submodules[@]}"; do
        if [ ! -f "${SCRIPT_DIR}/${submodule}/.git" ]; then
            log_error "Critical submodule not initialized: ${submodule}"
            exit 1
        fi
    done

    log_success "Submodules initialized"
}

# ============================================================================
# BUILD STEPS
# ============================================================================

build_oneapi() {
    if [ $SKIP_ONEAPI -eq 1 ]; then
        log_warn "Skipping OneAPI build"
        return
    fi

    log_build "Building OneAPI (TBB + oneDNN)..."
    bash "${SCRIPT_DIR}/build_hardened_oneapi.sh"
    log_success "OneAPI build complete"
}

build_openvino() {
    if [ $SKIP_OPENVINO -eq 1 ]; then
        log_warn "Skipping OpenVINO build"
        return
    fi

    log_build "Building OpenVINO with NPU support..."
    bash "${SCRIPT_DIR}/build_hardened_openvino.sh"
    log_success "OpenVINO build complete"
}

setup_kernel_integration() {
    if [ $SKIP_KERNEL_INTEGRATION -eq 1 ]; then
        log_warn "Skipping kernel integration setup"
        return
    fi

    log_build "Setting up kernel integration..."
    bash "${SCRIPT_DIR}/kernel_integration.sh"
    log_success "Kernel integration setup complete"
}

# ============================================================================
# POST-BUILD VERIFICATION
# ============================================================================

verify_build() {
    log_info "Verifying build..."

    local errors=0

    # Check OneAPI
    if [ $SKIP_ONEAPI -eq 0 ]; then
        if [ ! -f "${SCRIPT_DIR}/install/oneapi-tbb/lib/libtbb.so" ]; then
            log_error "oneTBB library not found"
            ((errors++))
        fi
        if [ ! -f "${SCRIPT_DIR}/install/oneapi-dnn/lib/libdnnl.so" ]; then
            log_error "oneDNN library not found"
            ((errors++))
        fi
    fi

    # Check OpenVINO
    if [ $SKIP_OPENVINO -eq 0 ]; then
        if [ ! -f "${SCRIPT_DIR}/install/openvino/lib/libopenvino.so" ]; then
            log_error "OpenVINO library not found"
            ((errors++))
        fi
    fi

    # Check kernel integration
    if [ $SKIP_KERNEL_INTEGRATION -eq 0 ]; then
        if [ ! -f "${SCRIPT_DIR}/kernel_config.mk" ]; then
            log_error "Kernel configuration not found"
            ((errors++))
        fi
    fi

    if [ $errors -eq 0 ]; then
        log_success "Build verification passed"
        return 0
    else
        log_error "Build verification failed with $errors errors"
        return 1
    fi
}

# ============================================================================
# BUILD SUMMARY
# ============================================================================

print_summary() {
    local install_dir="${SCRIPT_DIR}/install"

    cat << EOF

╔══════════════════════════════════════════════════════════════════════════╗
║  BUILD COMPLETE - HARDVINO                                               ║
╚══════════════════════════════════════════════════════════════════════════╝

Installation Directory: ${install_dir}

Components Built:
EOF

    if [ $SKIP_ONEAPI -eq 0 ]; then
        echo "  ✓ oneTBB     : ${install_dir}/oneapi-tbb"
        echo "  ✓ oneDNN     : ${install_dir}/oneapi-dnn"
    fi

    if [ $SKIP_OPENVINO -eq 0 ]; then
        echo "  ✓ OpenVINO   : ${install_dir}/openvino"
    fi

    if [ $SKIP_KERNEL_INTEGRATION -eq 0 ]; then
        echo "  ✓ Kernel Integration Files"
    fi

    cat << EOF

Security Hardening Applied:
  ✓ FORTIFY_SOURCE=3
  ✓ Stack protectors (strong + clash)
  ✓ Control-flow integrity (CFI)
  ✓ Spectre/Meltdown mitigations
  ✓ Full RELRO + PIE
  ✓ Position Independent Code

Architecture Optimizations:
  ✓ Intel Meteor Lake tuning
  ✓ AVX2 + AVX-VNNI
  ✓ AES-NI + SHA extensions
  ✓ NPU VPU 3720 support

Quick Start:
  1. Set up environment:
     source ${install_dir}/setupvars.sh

  2. Initialize NPU:
     init_npu_tactical

  3. Test NPU:
     test_npu_military

Kernel Integration:
  See KERNEL_INTEGRATION.md for detailed instructions

  Quick: Include in your kernel Makefile:
    export HARDVINO_ROOT=${SCRIPT_DIR}
    include \$(HARDVINO_ROOT)/Kbuild.mk

Documentation:
  - README.md              : Overview and usage
  - KERNEL_INTEGRATION.md  : Kernel build integration guide
  - example_module/        : Example kernel module

EOF

    if command -v checksec &> /dev/null && [ $SKIP_OPENVINO -eq 0 ]; then
        echo "Security Verification (checksec):"
        checksec --file="${install_dir}/openvino/lib/libopenvino.so" 2>/dev/null || true
        echo ""
    fi

    cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════╗
║  HARDVINO is ready for deployment                                       ║
╚══════════════════════════════════════════════════════════════════════════╝

EOF
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_banner

    # Clean build if requested
    if [ $CLEAN_BUILD -eq 1 ]; then
        clean_build
    fi

    # Pre-build checks
    check_system_dependencies
    init_submodules

    # Build components
    build_oneapi
    build_openvino
    setup_kernel_integration

    # Post-build verification
    if ! verify_build; then
        log_error "Build verification failed"
        exit 1
    fi

    # Make all scripts executable
    chmod +x "${SCRIPT_DIR}"/*.sh

    # Print summary
    print_summary

    log_success "HARDVINO build completed successfully!"
}

# Execute main
main "$@"
