#!/bin/bash
# ============================================================================
# HARDVINO - Hardened OpenVINO Build Script
# Builds OpenVINO with military-grade hardening + NPU VPU 3720 support
# Based on ImageHarden security principles
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
INSTALL_PREFIX="${SCRIPT_DIR}/install"
OPENVINO_DIR="${SCRIPT_DIR}/openvino"

# Source NPU military configuration
source "${SCRIPT_DIR}/npu_military_config.sh"

# ============================================================================
# COLOR OUTPUT
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# DEPENDENCY CHECK
# ============================================================================

check_dependencies() {
    log_info "Checking dependencies..."

    local deps=(
        "git"
        "cmake"
        "gcc"
        "g++"
        "python3"
        "python3-pip"
        "ninja-build"
        "pkg-config"
    )

    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Install with: sudo apt-get install ${missing[*]}"
        exit 1
    fi

    log_info "All dependencies satisfied"
}

# ============================================================================
# SUBMODULE INITIALIZATION
# ============================================================================

init_submodules() {
    log_info "Initializing OpenVINO submodule..."

    cd "${SCRIPT_DIR}"

    if [ ! -f "${OPENVINO_DIR}/.git" ]; then
        log_error "OpenVINO submodule not found. Run: git submodule update --init --recursive"
        exit 1
    fi

    cd "${OPENVINO_DIR}"
    git submodule update --init --recursive --depth 1

    log_info "Submodules initialized"
}

# ============================================================================
# HARDENED CMAKE CONFIGURATION
# ============================================================================

configure_openvino() {
    log_info "Configuring OpenVINO with hardened flags..."

    mkdir -p "${BUILD_DIR}/openvino"
    cd "${BUILD_DIR}/openvino"

    # Combine all hardening flags
    local CMAKE_C_FLAGS="${CFLAGS_NPU_HARDENED}"
    local CMAKE_CXX_FLAGS="${CFLAGS_NPU_HARDENED} -std=c++17"
    local CMAKE_EXE_LINKER_FLAGS="${LDFLAGS_NPU_HARDENED}"

    # AVX2-FIRST ARCHITECTURE FOR METEOR LAKE
    # Intel Core Ultra 7 165H (Meteor Lake) supports:
    #   ✓ SSE4.2, AVX, AVX2, AVX-VNNI (AI acceleration)
    #   ✗ NO AVX-512 support (not available on this platform)
    # Design Decision: AVX2-First Workflow
    # - AVX-VNNI provides AI/ML acceleration on AVX2 width (256-bit)
    # - Better power efficiency and thermal characteristics
    # - Optimal performance for Meteor Lake hybrid architecture
    # - See AVX2_FIRST_WORKFLOW.md for detailed rationale
    cmake "${OPENVINO_DIR}" \
        -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}/openvino" \
        -DCMAKE_C_COMPILER=gcc \
        -DCMAKE_CXX_COMPILER=g++ \
        -DCMAKE_C_FLAGS="${CMAKE_C_FLAGS}" \
        -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS}" \
        -DCMAKE_EXE_LINKER_FLAGS="${CMAKE_EXE_LINKER_FLAGS}" \
        -DCMAKE_SHARED_LINKER_FLAGS="${CMAKE_EXE_LINKER_FLAGS}" \
        -DENABLE_INTEL_CPU=ON \
        -DENABLE_INTEL_GPU=ON \
        -DENABLE_INTEL_NPU=ON \
        -DENABLE_AUTO=ON \
        -DENABLE_AUTO_BATCH=ON \
        -DENABLE_HETERO=ON \
        -DENABLE_MULTI=ON \
        -DENABLE_OV_ONNX_FRONTEND=ON \
        -DENABLE_OV_PADDLE_FRONTEND=ON \
        -DENABLE_OV_PYTORCH_FRONTEND=ON \
        -DENABLE_OV_TF_FRONTEND=ON \
        -DENABLE_OV_TF_LITE_FRONTEND=ON \
        -DENABLE_PYTHON=ON \
        -DPYTHON_EXECUTABLE=$(which python3) \
        -DENABLE_TESTS=OFF \
        -DENABLE_FUNCTIONAL_TESTS=OFF \
        -DENABLE_SAMPLES=ON \
        -DENABLE_GAPI_PREPROCESSING=ON \
        -DENABLE_STRICT_DEPENDENCIES=OFF \
        -DENABLE_FASTER_BUILD=ON \
        -DENABLE_LTO=ON \
        -DENABLE_PROFILING_ITT=OFF \
        -DENABLE_PROFILING_FILTER=OFF \
        -DENABLE_PROFILING_RAW=OFF \
        -DTHREADING=TBB \
        -DENABLE_TBBBIND_2_5=ON \
        -DTBB_DIR="${INSTALL_PREFIX}/oneapi-tbb/lib/cmake/tbb" \
        -DENABLE_SSE42=ON \
        -DENABLE_AVX2=ON \
        -DENABLE_AVX512F=OFF \
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DCMAKE_CXX_VISIBILITY_PRESET=hidden \
        -DCMAKE_VISIBILITY_INLINES_HIDDEN=ON \
        -DCMAKE_SKIP_RPATH=OFF \
        -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON \
        -DCMAKE_BUILD_RPATH="${INSTALL_PREFIX}/openvino/lib:${INSTALL_PREFIX}/oneapi-tbb/lib:${INSTALL_PREFIX}/oneapi-dnn/lib" \
        -DCMAKE_INSTALL_RPATH="${INSTALL_PREFIX}/openvino/lib:${INSTALL_PREFIX}/oneapi-tbb/lib:${INSTALL_PREFIX}/oneapi-dnn/lib"

    log_info "OpenVINO configured successfully"
}

