#!/bin/bash
# ============================================================================
# Intel Acceleration Stack - Extended Components Build
# HARDVINO / DSMIL Platform
# ============================================================================
#
# Builds OPTIONAL Intel stack components on top of HARDVINO core.
# HARDVINO core (OpenVINO, oneDNN, oneTBB) is built via ./build_all.sh
#
# Usage:
#   ./scripts/build_intel_stack.sh [options] [components...]
#
# Options:
#   --all           Build all optional components
#   --gpu           Build GPU compute runtime (Level Zero, OpenCL)
#   --media         Build media drivers (VAAPI)
#   --qat           Build QAT libraries (crypto/compression)
#   --tools         Build profiling/optimization tools
#   --clean         Clean build directories first
#   --install-deps  Install system dependencies
#   --jobs N        Number of parallel jobs (default: nproc)
#   --help          Show this help
#
# Core HARDVINO components (OpenVINO, oneDNN, oneTBB, NUC2.1) are NOT built
# by this script. Use ./build_all.sh for core components.
#
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
BUILD_DIR="${ROOT_DIR}/build/intel-stack"
INSTALL_DIR="${ROOT_DIR}/install/intel-stack"

# ============================================================================
# COLOR OUTPUT
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${CYAN}=== $1 ===${NC}\n"; }

# ============================================================================
# SOURCE ENVIRONMENT
# ============================================================================

source "${SCRIPT_DIR}/intel_env.sh" 2>/dev/null || true

# ============================================================================
# DEFAULT CONFIGURATION
# ============================================================================

JOBS="${JOBS:-$(nproc)}"
CLEAN_BUILD=0
INSTALL_DEPS=0
BUILD_GPU=0
BUILD_MEDIA=0
BUILD_QAT=0
BUILD_TOOLS=0
BUILD_ALL=0

# ============================================================================
# PARSE ARGUMENTS
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)          BUILD_ALL=1; shift ;;
        --gpu)          BUILD_GPU=1; shift ;;
        --media)        BUILD_MEDIA=1; shift ;;
        --qat)          BUILD_QAT=1; shift ;;
        --tools)        BUILD_TOOLS=1; shift ;;
        --clean)        CLEAN_BUILD=1; shift ;;
        --install-deps) INSTALL_DEPS=1; shift ;;
        --jobs)         JOBS="$2"; shift 2 ;;
        --help)         head -28 "$0" | tail -25; exit 0 ;;
        *)              log_error "Unknown option: $1"; exit 1 ;;
    esac
done

[[ $BUILD_ALL -eq 1 ]] && { BUILD_GPU=1; BUILD_MEDIA=1; BUILD_QAT=1; BUILD_TOOLS=1; }

# Default to showing help if nothing specified
if [[ $BUILD_GPU -eq 0 && $BUILD_MEDIA -eq 0 && $BUILD_QAT -eq 0 && $BUILD_TOOLS -eq 0 && $INSTALL_DEPS -eq 0 ]]; then
    echo "Intel Stack Extended Components Builder"
    echo ""
    echo "For HARDVINO core (OpenVINO, oneDNN, oneTBB): ./build_all.sh"
    echo "For extended Intel components: $0 --all"
    echo ""
    echo "Run '$0 --help' for options"
    exit 0
fi

# ============================================================================
# INSTALL DEPENDENCIES
# ============================================================================

install_dependencies() {
    log_section "Installing System Dependencies"
    sudo apt-get update
    sudo apt-get install -y \
        build-essential git cmake ninja-build pkg-config \
        autoconf automake libtool \
        clang lld llvm \
        python3 python3-pip python3-dev \
        libssl-dev libusb-1.0-0-dev \
        libva-dev libdrm-dev libpciaccess-dev \
        libx11-dev libxext-dev libxfixes-dev \
        libnuma-dev \
        ocl-icd-opencl-dev opencl-headers \
        zlib1g-dev libzstd-dev \
        nasm yasm
    log_info "Dependencies installed"
}

