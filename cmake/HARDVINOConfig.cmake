# ============================================================================
# HARDVINO CMake Configuration
# Intel Acceleration Stack for DSMIL Platform
# ============================================================================
#
# Include this in parent projects:
#   include(hardvino/cmake/HARDVINOConfig.cmake)
#
# Then use:
#   target_link_hardvino(your_target)
#
# ============================================================================

cmake_minimum_required(VERSION 3.16)

# Find HARDVINO root (parent of cmake/ directory)
get_filename_component(HARDVINO_CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}" ABSOLUTE)
get_filename_component(HARDVINO_ROOT "${HARDVINO_CMAKE_DIR}" DIRECTORY)

set(HARDVINO_ROOT "${HARDVINO_ROOT}" CACHE PATH "HARDVINO root directory")
set(HARDVINO_INSTALL_DIR "${HARDVINO_ROOT}/install" CACHE PATH "HARDVINO install directory")

message(STATUS "HARDVINO: Root = ${HARDVINO_ROOT}")

# ============================================================================
# Meteor Lake Optimized Compiler Flags
# Intel Core Ultra 7 165H (6P+10E cores)
# ============================================================================

# Check if compiler supports meteorlake
include(CheckCCompilerFlag)
check_c_compiler_flag("-march=meteorlake" COMPILER_SUPPORTS_METEORLAKE)

if(COMPILER_SUPPORTS_METEORLAKE)
    set(HARDVINO_ARCH "meteorlake")
else()
    set(HARDVINO_ARCH "alderlake")
    message(STATUS "HARDVINO: Compiler doesn't support meteorlake, using alderlake")
endif()

# ISA extensions for Meteor Lake
set(HARDVINO_ISA_FLAGS
    "-msse4.2 -mpopcnt -mavx -mavx2 -mfma -mf16c -mbmi -mbmi2 -mlzcnt -mmovbe"
    CACHE STRING "Meteor Lake ISA flags")

set(HARDVINO_VNNI_FLAGS "-mavxvnni" CACHE STRING "AVX-VNNI flags")

set(HARDVINO_CRYPTO_FLAGS
    "-maes -mvaes -mpclmul -mvpclmulqdq -msha -mgfni"
    CACHE STRING "Crypto acceleration flags")

# Optimal C flags (without hardening)
set(HARDVINO_C_FLAGS
    "-O3 -pipe -fomit-frame-pointer -funroll-loops -fstrict-aliasing -fno-plt -fdata-sections -ffunction-sections -flto=auto -march=${HARDVINO_ARCH} -mtune=${HARDVINO_ARCH} ${HARDVINO_ISA_FLAGS} ${HARDVINO_VNNI_FLAGS} ${HARDVINO_CRYPTO_FLAGS}"
    CACHE STRING "HARDVINO optimized C flags")

set(HARDVINO_CXX_FLAGS "${HARDVINO_C_FLAGS}" CACHE STRING "HARDVINO optimized C++ flags")

# Linker flags
set(HARDVINO_LINK_FLAGS
    "-Wl,--as-needed -Wl,--gc-sections -Wl,-O1 -Wl,--hash-style=gnu -flto=auto"
    CACHE STRING "HARDVINO linker flags")

# Security hardening flags (ImageHarden-inspired)
set(HARDVINO_HARDENING_FLAGS
    "-fstack-protector-strong -fstack-clash-protection -fcf-protection=full -D_FORTIFY_SOURCE=3 -fPIC"
    CACHE STRING "HARDVINO security hardening flags")

# Full RELRO linking
set(HARDVINO_HARDENING_LINK_FLAGS
    "-Wl,-z,relro -Wl,-z,now"
    CACHE STRING "HARDVINO hardening linker flags")

# Combined flags (optimal + hardening)
set(HARDVINO_FULL_C_FLAGS "${HARDVINO_C_FLAGS} ${HARDVINO_HARDENING_FLAGS}"
    CACHE STRING "HARDVINO full C flags (optimal + hardening)")

set(HARDVINO_FULL_LINK_FLAGS "${HARDVINO_LINK_FLAGS} ${HARDVINO_HARDENING_LINK_FLAGS}"
    CACHE STRING "HARDVINO full linker flags")

# ============================================================================
# Find OpenVINO
# ============================================================================

set(HARDVINO_OPENVINO_FOUND FALSE)

if(EXISTS "${HARDVINO_INSTALL_DIR}/openvino/runtime/cmake")
    set(OpenVINO_DIR "${HARDVINO_INSTALL_DIR}/openvino/runtime/cmake" CACHE PATH "OpenVINO CMake dir")
    find_package(OpenVINO QUIET PATHS "${OpenVINO_DIR}" NO_DEFAULT_PATH)
    if(OpenVINO_FOUND)
        set(HARDVINO_OPENVINO_FOUND TRUE)
        message(STATUS "HARDVINO: Found OpenVINO ${OpenVINO_VERSION}")
    endif()
