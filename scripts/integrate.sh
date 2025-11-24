#!/bin/bash
# ============================================================================
# HARDVINO Submodule Integration Script
# For parent projects (e.g., DSMIL)
# ============================================================================
#
# This script helps integrate HARDVINO as a submodule into larger projects.
#
# Usage from parent project:
#   git submodule add https://github.com/SWORDIntel/HARDVINO.git hardvino
#   ./hardvino/scripts/integrate.sh
#
# Or run directly:
#   ./scripts/integrate.sh --init       # Initialize all submodules
#   ./scripts/integrate.sh --build      # Build HARDVINO core
#   ./scripts/integrate.sh --cmake      # Generate CMake config for parent
#   ./scripts/integrate.sh --env        # Print environment setup
#
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARDVINO_ROOT="$(dirname "${SCRIPT_DIR}")"

# ============================================================================
# COLORS
# ============================================================================

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[HARDVINO]${NC} $1"; }
log_section() { echo -e "\n${CYAN}=== $1 ===${NC}\n"; }

# ============================================================================
# FUNCTIONS
# ============================================================================

show_help() {
    cat << 'EOF'
HARDVINO Submodule Integration

Usage: integrate.sh [command]

Commands:
  --init          Initialize HARDVINO and all submodules
  --build         Build HARDVINO core (OpenVINO, oneDNN, oneTBB)
  --build-all     Build core + extended Intel stack
  --cmake         Generate CMake configuration for parent project
  --env           Print environment variables for shell
  --check         Check HARDVINO installation status
  --help          Show this help

Integration into parent project:

  1. Add as submodule:
     git submodule add https://github.com/SWORDIntel/HARDVINO.git hardvino

  2. Initialize:
     ./hardvino/scripts/integrate.sh --init

  3. Build:
     ./hardvino/scripts/integrate.sh --build

  4. In parent CMakeLists.txt:
     include(hardvino/cmake/HARDVINOConfig.cmake)

  5. In shell:
     source hardvino/install/setupvars.sh
EOF
}

init_submodules() {
    log_section "Initializing HARDVINO Submodules"
    cd "${HARDVINO_ROOT}"

    # Core submodules (required)
    log_info "Initializing core submodules..."
    git submodule update --init --depth 1 openvino oneapi-tbb oneapi-dnn NUC2.1

    # Extended submodules (optional, shallow)
    log_info "Initializing extended Intel stack (shallow)..."
    git submodule update --init --depth 1 --recursive submodules/ 2>/dev/null || true

    log_info "Submodules initialized"
}

build_core() {
    log_section "Building HARDVINO Core"
    cd "${HARDVINO_ROOT}"

    if [ -x "./build_all.sh" ]; then
        ./build_all.sh --skip-kernel
    else
        log_info "build_all.sh not found, manual build required"
        exit 1
    fi
}

build_all() {
    build_core

    log_section "Building Extended Intel Stack"
    if [ -x "./scripts/build_intel_stack.sh" ]; then
        ./scripts/build_intel_stack.sh --all
    fi
}

