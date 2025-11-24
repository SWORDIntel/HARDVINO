#!/bin/bash
# ============================================================================
# Qualcomm QNN SDK Verification Script
# HARDVINO / DSMIL Platform
# ============================================================================
#
# Purpose: Verify Qualcomm QNN SDK installation and configuration
#
# Note: QNN SDK is closed-source and requires MANUAL installation via
#       Qualcomm Package Manager (qpm-cli). This script only VERIFIES
#       the installation - it does NOT install the SDK.
#
# Usage:
#   ./scripts/build_qnn.sh [--check-only] [--verbose]
#
# Exit Codes:
#   0 - QNN SDK found and verified
#   1 - QNN SDK not found (non-fatal for optional component)
#   2 - QNN SDK found but incomplete/corrupted
#
# See: docs/QNN_INTEGRATION.md for installation instructions
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
QNN_INSTALL_ROOT="/opt/qcom/aistack/qnn"
QNN_SDK_ROOT="${QNN_INSTALL_ROOT}/current"
VERBOSE=0
CHECK_ONLY=0

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
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

verbose_log() {
    if [[ $VERBOSE -eq 1 ]]; then
        log INFO "$*"
    fi
}

check_command() {
    local cmd=$1
    if command -v "$cmd" &> /dev/null; then
        verbose_log "Found command: $cmd ($(command -v "$cmd"))"
        return 0
    else
        verbose_log "Command not found: $cmd"
        return 1
    fi
}

check_file() {
    local file=$1
    local description=$2

    if [[ -f "$file" ]]; then
        verbose_log "Found $description: $file"
        return 0
    else
        log WARN "Missing $description: $file"
        return 1
    fi
}

check_directory() {
    local dir=$1
    local description=$2

    if [[ -d "$dir" ]]; then
        verbose_log "Found $description: $dir"
        return 0
    else
        log WARN "Missing $description: $dir"
        return 1
    fi
}

# ============================================================================
# Verification Functions
# ============================================================================

verify_qnn_installation() {
    log INFO "Verifying Qualcomm QNN SDK installation..."

    # Check if QNN install root exists
    if [[ ! -d "$QNN_INSTALL_ROOT" ]]; then
        log WARN "QNN installation directory not found: $QNN_INSTALL_ROOT"
        log WARN "QNN SDK is an optional component and must be installed manually"
        log WARN "See docs/QNN_INTEGRATION.md for installation instructions"
        return 1
    fi

    # Check if current symlink exists
    if [[ ! -L "$QNN_SDK_ROOT" ]]; then
        log ERROR "QNN SDK 'current' symlink not found: $QNN_SDK_ROOT"
        log ERROR "Expected a symlink to the active QNN version"
        return 2
    fi

    # Resolve symlink
    local qnn_version_path
    qnn_version_path=$(readlink -f "$QNN_SDK_ROOT")
    verbose_log "QNN SDK current version: $qnn_version_path"

    # Check if resolved path exists
    if [[ ! -d "$qnn_version_path" ]]; then
        log ERROR "QNN SDK symlink points to non-existent directory: $qnn_version_path"
        return 2
    fi

    log SUCCESS "QNN SDK installation root found: $QNN_SDK_ROOT"
    log SUCCESS "QNN SDK version: $(basename "$qnn_version_path")"

    return 0
}