endif()

# ============================================================================
# Find oneTBB
# ============================================================================

set(HARDVINO_TBB_FOUND FALSE)

if(EXISTS "${HARDVINO_INSTALL_DIR}/oneapi-tbb/lib/cmake/TBB")
    set(TBB_DIR "${HARDVINO_INSTALL_DIR}/oneapi-tbb/lib/cmake/TBB" CACHE PATH "TBB CMake dir")
    find_package(TBB QUIET PATHS "${TBB_DIR}" NO_DEFAULT_PATH)
    if(TBB_FOUND)
        set(HARDVINO_TBB_FOUND TRUE)
        message(STATUS "HARDVINO: Found oneTBB ${TBB_VERSION}")
    endif()
endif()

# ============================================================================
# Find oneDNN
# ============================================================================

set(HARDVINO_DNNL_FOUND FALSE)

if(EXISTS "${HARDVINO_INSTALL_DIR}/oneapi-dnn/lib/cmake/dnnl")
    set(dnnl_DIR "${HARDVINO_INSTALL_DIR}/oneapi-dnn/lib/cmake/dnnl" CACHE PATH "oneDNN CMake dir")
    find_package(dnnl QUIET PATHS "${dnnl_DIR}" NO_DEFAULT_PATH)
    if(dnnl_FOUND)
        set(HARDVINO_DNNL_FOUND TRUE)
        message(STATUS "HARDVINO: Found oneDNN")
    endif()
endif()

# ============================================================================
# Convenience Functions
# ============================================================================

# Link all HARDVINO libraries to a target
function(target_link_hardvino target)
    # Link libraries
    if(HARDVINO_OPENVINO_FOUND)
        target_link_libraries(${target} PRIVATE openvino::runtime)
    endif()

    if(HARDVINO_TBB_FOUND)
        target_link_libraries(${target} PRIVATE TBB::tbb)
    endif()

    if(HARDVINO_DNNL_FOUND)
        target_link_libraries(${target} PRIVATE DNNL::dnnl)
    endif()

    # Apply Meteor Lake optimization + hardening flags
    target_compile_options(${target} PRIVATE
        $<$<COMPILE_LANGUAGE:C>:${HARDVINO_FULL_C_FLAGS}>
        $<$<COMPILE_LANGUAGE:CXX>:${HARDVINO_FULL_C_FLAGS}>
    )

    target_link_options(${target} PRIVATE ${HARDVINO_FULL_LINK_FLAGS})
endfunction()

# Link only optimization flags (no hardening)
function(target_link_hardvino_fast target)
    if(HARDVINO_OPENVINO_FOUND)
        target_link_libraries(${target} PRIVATE openvino::runtime)
    endif()

    if(HARDVINO_TBB_FOUND)
        target_link_libraries(${target} PRIVATE TBB::tbb)
    endif()

    if(HARDVINO_DNNL_FOUND)
        target_link_libraries(${target} PRIVATE DNNL::dnnl)
    endif()

    target_compile_options(${target} PRIVATE
        $<$<COMPILE_LANGUAGE:C>:${HARDVINO_C_FLAGS}>
        $<$<COMPILE_LANGUAGE:CXX>:${HARDVINO_CXX_FLAGS}>
    )

    target_link_options(${target} PRIVATE ${HARDVINO_LINK_FLAGS})
endfunction()

# Apply only compilation flags (no linking)
function(target_hardvino_flags target)
    target_compile_options(${target} PRIVATE
        $<$<COMPILE_LANGUAGE:C>:${HARDVINO_FULL_C_FLAGS}>
        $<$<COMPILE_LANGUAGE:CXX>:${HARDVINO_FULL_C_FLAGS}>
    )
    target_link_options(${target} PRIVATE ${HARDVINO_FULL_LINK_FLAGS})
endfunction()

# ============================================================================
# Summary
# ============================================================================

message(STATUS "HARDVINO: Install = ${HARDVINO_INSTALL_DIR}")
message(STATUS "HARDVINO: Arch = ${HARDVINO_ARCH}")
message(STATUS "HARDVINO: OpenVINO = ${HARDVINO_OPENVINO_FOUND}")
message(STATUS "HARDVINO: TBB = ${HARDVINO_TBB_FOUND}")
message(STATUS "HARDVINO: oneDNN = ${HARDVINO_DNNL_FOUND}")