generate_cmake_config() {
    log_section "Generating CMake Configuration"

    mkdir -p "${HARDVINO_ROOT}/cmake"
    cat > "${HARDVINO_ROOT}/cmake/HARDVINOConfig.cmake" << 'CMAKEOF'
# ============================================================================
# HARDVINO CMake Configuration
# Include this in parent projects: include(hardvino/cmake/HARDVINOConfig.cmake)
# ============================================================================

# Find HARDVINO root
get_filename_component(HARDVINO_CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}" DIRECTORY)
set(HARDVINO_ROOT "${HARDVINO_CMAKE_DIR}" CACHE PATH "HARDVINO root directory")
set(HARDVINO_INSTALL_DIR "${HARDVINO_ROOT}/install" CACHE PATH "HARDVINO install directory")

# ============================================================================
# Compiler flags (Meteor Lake optimized)
# ============================================================================

set(HARDVINO_C_FLAGS "-O3 -pipe -march=native -mavx2 -mavxvnni -mfma -maes -msha -mgfni" CACHE STRING "HARDVINO C flags")
set(HARDVINO_CXX_FLAGS "${HARDVINO_C_FLAGS}" CACHE STRING "HARDVINO C++ flags")

set(HARDVINO_HARDENING_FLAGS "-fstack-protector-strong -fstack-clash-protection -fcf-protection=full -D_FORTIFY_SOURCE=3" CACHE STRING "HARDVINO hardening flags")

# ============================================================================
# Find OpenVINO
# ============================================================================

if(EXISTS "${HARDVINO_INSTALL_DIR}/openvino")
    set(OpenVINO_DIR "${HARDVINO_INSTALL_DIR}/openvino/runtime/cmake" CACHE PATH "OpenVINO CMake dir")
    find_package(OpenVINO QUIET PATHS "${OpenVINO_DIR}")
    if(OpenVINO_FOUND)
        message(STATUS "HARDVINO: Found OpenVINO ${OpenVINO_VERSION}")
    endif()
endif()

# ============================================================================
# Find oneTBB
# ============================================================================

if(EXISTS "${HARDVINO_INSTALL_DIR}/oneapi-tbb")
    set(TBB_DIR "${HARDVINO_INSTALL_DIR}/oneapi-tbb/lib/cmake/TBB" CACHE PATH "TBB CMake dir")
    find_package(TBB QUIET PATHS "${TBB_DIR}")
    if(TBB_FOUND)
        message(STATUS "HARDVINO: Found oneTBB ${TBB_VERSION}")
    endif()
endif()

# ============================================================================
# Find oneDNN
# ============================================================================

if(EXISTS "${HARDVINO_INSTALL_DIR}/oneapi-dnn")
    set(dnnl_DIR "${HARDVINO_INSTALL_DIR}/oneapi-dnn/lib/cmake/dnnl" CACHE PATH "oneDNN CMake dir")
    find_package(dnnl QUIET PATHS "${dnnl_DIR}")
    if(dnnl_FOUND)
        message(STATUS "HARDVINO: Found oneDNN")
    endif()
endif()

# ============================================================================
# Convenience function
# ============================================================================

function(target_link_hardvino target)
    if(OpenVINO_FOUND)
        target_link_libraries(${target} PRIVATE openvino::runtime)
    endif()
    if(TBB_FOUND)
        target_link_libraries(${target} PRIVATE TBB::tbb)
    endif()
    if(dnnl_FOUND)
        target_link_libraries(${target} PRIVATE DNNL::dnnl)
    endif()

    target_compile_options(${target} PRIVATE ${HARDVINO_C_FLAGS} ${HARDVINO_HARDENING_FLAGS})
endfunction()

# ============================================================================
# Print summary
# ============================================================================

message(STATUS "HARDVINO: Root = ${HARDVINO_ROOT}")
message(STATUS "HARDVINO: Install = ${HARDVINO_INSTALL_DIR}")
CMAKEOF

    log_info "Generated: ${HARDVINO_ROOT}/cmake/HARDVINOConfig.cmake"
}

print_env() {
    log_section "HARDVINO Environment Setup"
    cat << EOF
# Add to your shell (bash/zsh):

export HARDVINO_ROOT="${HARDVINO_ROOT}"
export PATH="\${HARDVINO_ROOT}/install/openvino/runtime/bin:\${PATH}"
export LD_LIBRARY_PATH="\${HARDVINO_ROOT}/install/openvino/runtime/lib/intel64:\${LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH="\${HARDVINO_ROOT}/install/oneapi-tbb/lib:\${LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH="\${HARDVINO_ROOT}/install/oneapi-dnn/lib:\${LD_LIBRARY_PATH}"
export PYTHONPATH="\${HARDVINO_ROOT}/install/openvino/python:\${PYTHONPATH}"

# Or source the setup script:
source "\${HARDVINO_ROOT}/install/setupvars.sh"

# Environment script:
source "\${HARDVINO_ROOT}/scripts/intel_env.sh"
EOF
}

check_status() {
    log_section "HARDVINO Installation Status"

    echo "Root: ${HARDVINO_ROOT}"
    echo ""

    # Check core components
    echo "Core Components:"
    for comp in openvino oneapi-tbb oneapi-dnn NUC2.1; do
        if [ -d "${HARDVINO_ROOT}/${comp}" ]; then
            echo "  [OK] ${comp}"
        else
            echo "  [--] ${comp} (not initialized)"
        fi
    done

    echo ""
    echo "Installed:"
    for comp in openvino oneapi-tbb oneapi-dnn; do
        if [ -d "${HARDVINO_ROOT}/install/${comp}" ]; then
            echo "  [OK] ${comp}"
        else
            echo "  [--] ${comp} (not built)"
        fi
    done

    echo ""
    echo "Extended Intel Stack:"
    local stack_dir="${HARDVINO_ROOT}/submodules/intel-stack"
    if [ -d "${stack_dir}" ]; then
        find "${stack_dir}" -maxdepth 3 -type d -name ".git" 2>/dev/null | while read git_dir; do
            local mod_dir=$(dirname "${git_dir}")
            local mod_name=$(basename "${mod_dir}")
            echo "  [OK] ${mod_name}"
        done
    else
        echo "  [--] Not initialized (run --init)"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

case "${1:-}" in
    --init)      init_submodules ;;
    --build)     build_core ;;
    --build-all) build_all ;;
    --cmake)     generate_cmake_config ;;
    --env)       print_env ;;
    --check)     check_status ;;
    --help|-h)   show_help ;;
    *)
        if [ -z "$1" ]; then
            show_help
        else
            echo "Unknown command: $1"
            echo "Run '$0 --help' for usage"
            exit 1
        fi
        ;;
esac