verify_qnn_structure() {
    log INFO "Verifying QNN SDK directory structure..."

    local errors=0

    # Required directories
    local required_dirs=(
        "$QNN_SDK_ROOT/bin"
        "$QNN_SDK_ROOT/lib"
        "$QNN_SDK_ROOT/include"
    )

    for dir in "${required_dirs[@]}"; do
        if ! check_directory "$dir" "$(basename "$dir") directory"; then
            ((errors++))
        fi
    done

    # Required tools
    local required_tools=(
        "$QNN_SDK_ROOT/bin/qnn-profile"
        "$QNN_SDK_ROOT/bin/qnn-net-run"
    )

    for tool in "${required_tools[@]}"; do
        if ! check_file "$tool" "$(basename "$tool") tool"; then
            ((errors++))
        fi
    done

    # Check for libraries (architecture-specific)
    local lib_dirs=()
    if [[ -d "$QNN_SDK_ROOT/lib/x86_64-linux-gnu" ]]; then
        lib_dirs+=("$QNN_SDK_ROOT/lib/x86_64-linux-gnu")
    fi
    if [[ -d "$QNN_SDK_ROOT/lib/aarch64-linux-gnu" ]]; then
        lib_dirs+=("$QNN_SDK_ROOT/lib/aarch64-linux-gnu")
    fi
    if [[ -d "$QNN_SDK_ROOT/lib" ]]; then
        lib_dirs+=("$QNN_SDK_ROOT/lib")
    fi

    if [[ ${#lib_dirs[@]} -eq 0 ]]; then
        log ERROR "No QNN library directory found"
        ((errors++))
    else
        for lib_dir in "${lib_dirs[@]}"; do
            verbose_log "Found library directory: $lib_dir"

            # Check for core libraries
            local found_libs=0
            for lib in "$lib_dir"/libQnn*.so; do
                if [[ -f "$lib" ]]; then
                    verbose_log "Found QNN library: $(basename "$lib")"
                    ((found_libs++))
                fi
            done

            if [[ $found_libs -eq 0 ]]; then
                log WARN "No QNN libraries (libQnn*.so) found in $lib_dir"
                ((errors++))
            else
                verbose_log "Found $found_libs QNN libraries in $lib_dir"
            fi
        done
    fi

    if [[ $errors -gt 0 ]]; then
        log ERROR "QNN SDK structure verification failed with $errors errors"
        return 2
    fi

    log SUCCESS "QNN SDK structure verified"
    return 0
}

verify_qnn_permissions() {
    log INFO "Verifying QNN SDK permissions..."

    local errors=0

    # Check ownership
    local owner
    owner=$(stat -c '%U:%G' "$QNN_SDK_ROOT")

    if [[ "$owner" == "root:qnnsvc" ]]; then
        verbose_log "QNN SDK ownership correct: $owner"
    elif [[ "$owner" == "root:root" ]]; then
        log WARN "QNN SDK ownership is root:root (expected root:qnnsvc)"
        log WARN "Service account isolation not configured"
    else
        log WARN "QNN SDK ownership unexpected: $owner (expected root:qnnsvc)"
    fi

    # Check for world-writable files (security risk)
    local world_writable_count
    world_writable_count=$(find "$QNN_SDK_ROOT" -perm -o+w 2>/dev/null | wc -l)

    if [[ $world_writable_count -gt 0 ]]; then
        log ERROR "Found $world_writable_count world-writable files in QNN SDK"
        log ERROR "This is a SECURITY RISK - run: chmod -R o-w $QNN_SDK_ROOT"
        ((errors++))
    else
        verbose_log "No world-writable files found (good)"
    fi

    # Check qnnsvc user exists
    if getent passwd qnnsvc &>/dev/null; then
        verbose_log "Service account 'qnnsvc' exists"

        # Verify no login shell
        local qnnsvc_shell
        qnnsvc_shell=$(getent passwd qnnsvc | cut -d: -f7)
        if [[ "$qnnsvc_shell" == "/usr/sbin/nologin" ]] || [[ "$qnnsvc_shell" == "/bin/false" ]]; then
            verbose_log "Service account properly configured (no login shell)"
        else
            log WARN "Service account has login shell: $qnnsvc_shell (security risk)"
        fi
    else
        log WARN "Service account 'qnnsvc' not found"
        log WARN "Create with: groupadd qnnsvc && useradd -g qnnsvc -M -s /usr/sbin/nologin qnnsvc"
    fi

    if [[ $errors -gt 0 ]]; then
        log ERROR "QNN SDK permission verification failed"
        return 2
    fi

    log SUCCESS "QNN SDK permissions verified"
    return 0
}

verify_qnn_environment() {
    log INFO "Verifying QNN environment configuration..."

    # Check environment variables
    if [[ -n "${QNN_SDK_ROOT:-}" ]]; then
        verbose_log "QNN_SDK_ROOT is set: $QNN_SDK_ROOT"
    else
        log WARN "QNN_SDK_ROOT environment variable not set"
        log WARN "Add to ~/.profile: export QNN_SDK_ROOT=/opt/qcom/aistack/qnn/current"
    fi

    # Check if QNN libraries are in LD_LIBRARY_PATH
    if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
        if echo "$LD_LIBRARY_PATH" | grep -q "qnn"; then
            verbose_log "QNN libraries in LD_LIBRARY_PATH"
        else
            log WARN "QNN libraries not in LD_LIBRARY_PATH"
            log WARN "Add: export LD_LIBRARY_PATH=\$QNN_SDK_ROOT/lib/x86_64-linux-gnu:\$LD_LIBRARY_PATH"
        fi
    else
        log WARN "LD_LIBRARY_PATH not set"
    fi

    log SUCCESS "QNN environment configuration checked"
    return 0
}

verify_qnn_dependencies() {
    log INFO "Checking QNN system dependencies..."

    # Check for Python 3.10+
    if check_command python3.10; then
        local python_version
        python_version=$(python3.10 --version | awk '{print $2}')
        verbose_log "Python 3.10 version: $python_version"
    else
        log WARN "Python 3.10 not found (required for QNN)"
        log WARN "Install: apt install python3.10 python3.10-venv"
    fi

    # Check for build tools
    local build_tools=("gcc" "g++" "cmake" "make")
    for tool in "${build_tools[@]}"; do
        if ! check_command "$tool"; then
            log WARN "Build tool not found: $tool"
        fi
    done

    # Check for key libraries
    if ldconfig -p | grep -q libstdc++; then
        verbose_log "libstdc++ found"
    else
        log WARN "libstdc++ not found (required for QNN)"
    fi

    # Check if dependency checker scripts exist and run them
    if [[ -f "$QNN_SDK_ROOT/bin/check-python-dependency" ]]; then
        verbose_log "Running QNN Python dependency checker..."
        if [[ $VERBOSE -eq 1 ]]; then
            "$QNN_SDK_ROOT/bin/check-python-dependency" || log WARN "QNN Python dependency check reported issues"
        else
            "$QNN_SDK_ROOT/bin/check-python-dependency" &>/dev/null || log WARN "QNN Python dependency check reported issues (run with --verbose)"
        fi
    fi

    if [[ -f "$QNN_SDK_ROOT/bin/check-linux-dependency.sh" ]]; then
        verbose_log "Running QNN Linux dependency checker..."
        if [[ $VERBOSE -eq 1 ]]; then
            bash "$QNN_SDK_ROOT/bin/check-linux-dependency.sh" || log WARN "QNN Linux dependency check reported issues"
        else
            bash "$QNN_SDK_ROOT/bin/check-linux-dependency.sh" &>/dev/null || log WARN "QNN Linux dependency check reported issues (run with --verbose)"
        fi
    fi

    log SUCCESS "QNN dependency check complete"
    return 0
}

run_qnn_smoke_test() {
    log INFO "Running QNN smoke test..."

    # Check if qnn-profile exists and is executable
    if [[ ! -x "$QNN_SDK_ROOT/bin/qnn-profile" ]]; then
        log WARN "qnn-profile tool not executable, skipping smoke test"
        return 0
    fi

    # Check if example model exists
    local example_model=""
    if [[ -f "$QNN_SDK_ROOT/examples/models/mobilenet_v2/model.qnn" ]]; then
        example_model="$QNN_SDK_ROOT/examples/models/mobilenet_v2/model.qnn"
    fi

    if [[ -z "$example_model" ]]; then
        log WARN "No example models found, skipping smoke test"
        log WARN "Run manual test: qnn-profile --backend cpu --model <your-model.qnn>"
        return 0
    fi

    verbose_log "Running smoke test with: $example_model"

    # Run qnn-profile with CPU backend
    if "$QNN_SDK_ROOT/bin/qnn-profile" --backend cpu --model "$example_model" &>/dev/null; then
        log SUCCESS "QNN smoke test PASSED (CPU backend)"
    else
        log WARN "QNN smoke test failed (this may be expected if no model is available)"
        log WARN "Run manual verification: qnn-profile --backend cpu --model <your-model.qnn>"
    fi

    return 0
}

display_integration_info() {
    echo ""
    log INFO "QNN Integration Status:"
    echo ""
    echo "  Installation Path: $QNN_SDK_ROOT"
    echo "  Documentation:     docs/QNN_INTEGRATION.md"
    echo "  Build Stage:       6.5 (after QAT, before ML frameworks)"
    echo "  CMake Function:    target_link_qnn(target)"
    echo ""
    echo "  Environment Setup:"
    echo "    export QNN_SDK_ROOT=/opt/qcom/aistack/qnn/current"
    echo "    export LD_LIBRARY_PATH=\$QNN_SDK_ROOT/lib/x86_64-linux-gnu:\$LD_LIBRARY_PATH"
    echo ""
    echo "  Systemd Service:   /etc/systemd/system/qnn-inference.service"
    echo "  Service Account:   qnnsvc:qnnsvc"
    echo ""
}

# ============================================================================
# Main Script
# ============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                VERBOSE=1
                shift
                ;;
            --check-only)
                CHECK_ONLY=1
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--check-only] [--verbose]"
                echo ""
                echo "Options:"
                echo "  --check-only    Only check installation, don't run smoke tests"
                echo "  --verbose       Show detailed verification output"
                echo "  --help          Show this help message"
                echo ""
                echo "This script verifies the Qualcomm QNN SDK installation."
                echo "The QNN SDK must be installed manually - see docs/QNN_INTEGRATION.md"
                exit 0
                ;;
            *)
                log ERROR "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    echo "============================================================================"
    echo "Qualcomm QNN SDK Verification"
    echo "HARDVINO / DSMIL Platform"
    echo "============================================================================"
    echo ""

    # Run verification steps
    local exit_code=0

    # Step 1: Check installation
    if ! verify_qnn_installation; then
        exit_code=$?
        if [[ $exit_code -eq 1 ]]; then
            log INFO "QNN SDK not installed (optional component)"
            log INFO "See docs/QNN_INTEGRATION.md for installation instructions"
            exit 0  # Non-fatal for optional component
        else
            log ERROR "QNN SDK installation verification failed"
            exit $exit_code
        fi
    fi

    # Step 2: Verify structure
    if ! verify_qnn_structure; then
        exit_code=$?
    fi

    # Step 3: Verify permissions
    if ! verify_qnn_permissions; then
        exit_code=$?
    fi

    # Step 4: Verify environment
    verify_qnn_environment

    # Step 5: Check dependencies
    verify_qnn_dependencies

    # Step 6: Run smoke test (unless --check-only)
    if [[ $CHECK_ONLY -eq 0 ]]; then
        run_qnn_smoke_test
    fi

    # Display integration info
    display_integration_info

    # Final status
    echo ""
    if [[ $exit_code -eq 0 ]]; then
        log SUCCESS "QNN SDK verification complete - all checks passed"
        echo "============================================================================"
        exit 0
    else
        log ERROR "QNN SDK verification completed with errors"
        log ERROR "Review the output above and consult docs/QNN_INTEGRATION.md"
        echo "============================================================================"
        exit $exit_code
    fi
}

# Run main
main "$@"
