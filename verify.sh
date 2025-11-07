#!/bin/bash
# ============================================================================
# HARDVINO - Verification Script
# Verifies the repository setup and readiness for building
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

ERRORS=0
WARNINGS=0

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  HARDVINO - Repository Verification                                     ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# 1. Check scripts exist and are executable
# ============================================================================

info "Checking build scripts..."

SCRIPTS=(
    "build_all.sh"
    "build_hardened_openvino.sh"
    "build_hardened_oneapi.sh"
    "kernel_integration.sh"
    "npu_military_config.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        pass "$script exists and is executable"
    else
        fail "$script missing or not executable"
        ((ERRORS++))
    fi
done

echo ""

# ============================================================================
# 2. Check script syntax
# ============================================================================

info "Checking script syntax..."

for script in "${SCRIPTS[@]}"; do
    if bash -n "$script" 2>/dev/null; then
        pass "$script has valid syntax"
    else
        fail "$script has syntax errors"
        ((ERRORS++))
    fi
done

echo ""

# ============================================================================
# 3. Check submodules
# ============================================================================

info "Checking git submodules..."

SUBMODULES=("openvino" "oneapi-tbb" "oneapi-dnn")

for submodule in "${SUBMODULES[@]}"; do
    if [ -d "$submodule/.git" ] || [ -f "$submodule/.git" ]; then
        pass "$submodule submodule initialized"
    else
        fail "$submodule submodule not initialized"
        ((ERRORS++))
    fi
done

echo ""

# ============================================================================
# 4. Check OpenVINO sub-submodules
# ============================================================================

info "Checking OpenVINO sub-submodules..."

cd openvino
UNINIT=$(git submodule status | grep -c "^-" || echo "0")
TOTAL=$(git submodule status | wc -l)

if [ "$UNINIT" -eq 0 ]; then
    pass "All OpenVINO sub-submodules initialized (0/$TOTAL uninitialized)"
else
    warn "OpenVINO has $UNINIT/$TOTAL uninitialized sub-submodules"
    info "Run: git submodule update --init --recursive --depth 1"
    ((WARNINGS++))
fi

cd "${SCRIPT_DIR}"
echo ""

# ============================================================================
# 5. Check configuration files
# ============================================================================

info "Checking configuration files..."

if [ -f "meteor_lake_flags_ultimate/METEOR_LAKE_COMPLETE_FLAGS.sh" ]; then
    pass "Meteor Lake flags file exists"
    if source "./meteor_lake_flags_ultimate/METEOR_LAKE_COMPLETE_FLAGS.sh" >/dev/null 2>&1; then
        pass "Meteor Lake flags can be sourced"
    else
        fail "Meteor Lake flags has errors when sourced"
        ((ERRORS++))
    fi
else
    fail "Meteor Lake flags file missing"
    ((ERRORS++))
fi

if source "./npu_military_config.sh" >/dev/null 2>&1; then
    pass "NPU military config can be sourced"
else
    fail "NPU military config has errors when sourced"
    ((ERRORS++))
fi

echo ""

# ============================================================================
# 6. Check build dependencies
# ============================================================================

info "Checking build dependencies..."

DEPS=(
    "git:git"
    "cmake:cmake"
    "ninja:ninja-build"
    "gcc:gcc"
    "g++:g++"
    "python3:python3"
    "pkg-config:pkg-config"
)

for dep in "${DEPS[@]}"; do
    IFS=':' read -r cmd pkg <<< "$dep"
    if command -v "$cmd" >/dev/null 2>&1; then
        VERSION=$($cmd --version 2>/dev/null | head -1 || echo "unknown")
        pass "$cmd available: $VERSION"
    else
        warn "$cmd not found (install: sudo apt-get install $pkg)"
        ((WARNINGS++))
    fi
done

echo ""

# ============================================================================
# 7. Check disk space
# ============================================================================

info "Checking disk space..."

AVAILABLE=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE" -gt 50 ]; then
    pass "Sufficient disk space: ${AVAILABLE}GB available (need ~50GB for build)"
else
    warn "Limited disk space: ${AVAILABLE}GB available (recommend 50GB+)"
    ((WARNINGS++))
fi

echo ""

# ============================================================================
# 8. Test configuration loading
# ============================================================================

info "Testing configuration variables..."

source "./npu_military_config.sh" >/dev/null 2>&1

if [ -n "$CFLAGS_NPU_HARDENED" ]; then
    pass "CFLAGS_NPU_HARDENED is set"
else
    fail "CFLAGS_NPU_HARDENED is not set"
    ((ERRORS++))
fi

if [ -n "$OV_NPU_PLATFORM" ]; then
    pass "OV_NPU_PLATFORM is set to: $OV_NPU_PLATFORM"
else
    fail "OV_NPU_PLATFORM is not set"
    ((ERRORS++))
fi

echo ""

# ============================================================================
# 9. Summary
# ============================================================================

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  VERIFICATION SUMMARY                                                    ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ ALL CHECKS PASSED${NC}"
    echo ""
    echo "Repository is ready for building!"
    echo ""
    echo "Next steps:"
    echo "  1. Initialize OpenVINO sub-submodules (if warned above):"
    echo "     cd openvino && git submodule update --init --recursive --depth 1 && cd .."
    echo ""
    echo "  2. Build HARDVINO:"
    echo "     ./build_all.sh"
    echo ""
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ CHECKS PASSED WITH $WARNINGS WARNINGS${NC}"
    echo ""
    echo "Repository is mostly ready, but check warnings above."
    echo ""
    echo "To proceed anyway:"
    echo "  ./build_all.sh"
    echo ""
    exit 0
else
    echo -e "${RED}✗ CHECKS FAILED: $ERRORS ERRORS, $WARNINGS WARNINGS${NC}"
    echo ""
    echo "Please fix the errors above before building."
    echo ""
    exit 1
fi
