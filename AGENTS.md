# AGENTS.md - Guidelines for AI Coding Agents

This document provides guidelines for AI agents working on the libshell codebase.

## Project Overview

libshell is a cross-platform shell utility library supporting **Bash 4.0+** and **Zsh 5.0+** on **Linux** and **macOS**. The codebase uses a layered architecture:

- `common.sh` - POSIX-compatible shared code (OS detection, dependency checks, utilities)
- `lib.bash` - Bash-specific implementations using bash syntax
- `lib.zsh` - Zsh-specific implementations using zsh syntax

## Build/Lint/Test Commands

### Run All Tests
```bash
./tests/run_tests.sh
```

### Run Specific Test Suite
```bash
./tests/run_tests.sh common    # Test common.sh only
./tests/run_tests.sh bash      # Test lib.bash only
./tests/run_tests.sh zsh       # Test lib.zsh only
```

### Run with Verbose Output
```bash
TEST_VERBOSE=1 ./tests/run_tests.sh
```

### Run a Single Test File Directly
```bash
bash tests/test_common.sh      # Common tests
bash tests/test_lib_bash.sh    # Bash tests
zsh tests/test_lib_zsh.sh      # Zsh tests
```

### Lint with ShellCheck (if available)
```bash
shellcheck common.sh lib.bash lib.zsh
shellcheck -s bash lib.bash tests/test_lib_bash.sh
shellcheck -s zsh lib.zsh tests/test_lib_zsh.sh  # Limited support
```

## Code Style Guidelines

### File Headers
Every shell file must start with a comment describing its purpose:
```bash
# filename.sh - Brief description of purpose
# Additional requirements or notes
```

### Guard Against Multiple Sourcing
All library files must prevent double-loading:
```bash
# For common.sh (POSIX)
if [ -n "$LIBSHELL_COMMON_LOADED" ]; then
    return 0
fi
export LIBSHELL_COMMON_LOADED=1
```

### Function Definitions
- Use `function name()` syntax for bash/zsh-specific files
- Use `name()` syntax (no `function` keyword) for POSIX-compatible code in common.sh

### Error Handling
- Use defined error codes from common.sh (e.g., `LIBSHELL_ARG_ERR`, `LIBSHELL_CMD_NOT_FOUND`)
- Always validate arguments at function start
- Use `log_err` for error messages (outputs to stderr)
- Return appropriate error codes, never use `exit` in library functions

```bash
function my_function() {
    if [ "$#" -ne 2 ]; then
        log_err "Usage: my_function <ARG1> <ARG2>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    # ... implementation
    return ${LIBSHELL_DEFAULT_OK}
}
```

### Error Codes
| Code | Constant | Use Case |
|------|----------|----------|
| 0 | `LIBSHELL_DEFAULT_OK` | Success |
| 1 | `LIBSHELL_DEFAULT_ERR` | General error |
| 2 | `LIBSHELL_ARG_ERR` | Invalid arguments |
| 3 | `LIBSHELL_SHELL_NOT_SUPPORTED` | Wrong shell type |
| 4 | `LIBSHELL_CMD_NOT_FOUND` | Missing dependency |
| 5 | `LIBSHELL_FILE_EXISTED` | File already exists |
| 6 | `LIBSHELL_FILE_TYPE_ERR` | Wrong file type |
| 7 | `LIBSHELL_FILE_IO_ERR` | I/O error |
| 8 | `LIBSHELL_LINK_ERR` | Symlink error |
| 9 | `LIBSHELL_OS_NOT_SUPPORTED` | Unsupported OS |

### Naming Conventions
- **Functions**: `snake_case` (e.g., `real_dir`, `prepend_path`)
- **Internal/private functions**: Prefix with `__libshell_` (e.g., `__libshell_check_cmd`)
- **Constants**: `UPPER_SNAKE_CASE` with `LIBSHELL_` prefix (e.g., `LIBSHELL_ARG_ERR`)
- **Local variables**: `snake_case`, always declare with `local`

### Shell-Specific Implementations

When a function requires different syntax for bash vs zsh, implement in both `lib.bash` and `lib.zsh`:

| Feature | Bash | Zsh |
|---------|------|-----|
| Indirect variable | `${!var}` | `${(P)var}` |
| Script path | `${BASH_SOURCE[0]}` | `$0` |
| Source detection | `BASH_SOURCE[0] != $0` | `ZSH_EVAL_CONTEXT =~ *:file*` |
| Realpath | `realpath` or `cd && pwd -P` | `${var:A}` |
| Dirname | `dirname` | `${var:h}` |
| Export function | `export -f func` | Not supported |

### OS-Specific Behavior

Always check `$LIBSHELL_OS` for OS-specific commands:
```bash
if [ "$LIBSHELL_OS" = "macos" ]; then
    sed -i '' "s/old/new/" file
else
    sed -i "s/old/new/" file
fi
```

### Dependency Checking

For functions requiring external commands, check availability:
```bash
function my_function() {
    __libshell_require_cmd rsync || return $?
    # ... use rsync
}
```

### Exporting Functions (Bash only)

In `lib.bash`, export functions that may be called from subshells:
```bash
function my_function() {
    # ... implementation
}
export -f my_function
```

Note: Zsh does not support `export -f`. Use pipelines instead of `find -exec bash -c`.

## Testing Guidelines

### Test Framework Functions
- `test_start "description"` - Start a test case
- `test_pass` / `test_fail "message"` - Mark result
- `test_skip "reason"` - Skip test
- `assert_equals expected actual` - Assert equality
- `assert_not_equals unexpected actual` - Assert inequality
- `assert_true "command"` - Assert command succeeds
- `assert_false "command"` - Assert command fails
- `test_summary` - Print summary (call at end)

### Testing Subshell Behavior

When testing functions in subshells, unset guard variables:
```bash
cat > "$temp_script" << SCRIPT
#!/usr/bin/env zsh
unset LIBSHELL_ZSH_LOADED
unset LIBSHELL_COMMON_LOADED
source "$PROJECT_DIR/lib.zsh"
# ... test code
SCRIPT
```

### Script Directory Detection
```bash
# Bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Zsh
SCRIPT_DIR="${0:A:h}"
```

### Reserved Keywords in prepend_path
The variables `var_name`, `new_path`, and `separator` are reserved and cannot be used as the first argument to `prepend_path`.

## Common Pitfalls

1. **Zsh `is_source` pattern**: Use `*:file*` not `:file$` (context changes in function calls)
2. **Exported guard variables**: Subshells inherit `LIBSHELL_*_LOADED`, causing early returns
3. **macOS `sed -i`**: Requires empty string argument `sed -i ''`
4. **macOS `stat`**: Use `-f "%Sp"` not `--format=%A`
5. **Heredoc variable expansion**: Use `<< 'EOF'` to prevent expansion, `<< EOF` to allow it