# ============================================================================
# CMAKE HELPER
# ============================================================================

cmake_build() {
    local name="$1"
    local src_dir="$2"
    local install_prefix="${INSTALL_DIR}/${name}"
    shift 2
    local cmake_args=("$@")

    log_info "Building ${name}..."

    local build_dir="${BUILD_DIR}/${name}"
    mkdir -p "${build_dir}"
    cd "${build_dir}"

    cmake "${src_dir}" \
        -G "${CMAKE_GENERATOR:-Ninja}" \
        -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}" \
        -DCMAKE_INSTALL_PREFIX="${install_prefix}" \
        -DCMAKE_C_COMPILER="${CC:-clang}" \
        -DCMAKE_CXX_COMPILER="${CXX:-clang++}" \
        -DCMAKE_C_FLAGS="${CFLAGS_OPTIMAL:-}" \
        -DCMAKE_CXX_FLAGS="${CFLAGS_OPTIMAL:-}" \
        -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS_OPTIMAL:-}" \
        -DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS_OPTIMAL:-}" \
        "${cmake_args[@]}"

    cmake --build . --parallel "${JOBS}"
    cmake --install .
    log_info "${name} -> ${install_prefix}"
}

# ============================================================================
# BUILD GPU COMPUTE RUNTIME
# ============================================================================

build_gpu() {
    log_section "GPU Compute Runtime (Level Zero / OpenCL)"

    local GPU_DIR="${ROOT_DIR}/submodules/intel-stack/runtimes/gpu-compute"

    if [ -d "${GPU_DIR}/intel-graphics-compiler" ]; then
        cmake_build "igc" "${GPU_DIR}/intel-graphics-compiler" \
            -DIGC_OPTION__ARCHITECTURE_TARGET="MTL" \
            -DIGC_BUILD__VC_ENABLED=ON \
            -DCMAKE_BUILD_TYPE=Release
    else
        log_warn "intel-graphics-compiler not found, skipping"
    fi

    if [ -d "${GPU_DIR}/compute-runtime" ]; then
        cmake_build "compute-runtime" "${GPU_DIR}/compute-runtime" \
            -DNEO_ENABLE_i915_PRELIM_DETECTION=ON \
            -DNEO_SKIP_UNIT_TESTS=ON \
            -DSUPPORT_MTL=ON
    else
        log_warn "compute-runtime not found, skipping"
    fi
}

# ============================================================================
# BUILD MEDIA DRIVERS
# ============================================================================

build_media() {
    log_section "Media Drivers (VAAPI)"

    local MEDIA_DIR="${ROOT_DIR}/submodules/intel-stack/runtimes/media"

    if [ -d "${MEDIA_DIR}/media-driver" ]; then
        cmake_build "media-driver" "${MEDIA_DIR}/media-driver" \
            -DMEDIA_BUILD_FATAL_WARNINGS=OFF \
            -DBUILD_TYPE=Release \
            -DENABLE_PRODUCTION_KMD=ON
    else
        log_warn "media-driver not found, skipping"
    fi
}

# ============================================================================
# BUILD QAT LIBRARIES
# ============================================================================

build_qat() {
    log_section "QAT Libraries (Crypto/Compression)"

    local QAT_DIR="${ROOT_DIR}/submodules/intel-stack/runtimes/qat"

    # qatlib (autotools)
    if [ -d "${QAT_DIR}/qatlib" ]; then
        log_info "Building qatlib..."
        cd "${QAT_DIR}/qatlib"
        if [ -f "autogen.sh" ]; then
            ./autogen.sh 2>/dev/null || true
            ./configure --prefix="${INSTALL_DIR}/qatlib" \
                CC="${CC:-clang}" \
                CFLAGS="${CFLAGS_OPTIMAL:-}"
            make -j"${JOBS}"
            make install
            log_info "qatlib -> ${INSTALL_DIR}/qatlib"
        fi
    fi

    # QAT-ZSTD-Plugin (CMake)
    if [ -d "${QAT_DIR}/QAT-ZSTD-Plugin" ]; then
        cmake_build "QAT-ZSTD-Plugin" "${QAT_DIR}/QAT-ZSTD-Plugin" \
            -DQATLIB_ROOT="${INSTALL_DIR}/qatlib"
    fi
}

