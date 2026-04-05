#!/usr/bin/env bash
# run_tests.sh - Run all libshell tests
#
# Usage:
#   ./run_tests.sh           # Run all tests
#   ./run_tests.sh bash      # Run bash tests only
#   ./run_tests.sh zsh       # Run zsh tests only
#   ./run_tests.sh common    # Run common tests only
#
# Environment variables:
#   TEST_VERBOSE=1           # Enable verbose output

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "LibShell Test Runner"
echo -e "==========================================${NC}"
echo ""

# Track overall results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

run_test_suite() {
    local name="$1"
    local shell="$2"
    local test_file="$3"
    
    echo -e "${BLUE}------------------------------------------"
    echo "Running: $name"
    echo -e "------------------------------------------${NC}"
    
    TOTAL_SUITES=$((TOTAL_SUITES + 1))
    
    if "$shell" "$test_file"; then
        PASSED_SUITES=$((PASSED_SUITES + 1))
    else
        FAILED_SUITES=$((FAILED_SUITES + 1))
    fi
    echo ""
}

# Determine which tests to run
TEST_TARGET="${1:-all}"

case "$TEST_TARGET" in
    common)
        run_test_suite "Common Tests (bash)" "bash" "$SCRIPT_DIR/test_common.sh"
        ;;
    bash)
        run_test_suite "Bash Tests" "bash" "$SCRIPT_DIR/test_lib_bash.sh"
        ;;
    zsh)
        if command -v zsh >/dev/null 2>&1; then
            run_test_suite "Zsh Tests" "zsh" "$SCRIPT_DIR/test_lib_zsh.sh"
        else
            echo -e "${RED}zsh not found, skipping zsh tests${NC}"
        fi
        ;;
    all)
        run_test_suite "Common Tests (bash)" "bash" "$SCRIPT_DIR/test_common.sh"
        run_test_suite "Bash Tests" "bash" "$SCRIPT_DIR/test_lib_bash.sh"
        if command -v zsh >/dev/null 2>&1; then
            run_test_suite "Zsh Tests" "zsh" "$SCRIPT_DIR/test_lib_zsh.sh"
        else
            echo -e "${RED}zsh not found, skipping zsh tests${NC}"
        fi
        ;;
    *)
        echo "Unknown test target: $TEST_TARGET"
        echo "Usage: $0 [all|common|bash|zsh]"
        exit 1
        ;;
esac

# Print overall summary
echo -e "${BLUE}=========================================="
echo "Overall Test Summary"
echo -e "==========================================${NC}"
echo "Test Suites: $TOTAL_SUITES"
echo -e "${GREEN}Passed: $PASSED_SUITES${NC}"
echo -e "${RED}Failed: $FAILED_SUITES${NC}"
echo "=========================================="

if [ "$FAILED_SUITES" -eq 0 ]; then
    echo -e "${GREEN}All test suites passed!${NC}"
    exit 0
else
    echo -e "${RED}Some test suites failed!${NC}"
    exit 1
fi
