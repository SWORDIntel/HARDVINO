#!/bin/bash
# ============================================================================
# HARDVINO Build Order Configuration
# Defines compilation order and dependencies for the Intel stack
# ============================================================================
#
# HARDVINO supersedes upstream OpenVINO - this is the single entrypoint
#
# Build Order (dependencies resolved):
#   1. Toolchains (no deps)
#   2. oneAPI libs (toolchain deps)
#   3. Core HARDVINO (oneAPI deps)
#   4. GPU/NPU runtimes (core deps)
#   5. Media drivers (runtime deps)
#   6. QAT libraries (standalone)
#   7. ML frameworks (core + runtime deps)
#   8. Tools (framework deps)
#   9. PLATFORM (everything)
#
# ============================================================================

# Build stages in dependency order
declare -a BUILD_STAGES=(
    "stage1_toolchains"
    "stage2_oneapi"
    "stage3_core"
    "stage4_runtimes"
    "stage5_media"
    "stage6_qat"
    "stage7_frameworks"
    "stage8_tools"
    "stage9_platform"
)

# ============================================================================
# STAGE 1: Toolchains (no dependencies)
# ============================================================================
stage1_toolchains() {
    log_stage "Stage 1: Toolchains"

    # XeTLA - Xe Template Library (header-only, just install)
    build_component "xetla" \
        "submodules/intel-stack/toolchains/xetla" \
        "header-only"
}

# ============================================================================
# STAGE 2: oneAPI Libraries
# ============================================================================
stage2_oneapi() {
    log_stage "Stage 2: oneAPI Libraries"

    # oneTBB - Threading (already in HARDVINO core)
    build_component "oneTBB" "oneapi-tbb" "cmake" \
        -DTBB_TEST=OFF \
        -DTBB_EXAMPLES=OFF

    # oneDNN - Deep Neural Network (already in HARDVINO core)
    build_component "oneDNN" "oneapi-dnn" "cmake" \
        -DDNNL_BUILD_TESTS=OFF \
        -DDNNL_BUILD_EXAMPLES=OFF \
        -DDNNL_CPU_RUNTIME=TBB

    # oneMKL - Math Kernel Library
    build_component "oneMKL" \
        "submodules/intel-stack/toolchains/oneapi-libs/oneMKL" \
        "cmake" \
        -DBUILD_FUNCTIONAL_TESTS=OFF

    # oneDAL - Data Analytics Library
    build_component "oneDAL" \
        "submodules/intel-stack/toolchains/oneapi-libs/oneDAL" \
        "cmake" \
        -DONEDAL_INTERFACE=YES

    # oneCCL - Collective Communications
    build_component "oneCCL" \
        "submodules/intel-stack/toolchains/oneapi-libs/oneCCL" \
        "cmake" \
        -DBUILD_EXAMPLES=OFF

    # oneDPL - Parallel STL (header-only)
    build_component "oneDPL" \
        "submodules/intel-stack/toolchains/oneapi-libs/oneDPL" \
        "cmake" \
        -DONEDPL_BACKEND=tbb
}

# ============================================================================
# STAGE 3: Core HARDVINO (OpenVINO replacement)
# ============================================================================
stage3_core() {
    log_stage "Stage 3: Core HARDVINO (supersedes OpenVINO)"

    # HARDVINO builds OpenVINO with hardening - use existing build_all.sh
    if [ -x "${HARDVINO_ROOT}/build_all.sh" ]; then
        log_info "Building HARDVINO core via build_all.sh..."
        cd "${HARDVINO_ROOT}"
        ./build_all.sh --skip-kernel
    else
        log_error "build_all.sh not found - cannot build core"
        return 1
    fi

    # NUC2.1 - Movidius VPU
    if [ -d "${HARDVINO_ROOT}/NUC2.1" ]; then
        log_info "Building NUC2.1 (Movidius VPU)..."
        cd "${HARDVINO_ROOT}/NUC2.1"
        if [ -f "Cargo.toml" ]; then
            cargo build --release
        fi
    fi
}

# ============================================================================
# STAGE 4: GPU/NPU Runtimes
# ============================================================================
stage4_runtimes() {
    log_stage "Stage 4: GPU/NPU Runtimes"

    # Level Zero - Low-level GPU API
    build_component "level-zero" \
        "submodules/intel-stack/runtimes/gpu-compute/level-zero" \
        "cmake"

    # Intel Graphics Compiler
    build_component "igc" \
        "submodules/intel-stack/runtimes/gpu-compute/intel-graphics-compiler" \
        "cmake" \
        -DIGC_OPTION__ARCHITECTURE_TARGET="MTL" \
        -DCMAKE_BUILD_TYPE=Release

    # Compute Runtime (OpenCL/Level Zero)
    build_component "compute-runtime" \
        "submodules/intel-stack/runtimes/gpu-compute/compute-runtime" \
        "cmake" \
        -DNEO_SKIP_UNIT_TESTS=ON \
        -DSUPPORT_MTL=ON

    # NPU Acceleration Library
    build_component "npu-accel" \
        "submodules/intel-stack/runtimes/npu/intel-npu-acceleration-library" \
        "pip"

    # Linux NPU Driver tools
    build_component "npu-driver" \
        "submodules/intel-stack/runtimes/npu/linux-npu-driver" \
        "cmake"
}

