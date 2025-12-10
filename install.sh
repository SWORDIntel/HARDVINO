#!/bin/bash
# ============================================================================
# HARDVINO - Intel Acceleration Stack Single Entrypoint
# ============================================================================
#
# Complete build and install for Intel AI compute stack optimized for
# Meteor Lake (Core Ultra 7 165H) with NPU, iGPU, and AVX-VNNI.
#
# Usage:
#   ./install.sh                    # Full install
#   ./install.sh --init             # Initialize submodules only
#   ./install.sh --core             # Build core components only
#   ./install.sh --all              # Build everything
#   ./install.sh --deps             # Install system dependencies
#   ./install.sh --platform         # Install PLATFORM AI framework
#   ./install.sh --help             # Show help
#
# DSMIL Integration:
#   git submodule add https://github.com/SWORDIntel/HARDVINO.git hardvino
#   ./hardvino/install.sh --all
#
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HARDVINO_ROOT="${SCRIPT_DIR}"
export INSTALL_DIR="${HARDVINO_ROOT}/install"
export BUILD_DIR="${HARDVINO_ROOT}/build"

# ============================================================================
# COLORS
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${CYAN}${BOLD}=== $1 ===${NC}\n"; }
log_header()  { echo -e "\n${BLUE}${BOLD}$1${NC}"; }

# ============================================================================
# METEOR TRUE FLAG PROFILE (OPTIMAL + SECURITY for defensive workloads)
# Applied only to build steps (core/extended), not to dependency installs.
# Combines OPTIMAL flags (preserves numerical precision) with SECURITY flags
# (stack protection, CFI, hardening) for defensive AI/ML workloads.
# ============================================================================
load_meteor_flags() {
    local flags_file="${SCRIPT_DIR}/METEOR_TRUE_FLAGS.sh"
    if [ -f "${flags_file}" ]; then
        # shellcheck disable=SC1090
        source "${flags_file}"
        export CFLAGS="${CFLAGS_OPTIMAL} ${CFLAGS_SECURITY}"
        export CXXFLAGS="${CXXFLAGS_OPTIMAL} ${CFLAGS_SECURITY}"
        export LDFLAGS="${LDFLAGS_OPTIMAL} ${LDFLAGS_SECURITY}"
        export KCFLAGS="${KCFLAGS} ${CFLAGS_SECURITY}"
        export KCPPFLAGS="${KCFLAGS}"
        log_info "Applied METEOR TRUE OPTIMAL + SECURITY flags (defensive workload: preserves precision + hardening)"
    else
        log_warn "METEOR_TRUE_FLAGS.sh not found; using toolchain defaults"
    fi
}

# ============================================================================
# SOURCE ENVIRONMENT AND BUILD ORDER
# ============================================================================

source_env() {
    if [ -f "${SCRIPT_DIR}/scripts/intel_env.sh" ]; then
        source "${SCRIPT_DIR}/scripts/intel_env.sh"
    fi
    if [ -f "${SCRIPT_DIR}/scripts/build_order.sh" ]; then
        source "${SCRIPT_DIR}/scripts/build_order.sh"
    fi
}

# ============================================================================
# HELP
# ============================================================================

show_help() {
    cat << 'EOF'
HARDVINO - Intel Acceleration Stack Installer

Usage: ./install.sh [options]

Options:
  --init          Initialize all submodules (shallow clone)
  --deps          Install system dependencies
  --core          Build core components (OpenVINO, oneDNN, oneTBB)
  --extended      Build extended Intel stack (GPU, media, QAT, tools)
  --platform      Install PLATFORM AI framework
  --all           Build everything (core + extended + platform)
  --clean         Clean build directories before building
  --jobs N        Number of parallel jobs (default: nproc)
  --help          Show this help

Examples:
  ./install.sh --init --deps --all    # Full setup from scratch
  ./install.sh --core                 # Just core components
  ./install.sh --platform             # Install AI platform

DSMIL Integration:
  In parent project:
    git submodule add https://github.com/SWORDIntel/HARDVINO.git hardvino
    ./hardvino/install.sh --init --all

  In CMakeLists.txt:
    include(hardvino/cmake/HARDVINOConfig.cmake)
    target_link_hardvino(your_target)

  Environment:
    source hardvino/install/setup_hardvino.sh
EOF
}

# ============================================================================
# PARSE ARGUMENTS
# ============================================================================

DO_INIT=0
DO_DEPS=0
DO_CORE=0
DO_EXTENDED=0
DO_PLATFORM=0
DO_CLEAN=0
JOBS="${JOBS:-$(nproc)}"

