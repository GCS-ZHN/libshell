#!/usr/bin/env bash
# test_common.sh - Tests for common.sh functions

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source test framework
source "$SCRIPT_DIR/test_framework.sh"

# Source the library to test
export LIBSHELL_QUIET=1
unset LIBSHELL_COMMON_LOADED  # Ensure fresh load even if inherited from parent
source "$PROJECT_DIR/common.sh"

# =============================================================================
# Test: Error Codes
# =============================================================================

test_start "Error codes are defined"
if [ -n "$LIBSHELL_DEFAULT_OK" ] && \
   [ -n "$LIBSHELL_DEFAULT_ERR" ] && \
   [ -n "$LIBSHELL_ARG_ERR" ]; then
    test_pass
else
    test_fail "Error codes not properly defined"
fi

test_start "LIBSHELL_DEFAULT_OK equals 0"
assert_equals "0" "$LIBSHELL_DEFAULT_OK"

test_start "LIBSHELL_ARG_ERR equals 2"
assert_equals "2" "$LIBSHELL_ARG_ERR"

# =============================================================================
# Test: OS Detection
# =============================================================================

test_start "LIBSHELL_OS is set"
if [ -n "$LIBSHELL_OS" ]; then
    test_pass
else
    test_fail "LIBSHELL_OS not set"
fi

test_start "LIBSHELL_OS is valid value"
case "$LIBSHELL_OS" in
    linux|macos|freebsd|cygwin|mingw|unknown)
        test_pass
        ;;
    *)
        test_fail "Invalid LIBSHELL_OS value: $LIBSHELL_OS"
        ;;
esac

# =============================================================================
# Test: Dependency Check Functions
# =============================================================================

test_start "__libshell_check_cmd returns 0 for existing command"
__libshell_check_cmd ls 2>/dev/null
assert_equals "0" "$?"

test_start "__libshell_check_cmd returns 1 for non-existing command"
__libshell_check_cmd nonexistent_cmd_12345 2>/dev/null
assert_equals "1" "$?"

test_start "__libshell_get_install_hint returns non-empty for tmux"
hint=$(__libshell_get_install_hint tmux)
if [ -n "$hint" ]; then
    test_pass
else
    test_fail "Expected non-empty hint"
fi

# =============================================================================
# Test: log_err function
# =============================================================================

test_start "log_err outputs to stderr"
output=$(log_err "test error message" 2>&1)
assert_output_contains "test error message" "echo '$output'"

test_start "log_err returns custom exit code"
log_err "test" 42 2>/dev/null
assert_equals "42" "$?"

test_start "log_err with missing args returns ARG_ERR"
log_err 2>/dev/null
assert_equals "$LIBSHELL_ARG_ERR" "$?"

# =============================================================================
# Test: permission2int function
# =============================================================================

test_start "permission2int converts 'rwx' to 7"
result=$(permission2int "rwx")
assert_equals "7" "$result"

test_start "permission2int converts 'r--' to 4"
result=$(permission2int "r--")
assert_equals "4" "$result"

test_start "permission2int converts 'rw-' to 6"
result=$(permission2int "rw-")
assert_equals "6" "$result"

test_start "permission2int converts '--x' to 1"
result=$(permission2int "--x")
assert_equals "1" "$result"

test_start "permission2int converts '---' to 0"
result=$(permission2int "---")
assert_equals "0" "$result"

# =============================================================================
# Test: int2permission function
# =============================================================================

test_start "int2permission converts 7 to 'rwx'"
result=$(int2permission 7)
assert_equals "rwx" "$result"

test_start "int2permission converts 4 to 'r'"
result=$(int2permission 4)
assert_equals "r" "$result"

test_start "int2permission converts 6 to 'rw'"
result=$(int2permission 6)
assert_equals "rw" "$result"

test_start "int2permission converts 0 to empty string"
result=$(int2permission 0)
assert_equals "" "$result"

# =============================================================================
# Test: real_dir function
# =============================================================================

test_start "real_dir returns absolute path for existing directory"
result=$(real_dir "/tmp")
# On macOS, /tmp is a symlink to /private/tmp, but on Linux it's just /tmp
if [ "$result" = "/tmp" ] || [ "$result" = "/private/tmp" ]; then
    test_pass
else
    test_fail "Expected '/tmp' or '/private/tmp' but got '$result'"
fi

test_start "real_dir fails for non-existent directory"
real_dir "/nonexistent_dir_12345" 2>/dev/null
assert_equals "$LIBSHELL_FILE_TYPE_ERR" "$?"

test_start "real_dir fails for file path"
TEMP_FILE=$(mktemp)
real_dir "$TEMP_FILE" 2>/dev/null
code=$?
rm -f "$TEMP_FILE"
assert_equals "$LIBSHELL_FILE_TYPE_ERR" "$code"

# =============================================================================
# Test: real_file function
# =============================================================================

test_start "real_file returns absolute path for existing file"
TEMP_FILE=$(mktemp)
result=$(real_file "$TEMP_FILE")
rm -f "$TEMP_FILE"
if [ -n "$result" ]; then
    test_pass
else
    test_fail "Expected non-empty path"
fi

test_start "real_file fails for non-existent file"
real_file "/nonexistent_file_12345" 2>/dev/null
assert_equals "$LIBSHELL_FILE_TYPE_ERR" "$?"

test_start "real_file fails for directory path"
real_file "/tmp" 2>/dev/null
assert_equals "$LIBSHELL_FILE_TYPE_ERR" "$?"

# =============================================================================
# Test: is_user_exist function
# =============================================================================

test_start "is_user_exist succeeds for current user"
is_user_exist "$USER" 2>/dev/null
assert_equals "0" "$?"

test_start "is_user_exist fails for non-existent user"
is_user_exist "nonexistent_user_12345" 2>/dev/null
assert_equals "$LIBSHELL_DEFAULT_ERR" "$?"

# =============================================================================
# Test: create_link function
# =============================================================================

test_start "create_link creates symlink"
TEMP_DIR=$(create_temp_dir)
touch "$TEMP_DIR/source_file"
create_link "$TEMP_DIR/source_file" "$TEMP_DIR/link_file"
if [ -L "$TEMP_DIR/link_file" ]; then
    test_pass
else
    test_fail "Symlink not created"
fi
cleanup_temp_dir "$TEMP_DIR"

test_start "create_link is idempotent for same target"
TEMP_DIR=$(create_temp_dir)
touch "$TEMP_DIR/source_file"
create_link "$TEMP_DIR/source_file" "$TEMP_DIR/link_file"
create_link "$TEMP_DIR/source_file" "$TEMP_DIR/link_file"
assert_equals "0" "$?"
cleanup_temp_dir "$TEMP_DIR"

# =============================================================================
# Test: __run_in_tmux_wrapper function
# =============================================================================

test_start "__run_in_tmux_wrapper is defined"
if type __run_in_tmux_wrapper >/dev/null 2>&1; then
    test_pass
else
    test_fail "Function not defined"
fi

# =============================================================================
# Print Summary
# =============================================================================

test_summary