# ============================================================================
# STAGE 5: Media Drivers
# ============================================================================
stage5_media() {
    log_stage "Stage 5: Media Drivers"

    # Intel Media Driver (modern VAAPI)
    build_component "media-driver" \
        "submodules/intel-stack/runtimes/media/media-driver" \
        "cmake" \
        -DMEDIA_BUILD_FATAL_WARNINGS=OFF \
        -DENABLE_PRODUCTION_KMD=ON

    # Legacy VAAPI (optional, for older hardware)
    build_component "vaapi-driver" \
        "submodules/intel-stack/runtimes/media/intel-vaapi-driver" \
        "autotools"
}

# ============================================================================
# STAGE 6: QAT Libraries
# ============================================================================
stage6_qat() {
    log_stage "Stage 6: QAT Crypto/Compression"

    # QAT Library
    build_component "qatlib" \
        "submodules/intel-stack/runtimes/qat/qatlib" \
        "autotools"

    # QAT OpenSSL Engine
    build_component "qat-engine" \
        "submodules/intel-stack/runtimes/qat/QAT_Engine" \
        "autotools"

    # QAT ZSTD Plugin
    build_component "qat-zstd" \
        "submodules/intel-stack/runtimes/qat/QAT-ZSTD-Plugin" \
        "cmake"
}

# ============================================================================
# STAGE 7: ML Frameworks
# ============================================================================
stage7_frameworks() {
    log_stage "Stage 7: ML Framework Extensions"

    # Intel Extension for PyTorch
    build_component "ipex" \
        "submodules/intel-stack/tools/intel-extension-for-pytorch" \
        "pip"

    # Intel Extension for TensorFlow
    build_component "itex" \
        "submodules/intel-stack/tools/intel-extension-for-tensorflow" \
        "pip"

    # Torch XPU Ops
    build_component "torch-xpu-ops" \
        "submodules/intel-stack/tools/torch-xpu-ops" \
        "pip"

    # Neural Speed (LLM inference)
    build_component "neural-speed" \
        "submodules/intel-stack/tools/neural-speed" \
        "pip"

    # Neural Compressor
    build_component "neural-compressor" \
        "submodules/intel-stack/tools/neural-compressor" \
        "pip"

    # Optimum Intel (HuggingFace)
    build_component "optimum-intel" \
        "submodules/intel-stack/tools/optimum-intel" \
        "pip"

    # OpenVINO Contrib
    build_component "openvino-contrib" \
        "submodules/intel-stack/runtimes/openvino/openvino_contrib" \
        "cmake"
}

# ============================================================================
# STAGE 8: Tools
# ============================================================================
stage8_tools() {
    log_stage "Stage 8: Tools & Utilities"

    # OpenVINO Rust bindings
    build_component "openvino-rs" \
        "submodules/intel-stack/tools/openvino-rs" \
        "cargo"

    # Open3D (3D perception)
    build_component "open3d" \
        "submodules/intel-stack/tools/Open3D" \
        "cmake" \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_UNIT_TESTS=OFF \
        -DBUILD_PYTHON_MODULE=ON

    # XeSS (super sampling)
    build_component "xess" \
        "submodules/intel-stack/tools/xess" \
        "cmake"

    # ROS2 OpenVINO Toolkit (if ROS2 available)
    if command -v ros2 &>/dev/null; then
        build_component "ros2-openvino" \
            "submodules/intel-stack/tools/ros2_openvino_toolkit" \
            "colcon"
    fi

    # PerfSpect (Python tool)
    build_component "perfspect" \
        "submodules/intel-stack/tools/PerfSpect" \
        "pip"
}

# ============================================================================
# STAGE 9: PLATFORM
# ============================================================================
stage9_platform() {
    log_stage "Stage 9: SWORDIntel PLATFORM"

    if [ -d "${HARDVINO_ROOT}/submodules/PLATFORM" ]; then
        build_component "platform" \
            "submodules/PLATFORM" \
            "auto"
    else
        log_warn "PLATFORM not found, skipping"
    fi
}

# ============================================================================
# BUILD HELPERS
# ============================================================================

log_stage() {
    echo -e "\n${CYAN}${BOLD}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║ $1${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════╝${NC}\n"
}