if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --init)      DO_INIT=1; shift ;;
        --deps)      DO_DEPS=1; shift ;;
        --core)      DO_CORE=1; shift ;;
        --extended)  DO_EXTENDED=1; shift ;;
        --platform)  DO_PLATFORM=1; shift ;;
        --all)       DO_CORE=1; DO_EXTENDED=1; DO_PLATFORM=1; shift ;;
        --clean)     DO_CLEAN=1; shift ;;
        --jobs)      JOBS="$2"; shift 2 ;;
        --help|-h)   show_help; exit 0 ;;
        *)           log_error "Unknown option: $1"; exit 1 ;;
    esac
done

# ============================================================================
# BANNER
# ============================================================================

show_banner() {
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
  _   _   _   ___  ___   _   _ ___ _  _  ___
 | | | | /_\ | _ \|   \ | | | |_ _| \| |/ _ \
 | |_| |/ _ \|   /| |) || |_| || || .` | (_) |
 |___|_/_/ \_\_|_\|___/  \___/|___|_|\_|\___/

 Intel Acceleration Stack for DSMIL
 Target: Intel Core Ultra 7 165H (Meteor Lake)
EOF
    echo -e "${NC}"
    echo "Submodules: 34 | HARDVINO supersedes OpenVINO"
    echo "Jobs: ${JOBS}"
    echo ""
}

# ============================================================================
# INITIALIZE SUBMODULES
# ============================================================================

init_submodules() {
    log_section "Initializing Submodules"
    cd "${HARDVINO_ROOT}"

    # Core submodules (required)
    # Note: HARDVINO supersedes upstream OpenVINO - no separate openvino submodule
    log_info "Initializing core submodules..."
    git submodule update --init --depth 1 oneapi-tbb oneapi-dnn NUC2.1

    # Extended submodules
    log_info "Initializing extended Intel stack..."
    git submodule update --init --depth 1 submodules/

    # PLATFORM
    if [ -d "submodules/PLATFORM" ]; then
        log_info "Initializing PLATFORM..."
        git submodule update --init --depth 1 submodules/PLATFORM
    fi

    log_info "All submodules initialized (34 total)"
}

# ============================================================================
# INSTALL DEPENDENCIES
# ============================================================================

install_deps() {
    log_section "Installing System Dependencies"

    sudo apt-get update
    sudo apt-get install -y \
        build-essential git cmake ninja-build pkg-config \
        autoconf automake libtool \
        clang lld llvm \
        python3 python3-pip python3-dev python3-venv \
        libssl-dev libusb-1.0-0-dev \
        libva-dev libdrm-dev libpciaccess-dev \
        libx11-dev libxext-dev libxfixes-dev \
        libnuma-dev libhwloc-dev \
        ocl-icd-opencl-dev opencl-headers \
        zlib1g-dev libzstd-dev liblz4-dev \
        libprotobuf-dev protobuf-compiler \
        libopencv-dev \
        nasm yasm \
        cargo rustc

    # Python packages
    pip3 install --user numpy pytest pybind11 cython wheel

    log_info "Dependencies installed"
}

# ============================================================================
# BUILD CORE
# ============================================================================

build_core() {
    log_section "Building Core Components"
    source_env
    load_meteor_flags

    cd "${HARDVINO_ROOT}"

    if [ -x "./build_all.sh" ]; then
        log_info "Using HARDVINO build_all.sh..."
        ./build_all.sh --skip-kernel
    else
        log_error "build_all.sh not found"
        exit 1
    fi
}

# ============================================================================
# BUILD EXTENDED (Staged Build)
# ============================================================================

build_extended() {
    log_section "Building Extended Intel Stack (Staged)"
    source_env
    load_meteor_flags

    export JOBS="${JOBS:-$(nproc)}"
    export BUILD_DIR="${BUILD_DIR:-${HARDVINO_ROOT}/build}"
    export INSTALL_DIR="${INSTALL_DIR:-${HARDVINO_ROOT}/install}"

    mkdir -p "${BUILD_DIR}" "${INSTALL_DIR}"

    # Run stages 4-8 (runtimes, media, qat, frameworks, tools)
    # Stages 1-3 are handled by build_core via build_all.sh
    if type -t stage4_runtimes &>/dev/null; then
        log_info "Running staged builds (4-8)..."
        stage4_runtimes || log_warn "Stage 4 (runtimes) had errors"
        stage5_media || log_warn "Stage 5 (media) had errors"
        stage6_qat || log_warn "Stage 6 (qat) had errors"
        stage7_frameworks || log_warn "Stage 7 (frameworks) had errors"
        stage8_tools || log_warn "Stage 8 (tools) had errors"
    elif [ -x "${SCRIPT_DIR}/scripts/build_intel_stack.sh" ]; then
        log_info "Fallback to build_intel_stack.sh..."
        "${SCRIPT_DIR}/scripts/build_intel_stack.sh" --all
    else
        log_warn "No extended build system found"
    fi
}

# ============================================================================
# INSTALL PLATFORM
# ============================================================================

install_platform() {
    log_section "Installing PLATFORM AI Framework"
    source_env

    local PLATFORM_DIR="${HARDVINO_ROOT}/submodules/PLATFORM"

    if [ ! -d "${PLATFORM_DIR}" ]; then
        log_error "PLATFORM submodule not found. Run --init first."
        return 1
    fi

    cd "${PLATFORM_DIR}"

    # Check for install script or setup.py
    if [ -x "./install.sh" ]; then
        log_info "Running PLATFORM install.sh..."
        ./install.sh
    elif [ -f "setup.py" ]; then
        log_info "Installing PLATFORM via pip..."
        pip3 install --user -e .
    elif [ -f "CMakeLists.txt" ]; then
        log_info "Building PLATFORM with CMake..."
        mkdir -p build && cd build
        cmake .. \
            -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}/platform" \
            -DCMAKE_C_COMPILER="${CC:-clang}" \
            -DCMAKE_CXX_COMPILER="${CXX:-clang++}"
        cmake --build . --parallel "${JOBS}"
        cmake --install .
    else
        log_warn "No build system found in PLATFORM, skipping"
    fi
}

# ============================================================================
# GENERATE UNIFIED SETUP SCRIPT
# ============================================================================

generate_setup() {
    log_section "Generating Setup Script"

    mkdir -p "${INSTALL_DIR}"

    cat > "${INSTALL_DIR}/setup_hardvino.sh" << 'SETUPEOF'
#!/bin/bash
# HARDVINO - Unified Environment Setup
# Source this file: source install/setup_hardvino.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARDVINO_ROOT="$(dirname "${SCRIPT_DIR}")"

export HARDVINO_ROOT
export HARDVINO_INSTALL="${SCRIPT_DIR}"

# OpenVINO
if [ -f "${SCRIPT_DIR}/openvino/setupvars.sh" ]; then
    source "${SCRIPT_DIR}/openvino/setupvars.sh"
fi

# Library paths
for lib_dir in \
    "${SCRIPT_DIR}/openvino/runtime/lib/intel64" \
    "${SCRIPT_DIR}/oneapi-tbb/lib" \
    "${SCRIPT_DIR}/oneapi-dnn/lib" \
    "${SCRIPT_DIR}/intel-stack"/**/lib
do
    [ -d "$lib_dir" ] && export LD_LIBRARY_PATH="${lib_dir}:${LD_LIBRARY_PATH}"
done

# Python
export PYTHONPATH="${SCRIPT_DIR}/openvino/python:${PYTHONPATH}"

# CMake
export CMAKE_PREFIX_PATH="${SCRIPT_DIR}/openvino:${CMAKE_PREFIX_PATH}"
export CMAKE_PREFIX_PATH="${SCRIPT_DIR}/oneapi-tbb:${CMAKE_PREFIX_PATH}"
export CMAKE_PREFIX_PATH="${SCRIPT_DIR}/oneapi-dnn:${CMAKE_PREFIX_PATH}"

# Source Intel env flags
if [ -f "${HARDVINO_ROOT}/scripts/intel_env.sh" ]; then
    source "${HARDVINO_ROOT}/scripts/intel_env.sh"
fi

echo "[HARDVINO] Environment loaded from ${SCRIPT_DIR}"
SETUPEOF

    chmod +x "${INSTALL_DIR}/setup_hardvino.sh"
    log_info "Setup script: ${INSTALL_DIR}/setup_hardvino.sh"
}

# ============================================================================
# CLEAN
# ============================================================================

clean_build() {
    log_section "Cleaning Build Directories"
    rm -rf "${BUILD_DIR}"
    rm -rf "${HARDVINO_ROOT}/build"
    log_info "Build directories cleaned"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    show_banner

    [[ $DO_CLEAN -eq 1 ]] && clean_build
    [[ $DO_INIT -eq 1 ]] && init_submodules
    [[ $DO_DEPS -eq 1 ]] && install_deps
    [[ $DO_CORE -eq 1 ]] && build_core
    [[ $DO_EXTENDED -eq 1 ]] && build_extended
    [[ $DO_PLATFORM -eq 1 ]] && install_platform

    generate_setup

    log_section "Installation Complete"
    echo ""
    echo "To use HARDVINO:"
    echo "  source ${INSTALL_DIR}/setup_hardvino.sh"
    echo ""
    echo "For DSMIL integration:"
    echo "  include(hardvino/cmake/HARDVINOConfig.cmake)"
    echo ""
}

main "$@"
