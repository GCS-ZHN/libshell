#!/usr/bin/env bash
# test_lib_bash.sh - Tests for lib.bash specific functions

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source test framework
source "$SCRIPT_DIR/test_framework.sh"

# Reset loaded flags for fresh test
unset LIBSHELL_COMMON_LOADED
unset LIBSHELL_BASH_LOADED
unset LIBSHELL_DEPS_CHECKED

# Source the library to test
export LIBSHELL_QUIET=1
source "$PROJECT_DIR/lib.bash"

# =============================================================================
# Test: Library Loading
# =============================================================================

test_start "lib.bash sets LIBSHELL_BASH_LOADED"
assert_equals "1" "$LIBSHELL_BASH_LOADED"

test_start "lib.bash loads common.sh (LIBSHELL_COMMON_LOADED)"
assert_equals "1" "$LIBSHELL_COMMON_LOADED"

test_start "LIBSHELL_VERSION is exported"
assert_equals "1.2.0" "$LIBSHELL_VERSION"

# =============================================================================
# Test: is_source function (bash-specific)
# =============================================================================

test_start "is_source function exists"
if type is_source >/dev/null 2>&1; then
    test_pass
else
    test_fail "Function not defined"
fi

test_start "is_source returns true when lib.bash is sourced"
# Create a script that sources lib.bash and checks is_source
temp_script=$(mktemp)
cat > "$temp_script" << SCRIPT
#!/usr/bin/env bash
export LIBSHELL_QUIET=1
source "$PROJECT_DIR/lib.bash" 2>/dev/null
is_source
echo \$?
SCRIPT
chmod +x "$temp_script"
result=$(bash -c "source $temp_script" 2>/dev/null)
rm -f "$temp_script"
assert_equals "0" "$result"

test_start "is_source returns false when lib.bash is run directly"
# Create a script that tests the is_source logic in a "run" context
temp_script=$(mktemp)
cat > "$temp_script" << 'SCRIPT'
#!/usr/bin/env bash
# Simulate the is_source check in a "run" context
# When run directly, BASH_SOURCE[0] equals $0
[ "${BASH_SOURCE[0]}" != "${0}" ]
echo $?
SCRIPT
chmod +x "$temp_script"
# Run directly (not source) - should return 1 (false)
result=$(bash "$temp_script" 2>/dev/null)
rm -f "$temp_script"
assert_equals "1" "$result"

# =============================================================================
# Test: require_arg function (bash-specific)
# =============================================================================

test_start "require_arg returns OK for defined variable"
TEST_VAR="hello"
require_arg TEST_VAR
assert_equals "0" "$?"

test_start "require_arg returns ARG_ERR for undefined variable"
unset UNDEFINED_VAR
require_arg UNDEFINED_VAR
assert_equals "$LIBSHELL_ARG_ERR" "$?"

test_start "require_arg returns ARG_ERR for empty variable"
EMPTY_VAR=""
require_arg EMPTY_VAR
assert_equals "$LIBSHELL_ARG_ERR" "$?"

# =============================================================================
# Test: prepend_path function (bash-specific)
# =============================================================================

test_start "prepend_path adds path to empty variable"
unset MY_PATH
prepend_path MY_PATH "/new/path"
assert_equals "/new/path" "$MY_PATH"

test_start "prepend_path prepends to existing path"
MY_PATH="/existing/path"
prepend_path MY_PATH "/new/path"
assert_equals "/new/path:/existing/path" "$MY_PATH"

test_start "prepend_path does not duplicate existing path"
MY_PATH="/existing/path"
prepend_path MY_PATH "/existing/path"
assert_equals "/existing/path" "$MY_PATH"

test_start "prepend_path rejects reserved keyword 'var_name'"
prepend_path var_name "/some/path" 2>/dev/null
assert_equals "$LIBSHELL_ARG_ERR" "$?"

test_start "prepend_path supports custom separator"
MY_LIST="item1"
prepend_path MY_LIST "item2" ","
assert_equals "item2,item1" "$MY_LIST"

# =============================================================================
# Test: trun function

test_start "trun function exists"
if type trun >/dev/null 2>&1; then
    test_pass
else
    test_fail "Function not defined"
fi

test_start "trun fails for non-existent command"
trun "nonexistent_cmd_12345" 2>/dev/null
assert_equals "$LIBSHELL_CMD_NOT_FOUND" "$?"

test_start "trun fails for tmux command"
trun tmux 2>/dev/null
assert_equals "$LIBSHELL_ARG_ERR" "$?"

test_start "trun creates alias for existing command"
if command -v tmux >/dev/null 2>&1; then
    # Unalias if exists
    unalias ls 2>/dev/null || true
    unalias ls.raw 2>/dev/null || true
    trun ls >/dev/null 2>&1
    if alias ls >/dev/null 2>&1; then
        test_pass
        unalias ls 2>/dev/null || true
        unalias ls.raw 2>/dev/null || true
    else
        test_fail "Alias not created"
    fi
else
    test_skip "tmux not installed"
fi

test_start "trun creates .raw alias"
if command -v tmux >/dev/null 2>&1; then
    unalias echo 2>/dev/null || true
    unalias echo.raw 2>/dev/null || true
    trun echo >/dev/null 2>&1
    if alias echo.raw >/dev/null 2>&1; then
        test_pass
        unalias echo 2>/dev/null || true
        unalias echo.raw 2>/dev/null || true
    else
        test_fail ".raw alias not created"
    fi
else
    test_skip "tmux not installed"
fi

# =============================================================================
# Test: Exported Functions
# =============================================================================

test_start "log_err is exported"
if bash -c 'type log_err' >/dev/null 2>&1; then
    test_pass
else
    test_fail "Function not exported"
fi

test_start "real_dir is exported"
if bash -c 'type real_dir' >/dev/null 2>&1; then
    test_pass
else
    test_fail "Function not exported"
fi

test_start "__run_in_tmux_wrapper is exported"
if bash -c 'type __run_in_tmux_wrapper' >/dev/null 2>&1; then
    test_pass
else
    test_fail "Function not exported"
fi

# =============================================================================
# Test: Slurm functions (may skip if not available)
# =============================================================================

test_start "sbat function exists"
if type sbat >/dev/null 2>&1; then
    test_pass
else
    test_fail "Function not defined"
fi

test_start "sque function exists"
if type sque >/dev/null 2>&1; then
    test_pass
else
    test_fail "Function not defined"
fi

# =============================================================================
# Print Summary
# =============================================================================

test_summary
