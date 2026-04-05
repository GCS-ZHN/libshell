# test_framework.sh - Simple shell unit testing framework
# This framework is POSIX-compatible and can be used with both bash and zsh

# =============================================================================
# Test Framework Variables
# =============================================================================
TEST_PASSED=0
TEST_FAILED=0
TEST_SKIPPED=0
TEST_TOTAL=0
CURRENT_TEST=""
TEST_VERBOSE=${TEST_VERBOSE:-0}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Test Framework Functions
# =============================================================================

test_start() {
    # Start a new test case
    # Usage: test_start "test description"
    CURRENT_TEST="$1"
    TEST_TOTAL=$((TEST_TOTAL + 1))
    if [ "$TEST_VERBOSE" -eq 1 ]; then
        echo -e "${BLUE}[RUN]${NC} $CURRENT_TEST"
    fi
}

test_pass() {
    # Mark current test as passed
    TEST_PASSED=$((TEST_PASSED + 1))
    echo -e "${GREEN}[PASS]${NC} $CURRENT_TEST"
}

test_fail() {
    # Mark current test as failed with optional message
    # Usage: test_fail [message]
    TEST_FAILED=$((TEST_FAILED + 1))
    local msg="${1:-}"
    if [ -n "$msg" ]; then
        echo -e "${RED}[FAIL]${NC} $CURRENT_TEST: $msg"
    else
        echo -e "${RED}[FAIL]${NC} $CURRENT_TEST"
    fi
}

test_skip() {
    # Skip current test with optional reason
    # Usage: test_skip [reason]
    TEST_SKIPPED=$((TEST_SKIPPED + 1))
    local reason="${1:-}"
    if [ -n "$reason" ]; then
        echo -e "${YELLOW}[SKIP]${NC} $CURRENT_TEST: $reason"
    else
        echo -e "${YELLOW}[SKIP]${NC} $CURRENT_TEST"
    fi
}

# =============================================================================
# Assertion Functions
# =============================================================================

assert_equals() {
    # Assert two values are equal
    # Usage: assert_equals expected actual [message]
    local expected="$1"
    local actual="$2"
    local msg="${3:-Expected '$expected' but got '$actual'}"
    if [ "$expected" = "$actual" ]; then
        test_pass
        return 0
    else
        test_fail "$msg"
        return 1
    fi
}

assert_not_equals() {
    # Assert two values are not equal
    # Usage: assert_not_equals unexpected actual [message]
    local unexpected="$1"
    local actual="$2"
    local msg="${3:-Expected value different from '$unexpected'}"
    if [ "$unexpected" != "$actual" ]; then
        test_pass
        return 0
    else
        test_fail "$msg"
        return 1
    fi
}

assert_true() {
    # Assert command returns 0 (true)
    # Usage: assert_true command [message]
    local cmd="$1"
    local msg="${2:-Expected command to succeed}"
    if eval "$cmd"; then
        test_pass
        return 0
    else
        test_fail "$msg"
        return 1
    fi
}

assert_false() {
    # Assert command returns non-zero (false)
    # Usage: assert_false command [message]
    local cmd="$1"
    local msg="${2:-Expected command to fail}"
    if eval "$cmd"; then
        test_fail "$msg"
        return 1
    else
        test_pass
        return 0
    fi
}

assert_exit_code() {
    # Assert command returns specific exit code
    # Usage: assert_exit_code expected_code command [message]
    local expected=$1
    local cmd="$2"
    local msg="${3:-Expected exit code $expected}"
    eval "$cmd"
    local actual=$?
    if [ "$expected" -eq "$actual" ]; then
        test_pass
        return 0
    else
        test_fail "$msg (got $actual)"
        return 1
    fi
}

assert_output_contains() {
    # Assert command output contains expected string
    # Usage: assert_output_contains expected command [message]
    local expected="$1"
    local cmd="$2"
    local msg="${3:-Expected output to contain '$expected'}"
    local output
    output=$(eval "$cmd" 2>&1)
    if echo "$output" | grep -q "$expected"; then
        test_pass
        return 0
    else
        test_fail "$msg (output: $output)"
        return 1
    fi
}

assert_output_equals() {
    # Assert command output equals expected string
    # Usage: assert_output_equals expected command [message]
    local expected="$1"
    local cmd="$2"
    local msg="${3:-Expected output '$expected'}"
    local output
    output=$(eval "$cmd" 2>&1)
    if [ "$expected" = "$output" ]; then
        test_pass
        return 0
    else
        test_fail "$msg (got: '$output')"
        return 1
    fi
}

assert_file_exists() {
    # Assert file exists
    # Usage: assert_file_exists path [message]
    local path="$1"
    local msg="${2:-Expected file '$path' to exist}"
    if [ -f "$path" ]; then
        test_pass
        return 0
    else
        test_fail "$msg"
        return 1
    fi
}

assert_dir_exists() {
    # Assert directory exists
    # Usage: assert_dir_exists path [message]
    local path="$1"
    local msg="${2:-Expected directory '$path' to exist}"
    if [ -d "$path" ]; then
        test_pass
        return 0
    else
        test_fail "$msg"
        return 1
    fi
}

assert_command_exists() {
    # Assert command is available
    # Usage: assert_command_exists command [message]
    local cmd="$1"
    local msg="${2:-Expected command '$cmd' to exist}"
    if command -v "$cmd" >/dev/null 2>&1; then
        test_pass
        return 0
    else
        test_fail "$msg"
        return 1
    fi
}

# =============================================================================
# Test Runner Functions
# =============================================================================

test_summary() {
    # Print test summary
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo -e "Total:   $TEST_TOTAL"
    echo -e "${GREEN}Passed:  $TEST_PASSED${NC}"
    echo -e "${RED}Failed:  $TEST_FAILED${NC}"
    echo -e "${YELLOW}Skipped: $TEST_SKIPPED${NC}"
    echo "=========================================="
    
    if [ "$TEST_FAILED" -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

run_test_file() {
    # Run a test file
    # Usage: run_test_file path/to/test_file.sh
    local test_file="$1"
    if [ -f "$test_file" ]; then
        echo ""
        echo "Running tests from: $test_file"
        echo "------------------------------------------"
        source "$test_file"
    else
        echo -e "${RED}Test file not found: $test_file${NC}"
        return 1
    fi
}

# =============================================================================
# Setup/Teardown Helpers
# =============================================================================

create_temp_dir() {
    # Create a temporary directory for tests
    mktemp -d "${TMPDIR:-/tmp}/libshell_test.XXXXXX"
}

cleanup_temp_dir() {
    # Clean up temporary directory
    # Usage: cleanup_temp_dir path
    local path="$1"
    if [ -d "$path" ] && [[ "$path" == *libshell_test* ]]; then
        rm -rf "$path"
    fi
}
