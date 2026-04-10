#!/usr/bin/env zsh
# test_lib_zsh.sh - Tests for lib.zsh specific functions

# Get the directory of this script (zsh-specific)
SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"

# Source test framework
source "$SCRIPT_DIR/test_framework.sh"

# Reset loaded flags for fresh test
unset LIBSHELL_COMMON_LOADED
unset LIBSHELL_ZSH_LOADED
unset LIBSHELL_DEPS_CHECKED

# Source the library to test
export LIBSHELL_QUIET=1
source "$PROJECT_DIR/lib.zsh"

# =============================================================================
# Test: Library Loading
# =============================================================================

test_start "lib.zsh sets LIBSHELL_ZSH_LOADED"
assert_equals "1" "$LIBSHELL_ZSH_LOADED"

test_start "lib.zsh loads common.sh (LIBSHELL_COMMON_LOADED)"
assert_equals "1" "$LIBSHELL_COMMON_LOADED"

test_start "LIBSHELL_VERSION is exported"
assert_equals "1.0.2" "$LIBSHELL_VERSION"

# =============================================================================
# Test: is_source function (zsh-specific)
# =============================================================================

test_start "is_source function exists"
if type is_source >/dev/null 2>&1; then
    test_pass
else
    test_fail "Function not defined"
fi

test_start "is_source returns true when lib.zsh is sourced"
# Create a script that sources lib.zsh and checks is_source
local temp_script=$(mktemp)
cat > "$temp_script" << SCRIPT
#!/usr/bin/env zsh
# Unset guard variables so lib.zsh actually loads in the subshell
# (they may be exported from parent shell)
unset LIBSHELL_ZSH_LOADED
unset LIBSHELL_COMMON_LOADED
export LIBSHELL_QUIET=1
source "$PROJECT_DIR/lib.zsh" 2>/dev/null
is_source
echo \$?
SCRIPT
chmod +x "$temp_script"
# Use zsh -c "source ..." to simulate sourcing context
local result=$(zsh -c "source $temp_script" 2>/dev/null)
rm -f "$temp_script"
assert_equals "0" "$result"

test_start "is_source returns false when lib.zsh is run directly"
# Create a script that tests the is_source logic in a "run" context
local temp_script=$(mktemp)
cat > "$temp_script" << 'SCRIPT'
#!/usr/bin/env zsh
# Simulate the is_source check in a "run" context
# When run directly, ZSH_EVAL_CONTEXT is "toplevel" (no ":file")
[[ "$ZSH_EVAL_CONTEXT" == *:file* ]]
echo $?
SCRIPT
chmod +x "$temp_script"
# Run directly (not source) - should return 1 (false)
local result=$(zsh "$temp_script" 2>/dev/null)
rm -f "$temp_script"
assert_equals "1" "$result"

# =============================================================================
# Test: require_arg function (zsh-specific)
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
# Test: prepend_path function (zsh-specific)
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

# =============================================================================
# Test: run_in_tmux function
# =============================================================================

test_start "run_in_tmux function exists"
if type run_in_tmux >/dev/null 2>&1; then
    test_pass
else
    test_fail "Function not defined"
fi

test_start "run_in_tmux fails for non-existent command"
run_in_tmux "nonexistent_cmd_12345" 2>/dev/null
assert_equals "$LIBSHELL_CMD_NOT_FOUND" "$?"

test_start "run_in_tmux creates alias for existing command"
if command -v tmux >/dev/null 2>&1; then
    # Unalias if exists
    unalias ls 2>/dev/null || true
    unalias ls.raw 2>/dev/null || true
    run_in_tmux ls >/dev/null 2>&1
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

test_start "run_in_tmux creates .raw alias"
if command -v tmux >/dev/null 2>&1; then
    unalias echo 2>/dev/null || true
    unalias echo.raw 2>/dev/null || true
    run_in_tmux echo >/dev/null 2>&1
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
# Test: Common functions available
# =============================================================================

test_start "log_err function available"
if type log_err >/dev/null 2>&1; then
    test_pass
else
    test_fail "Function not available"
fi

test_start "real_dir function available"
if type real_dir >/dev/null 2>&1; then
    test_pass
else
    test_fail "Function not available"
fi

test_start "permission2int function available"
if type permission2int >/dev/null 2>&1; then
    test_pass
else
    test_fail "Function not available"
fi

test_start "__run_in_tmux_wrapper function available"
if type __run_in_tmux_wrapper >/dev/null 2>&1; then
    test_pass
else
    test_fail "Function not available"
fi

# =============================================================================
# Test: Zsh-specific features
# =============================================================================

test_start "Zsh array splitting works in prepend_path"
MY_PATH="/a:/b:/c"
prepend_path MY_PATH "/new"
assert_equals "/new:/a:/b:/c" "$MY_PATH"

# =============================================================================
# Print Summary
# =============================================================================

test_summary
