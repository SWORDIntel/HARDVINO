#!/bin/bash
# ============================================================================
# HARDVINO Environment Setup
# Initializes OpenVINO and other necessary environment variables
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${SCRIPT_DIR}/install"

# ============================================================================
# COLOR OUTPUT
# ============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# ============================================================================
# ENVIRONMENT SETUP
# ============================================================================

# Check if OpenVINO is built
if [ ! -f "${INSTALL_DIR}/setupvars.sh" ]; then
    log_error "OpenVINO not found. Build HARDVINO first:"
    echo "  ./build_all.sh"
    return 1 2>/dev/null || exit 1
fi

# Source OpenVINO environment
log_info "Loading OpenVINO environment from ${INSTALL_DIR}/setupvars.sh"
source "${INSTALL_DIR}/setupvars.sh"

# Add HARDVINO installation paths to environment
export HARDVINO_ROOT="${SCRIPT_DIR}"
export HARDVINO_INSTALL="${INSTALL_DIR}"

# Set up library paths
export LD_LIBRARY_PATH="${INSTALL_DIR}/openvino/runtime/lib/intel64:${INSTALL_DIR}/oneapi-tbb/lib:${INSTALL_DIR}/oneapi-dnn/lib:${LD_LIBRARY_PATH}"

# Set up Python paths if Python is available
if command -v python3 &> /dev/null; then
    export PYTHONPATH="${INSTALL_DIR}/openvino/python:${PYTHONPATH}"
fi

log_info "HARDVINO environment initialized:"
echo "  HARDVINO_ROOT:        ${HARDVINO_ROOT}"
echo "  HARDVINO_INSTALL:     ${HARDVINO_INSTALL}"
echo "  OpenVINO Runtime:     ${INSTALL_DIR}/openvino"
echo "  oneTBB:               ${INSTALL_DIR}/oneapi-tbb"
echo "  oneDNN:               ${INSTALL_DIR}/oneapi-dnn"
echo ""

# Show available devices if OpenVINO is loaded
if [ -d "${INSTALL_DIR}/openvino" ]; then
    log_info "OpenVINO ready. Check available devices with:"
    echo "  python3 -c \"from openvino.runtime import Core; print('Devices:', Core().available_devices)\""
fi