build_component() {
    local name="$1"
    local path="$2"
    local type="$3"
    shift 3
    local extra_args=("$@")

    local full_path="${HARDVINO_ROOT}/${path}"

    if [ ! -d "${full_path}" ]; then
        log_warn "${name}: not found at ${path}, skipping"
        return 0
    fi

    log_info "Building ${name} (${type})..."

    case "${type}" in
        cmake)
            build_cmake "${name}" "${full_path}" "${extra_args[@]}"
            ;;
        autotools)
            build_autotools "${name}" "${full_path}"
            ;;
        pip)
            build_pip "${name}" "${full_path}"
            ;;
        cargo)
            build_cargo "${name}" "${full_path}"
            ;;
        colcon)
            build_colcon "${name}" "${full_path}"
            ;;
        header-only)
            install_headers "${name}" "${full_path}"
            ;;
        auto)
            build_auto "${name}" "${full_path}"
            ;;
        *)
            log_warn "${name}: unknown build type ${type}"
            ;;
    esac
}

build_cmake() {
    local name="$1"
    local src="$2"
    shift 2
    local args=("$@")

    local build_dir="${BUILD_DIR}/${name}"
    local install_dir="${INSTALL_DIR}/${name}"

    mkdir -p "${build_dir}"
    cd "${build_dir}"

    cmake "${src}" \
        -G "${CMAKE_GENERATOR:-Ninja}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${install_dir}" \
        -DCMAKE_C_COMPILER="${CC:-clang}" \
        -DCMAKE_CXX_COMPILER="${CXX:-clang++}" \
        -DCMAKE_C_FLAGS="${CFLAGS_OPTIMAL:-}" \
        -DCMAKE_CXX_FLAGS="${CFLAGS_OPTIMAL:-}" \
        "${args[@]}" || return 1

    cmake --build . --parallel "${JOBS}" || return 1
    cmake --install . || return 1

    log_info "${name} -> ${install_dir}"
}

build_autotools() {
    local name="$1"
    local src="$2"
    local install_dir="${INSTALL_DIR}/${name}"

    cd "${src}"

    [ -f "autogen.sh" ] && ./autogen.sh
    [ -f "configure" ] || autoreconf -fi

    ./configure \
        --prefix="${install_dir}" \
        CC="${CC:-clang}" \
        CXX="${CXX:-clang++}" \
        CFLAGS="${CFLAGS_OPTIMAL:-}" \
        CXXFLAGS="${CFLAGS_OPTIMAL:-}" || return 1

    make -j"${JOBS}" || return 1
    make install || return 1

    log_info "${name} -> ${install_dir}"
}

build_pip() {
    local name="$1"
    local src="$2"

    cd "${src}"
    pip3 install --user -e . || pip3 install --user . || return 1

    log_info "${name} -> pip (user)"
}

build_cargo() {
    local name="$1"
    local src="$2"

    cd "${src}"
    cargo build --release || return 1

    log_info "${name} -> ${src}/target/release"
}

build_colcon() {
    local name="$1"
    local src="$2"

    cd "${src}"
    colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release || return 1

    log_info "${name} -> ${src}/install"
}

build_auto() {
    local name="$1"
    local src="$2"

    cd "${src}"

    if [ -f "CMakeLists.txt" ]; then
        build_cmake "${name}" "${src}"
    elif [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
        build_pip "${name}" "${src}"
    elif [ -f "Cargo.toml" ]; then
        build_cargo "${name}" "${src}"
    elif [ -f "configure" ] || [ -f "autogen.sh" ]; then
        build_autotools "${name}" "${src}"
    elif [ -x "install.sh" ]; then
        ./install.sh
    else
        log_warn "${name}: no build system detected"
    fi
}

install_headers() {
    local name="$1"
    local src="$2"
    local install_dir="${INSTALL_DIR}/${name}/include"

    mkdir -p "${install_dir}"
    cp -r "${src}/include/"* "${install_dir}/" 2>/dev/null || \
    cp -r "${src}/"*.h "${install_dir}/" 2>/dev/null || \
    cp -r "${src}/"*.hpp "${install_dir}/" 2>/dev/null

    log_info "${name} -> ${install_dir}"
}

# ============================================================================
# RUN ALL STAGES
# ============================================================================

run_all_stages() {
    local start_stage="${1:-1}"

    for stage in "${BUILD_STAGES[@]}"; do
        local stage_num="${stage#stage}"
        stage_num="${stage_num%%_*}"

        if [ "${stage_num}" -ge "${start_stage}" ]; then
            ${stage} || {
                log_error "Stage ${stage} failed"
                return 1
            }
        fi
    done
}

# Export for use by install.sh
export -f run_all_stages
export -f build_component
export -f build_cmake
export -f build_autotools
export -f build_pip
export -f build_cargo
export -f log_stage