# ============================================================================
# BUILD
# ============================================================================

build_openvino() {
    log_info "Building OpenVINO..."

    cd "${BUILD_DIR}/openvino"

    # Use all available cores for building
    local num_cores=$(nproc)
    log_info "Building with ${num_cores} cores..."

    ninja -j${num_cores}

    log_info "OpenVINO built successfully"
}

# ============================================================================
# INSTALL
# ============================================================================

install_openvino() {
    log_info "Installing OpenVINO..."

    cd "${BUILD_DIR}/openvino"
    ninja install

    log_info "OpenVINO installed to ${INSTALL_PREFIX}/openvino"
}

# ============================================================================
# POST-INSTALL VERIFICATION
# ============================================================================

verify_installation() {
    log_info "Verifying installation..."

    # Check if critical files exist
    local critical_files=(
        "${INSTALL_PREFIX}/openvino/lib/libopenvino.so"
        "${INSTALL_PREFIX}/openvino/lib/libopenvino_c.so"
        "${INSTALL_PREFIX}/openvino/runtime/lib/intel64/libopenvino_intel_cpu_plugin.so"
    )

    for file in "${critical_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_warn "Missing expected file: $file"
        fi
    done

    # Check hardening flags in binaries
    log_info "Verifying security hardening..."

    if command -v checksec &> /dev/null; then
        checksec --file="${INSTALL_PREFIX}/openvino/lib/libopenvino.so" || true
    else
        log_warn "checksec not installed, skipping binary hardening verification"
        log_info "Install with: sudo apt-get install checksec"
    fi

    # Verify NPU plugin if available
    if [ -f "${INSTALL_PREFIX}/openvino/runtime/lib/intel64/libopenvino_intel_npu_plugin.so" ]; then
        log_info "✓ NPU plugin built successfully"
    else
        log_warn "NPU plugin not found - may need additional dependencies"
    fi

    log_info "Verification complete"
}

# ============================================================================
# SETUP ENVIRONMENT SCRIPT
# ============================================================================

create_env_script() {
    log_info "Creating environment setup script..."

    local env_script="${INSTALL_PREFIX}/setupvars.sh"

    cat > "${env_script}" << 'EOF'
#!/bin/bash
# HARDVINO Environment Setup Script

HARDVINO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# OpenVINO paths
export OPENVINO_INSTALL_DIR="${HARDVINO_DIR}/openvino"
export LD_LIBRARY_PATH="${OPENVINO_INSTALL_DIR}/runtime/lib/intel64:${LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH="${OPENVINO_INSTALL_DIR}/lib:${LD_LIBRARY_PATH}"
export PYTHONPATH="${OPENVINO_INSTALL_DIR}/python:${PYTHONPATH}"

# OneAPI TBB
export TBB_DIR="${HARDVINO_DIR}/oneapi-tbb"
export LD_LIBRARY_PATH="${TBB_DIR}/lib:${LD_LIBRARY_PATH}"

# OneAPI DNN
export DNNL_DIR="${HARDVINO_DIR}/oneapi-dnn"
export LD_LIBRARY_PATH="${DNNL_DIR}/lib:${LD_LIBRARY_PATH}"

# NPU configuration (source the full config if available)
if [ -f "${HARDVINO_DIR}/../npu_military_config.sh" ]; then
    source "${HARDVINO_DIR}/../npu_military_config.sh"
fi

echo "HARDVINO environment configured"
echo "OpenVINO: ${OPENVINO_INSTALL_DIR}"
echo ""
echo "To test NPU: test_npu_military"
EOF

    chmod +x "${env_script}"

    log_info "Environment script created: ${env_script}"
    log_info "To use: source ${env_script}"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║  HARDVINO - Hardened OpenVINO Build System                              ║"
    echo "║  NPU VPU 3720 Support + Military-Grade Hardening                        ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo ""

    check_dependencies
    init_submodules
    configure_openvino
    build_openvino
    install_openvino
    verify_installation
    create_env_script

    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║  BUILD COMPLETE                                                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Installation directory: ${INSTALL_PREFIX}/openvino"
    echo ""
    echo "To use OpenVINO, run:"
    echo "  source ${INSTALL_PREFIX}/setupvars.sh"
    echo ""
    echo "To initialize NPU:"
    echo "  init_npu_tactical"
    echo ""
    echo "To test NPU:"
    echo "  test_npu_military"
    echo ""
}

# Allow sourcing this script for functions
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