# ============================================================================
# BUILD TOOLS
# ============================================================================

build_tools() {
    log_section "Tools (oneDAL, Open3D)"

    # oneDAL
    local ONEDAL_DIR="${ROOT_DIR}/submodules/intel-stack/toolchains/oneapi-libs/oneDAL"
    if [ -d "${ONEDAL_DIR}" ] && [ -f "${ONEDAL_DIR}/CMakeLists.txt" ]; then
        cmake_build "oneDAL" "${ONEDAL_DIR}" \
            -DONEDAL_INTERFACE=YES \
            -DONEDAL_TESTS=NO
    fi

    # Open3D
    local OPEN3D_DIR="${ROOT_DIR}/submodules/intel-stack/tools/Open3D"
    if [ -d "${OPEN3D_DIR}" ]; then
        cmake_build "Open3D" "${OPEN3D_DIR}" \
            -DBUILD_EXAMPLES=OFF \
            -DBUILD_UNIT_TESTS=OFF \
            -DBUILD_PYTHON_MODULE=OFF \
            -DUSE_SYSTEM_EIGEN3=OFF \
            -DBUILD_CUDA_MODULE=OFF
    fi

    log_info "Python tools (install via pip if needed):"
    echo "  pip install neural-compressor"
    echo "  pip install optimum-intel"
}

# ============================================================================
# GENERATE ENV SCRIPT
# ============================================================================

generate_env() {
    log_section "Generating Environment Script"

    mkdir -p "${INSTALL_DIR}"
    cat > "${INSTALL_DIR}/setup.sh" << ENVEOF
#!/bin/bash
# Intel Stack Extended Components - Environment Setup
INSTALL_DIR="${INSTALL_DIR}"

# Add library paths
for dir in "\${INSTALL_DIR}"/*/lib; do
    [ -d "\$dir" ] && export LD_LIBRARY_PATH="\${dir}:\${LD_LIBRARY_PATH}"
done

# OpenCL ICD
[ -d "\${INSTALL_DIR}/compute-runtime" ] && \\
    export OCL_ICD_VENDORS="\${INSTALL_DIR}/compute-runtime/etc/OpenCL/vendors"

# VAAPI
[ -d "\${INSTALL_DIR}/media-driver" ] && {
    export LIBVA_DRIVERS_PATH="\${INSTALL_DIR}/media-driver/lib/dri"
    export LIBVA_DRIVER_NAME="iHD"
}

echo "[INFO] Intel stack extended components loaded"
ENVEOF
    chmod +x "${INSTALL_DIR}/setup.sh"
    log_info "Environment: source ${INSTALL_DIR}/setup.sh"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    log_section "HARDVINO Intel Stack Extended Builder"
    echo "Target: Intel Core Ultra 7 165H (Meteor Lake)"
    echo "Jobs:   ${JOBS}"
    echo ""

    [[ $INSTALL_DEPS -eq 1 ]] && install_dependencies
    [[ $CLEAN_BUILD -eq 1 ]] && rm -rf "${BUILD_DIR}"

    mkdir -p "${BUILD_DIR}" "${INSTALL_DIR}"

    # Initialize submodules if needed
    cd "${ROOT_DIR}"
    git submodule update --init --recursive --depth 1 2>/dev/null || true

    [[ $BUILD_GPU -eq 1 ]]   && build_gpu
    [[ $BUILD_MEDIA -eq 1 ]] && build_media
    [[ $BUILD_QAT -eq 1 ]]   && build_qat
    [[ $BUILD_TOOLS -eq 1 ]] && build_tools

    generate_env

    log_section "Build Complete"
    echo "Extended components: ${INSTALL_DIR}"
    echo "Core HARDVINO:       ${ROOT_DIR}/install"
}

main "$@"
