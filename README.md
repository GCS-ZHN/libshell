# libshell

A cross-platform shell utility library for common operations, supporting **Bash**, **Zsh**, and **PowerShell** on **Linux**, **macOS**, and **Windows**.

## Installation

```bash
# Clone the repository
git clone https://github.com/GCS-ZHN/libshell.git

# For Bash users, add to ~/.bashrc
source /path/to/libshell/lib.bash

# For Zsh users, add to ~/.zshrc
source /path/to/libshell/lib.zsh
```

### PowerShell

```powershell
# Dot-source in your PowerShell profile ($PROFILE)
. /path/to/libshell/lib.ps1

# Or load temporarily in current session
. C:\path\to\libshell\lib.ps1
```

To find your PowerShell profile location:
```powershell
echo $PROFILE
```

## Auto-Update

libshell can automatically check for updates when loaded. Configure with environment variables:

```bash
# Enable auto-update (will pull updates automatically)
export LIBSHELL_AUTO_UPDATE=1

# Or just get notified about available updates (default behavior)
# No configuration needed - you'll see a message if updates are available
```

To manually update:
```bash
# Bash/Zsh
update_libshell

# PowerShell
Update-Libshell
# or
update_libshell
```

## Project Structure

```
libshell/
├── common.sh          # Shared POSIX-compatible code (OS detection, dependency check)
├── lib.bash           # Bash-specific implementation
├── lib.zsh            # Zsh-specific implementation
├── lib.ps1            # PowerShell implementation (Windows/Linux/macOS)
└── tests/
    ├── test_framework.sh   # Lightweight test framework
    ├── test_common.sh      # Tests for common.sh
    ├── test_lib_bash.sh    # Tests for lib.bash
    ├── test_lib_zsh.sh     # Tests for lib.zsh
    ├── test_lib_ps1.ps1    # Tests for lib.ps1
    └── run_tests.sh        # Test runner
```

## OS and Dependency Detection

### Supported Operating Systems

The library automatically detects the operating system and stores it in `$LIBSHELL_OS`:

| Value | OS |
|-------|-----|
| `linux` | Linux distributions |
| `macos` | macOS / Darwin |
| `freebsd` | FreeBSD |
| `cygwin` | Cygwin on Windows |
| `mingw` | MinGW on Windows |
| `unknown` | Unrecognized system |

### Dependency Checking

The library checks for optional dependencies at load time. Missing dependencies will show a warning with installation instructions:

```
[libshell] Optional dependencies not found: tmux xxd
[libshell] Some features may be unavailable. Set LIBSHELL_QUIET=1 to suppress this warning.
```

To suppress these warnings:
```bash
export LIBSHELL_QUIET=1
source lib.bash
```

### Required Dependencies by Function

| Function | Dependencies | Installation |
|----------|--------------|--------------|
| `prepend_path` (bash) | `perl` | Usually pre-installed |
| `port_avail` | `nc` (netcat) | `apt install netcat` / `brew install netcat` |
| `conda_mv` | `rsync` | `apt install rsync` / `brew install rsync` |
| `run_in_tmux` | `tmux`, `xxd`* | `apt install tmux` / `brew install tmux` |
| `grant_access`, `get_access` | `setfacl`, `getfacl` | `apt install acl` (Linux only**) |

\* `xxd` is optional; falls back to `$RANDOM` or timestamp if unavailable.

\*\* macOS uses a different ACL system (`chmod +a`); `setfacl`/`getfacl` are Linux-specific.

### OS-Specific Behavior

Some functions adapt to the operating system:

| Function | Linux | macOS |
|----------|-------|-------|
| `stat` for permissions | `stat --format=%A` | `stat -f "%Sp"` |
| `sed` in-place | `sed -i` | `sed -i ''` |
| `realpath` | External command | Zsh: `${var:A}`, Bash: `cd && pwd -P` |

## Usage Examples

### Bash

```bash
source lib.bash

# Check if argument is defined
require_arg MY_VAR || log_err 'MY_VAR not found'

# Prepend path to environment variable
prepend_path PATH "/usr/local/bin"

# Run command in tmux automatically
run_in_tmux python
python script.py        # Runs in tmux session
python.raw --version    # Runs directly without tmux
```

### Zsh

```zsh
source lib.zsh

# Same API as Bash
require_arg MY_VAR || log_err 'MY_VAR not found'
prepend_path PATH "/usr/local/bin"
run_in_tmux python
```

### PowerShell

```powershell
. lib.ps1

# Check if argument is defined
Test-RequiredArg -VarName "MY_VAR"

# Or use Unix-style alias
require_arg MY_VAR

# Prepend path to environment variable
Add-PathPrefix -VarName "PATH" -NewPath "C:\tools\bin"

# Or use Unix-style alias
prepend_path PATH "C:\tools\bin"

# Get real directory path
Get-RealDir "C:\Users"

# Hash functions
md5sum file.txt
sha256sum file.txt

# Logging
Write-LogError "Something went wrong"
Write-LogWarn "This is a warning"
Write-LogInfo "Information message"
```

## Function Reference

### Utility Functions

| Function | Description | Usage | Support |
|----------|-------------|-------|---------|
| `log_err` | Output error message to stderr | `log_err <MSG> [EXIT_CODE]` | Bash/Zsh/PowerShell, All OS |
| `is_source` | Check if script is being sourced | `is_source && echo "sourced"` | Bash/Zsh, Linux/macOS |
| `require_arg` | Check if variable is defined | `require_arg <VAR_NAME>` | Bash/Zsh/PowerShell, All OS |
| `is_user_exist` | Check if user exists | `is_user_exist <USER>` | Bash/Zsh/PowerShell, All OS |
| `update_libshell` | Update libshell from git remote | `update_libshell` | Bash/Zsh/PowerShell, All OS |

### Path Functions

| Function | Description | Usage | Support |
|----------|-------------|-------|---------|
| `real_dir` | Get absolute path of directory | `real_dir <DIR_PATH>` | Bash/Zsh/PowerShell, All OS |
| `real_file` | Get absolute path of file | `real_file <FILE_PATH>` | Bash/Zsh/PowerShell, All OS |
| `prepend_path` | Prepend path to variable (no duplicates) | `prepend_path <VAR> <PATH> [SEP]` | Bash/Zsh/PowerShell, All OS |
| `create_link` | Create symlink (idempotent) | `create_link <SOURCE> <TARGET>` | Bash/Zsh/PowerShell, All OS |

### Network Functions

| Function | Description | Usage | Support |
|----------|-------------|-------|---------|
| `port_avail` | Check if remote port is accessible | `port_avail <HOST> <PORT>` | Bash/Zsh/PowerShell, All OS |

### Permission Functions

> **Note**: ACL functions (`grant_access`, `get_access`, etc.) require `setfacl`/`getfacl` commands. 
> These are available on Linux by default and can be installed on macOS via Homebrew (`brew install coreutils`).

| Function | Description | Usage | Support |
|----------|-------------|-------|---------|
| `permission2int` | Convert permission string to int | `permission2int "rwx"` → `7` | Bash/Zsh, Linux/macOS |
| `int2permission` | Convert int to permission string | `int2permission 7` → `rwx` | Bash/Zsh, Linux/macOS |
| `grant_access` | Grant ACL access to user | `grant_access <PATH> <USER> [MASK]` | Bash/Zsh, Linux |
| `get_access` | Get user's ACL access | `get_access <PATH> <USER>` | Bash/Zsh, Linux |
| `check_executable` | Check if user has execute permission | `check_executable <PATH> <USER>` | Bash/Zsh, Linux |
| `loop_check_parent_executable` | Check execute permission on all parent dirs | `loop_check_parent_executable <PATH> <USER>` | Bash/Zsh, Linux |
| `copy_access` | Copy owner permissions to user | `copy_access <DIR> <USER> [MASK]` | Bash/Zsh, Linux |

### Hash Functions

| Function | Description | Usage | Support |
|----------|-------------|-------|---------|
| `md5sum` | Compute MD5 hash | `md5sum <FILE>` | PowerShell, All OS |
| `sha1sum` | Compute SHA1 hash | `sha1sum <FILE>` | PowerShell, All OS |
| `sha256sum` | Compute SHA256 hash | `sha256sum <FILE>` | PowerShell, All OS |
| `sha384sum` | Compute SHA384 hash | `sha384sum <FILE>` | PowerShell, All OS |
| `sha512sum` | Compute SHA512 hash | `sha512sum <FILE>` | PowerShell, All OS |

### Conda Functions

| Function | Description | Usage | Support |
|----------|-------------|-------|---------|
| `conda_mv` | Move conda environment to new location | `conda_mv <OLD_PATH> <NEW_PATH>` | Bash/Zsh/PowerShell, All OS |

### Slurm Functions

| Function | Description | Usage | Support |
|----------|-------------|-------|---------|
| `sbat` | Submit batch job with colored output | `sbat [ARGS...] <SCRIPT>` | Bash, Linux |
| `sque` | Query current user's jobs | `sque [ARGS...]` | Bash, Linux |

### Tmux Functions

| Function | Description | Usage | Support |
|----------|-------------|-------|---------|
| `run_in_tmux` | Create alias to run command in tmux | `run_in_tmux <CMD>` | Bash/Zsh, Linux/macOS |

#### `run_in_tmux` Details

This function creates two aliases for a command:

- `<cmd>` - Automatically runs in a new tmux session (with random suffix to avoid conflicts)
- `<cmd>.raw` - Runs the original command directly (useful for `--help`, `--version`)

**Smart Detection**: If already inside tmux, commands run directly without creating nested sessions.

```bash
# Setup
run_in_tmux python
# Output:
# Created aliases:
#   python     -> auto tmux wrapper (detects nested tmux)
#   python.raw -> original command (for --help, --version, etc.)

# Usage
python train.py          # Opens: tmux new -s python_a1b2c3d4 python train.py
python.raw --version     # Directly outputs: Python 3.x.x

# Inside tmux
python train.py          # Runs directly, no nested tmux
```

## Shell-Specific Implementations

Some functions require different implementations due to Bash/Zsh syntax differences:

### 1. `is_source` - Detect if script is being sourced

| Shell | Implementation | Key Feature |
|-------|---------------|-------------|
| Bash | `[ "${BASH_SOURCE[0]}" != "${0}" ]` | `BASH_SOURCE` array holds script call stack |
| Zsh | `[[ "$ZSH_EVAL_CONTEXT" =~ :file$ ]]` | `ZSH_EVAL_CONTEXT` tracks execution context |

### 2. `require_arg` - Check if variable is defined

| Shell | Implementation | Key Feature |
|-------|---------------|-------------|
| Bash | `[ -z "${!1}" ]` | `${!var}` indirect expansion |
| Zsh | `[[ -z "${(P)1}" ]]` | `${(P)var}` parameter expansion flag |

### 3. `prepend_path` - Add path to variable without duplicates

| Shell | Implementation | Key Feature |
|-------|---------------|-------------|
| Bash | `${!var_name}` + perl for search | Indirect expansion, external tool |
| Zsh | `${(P)var}` + `${(@s/:/)str}` + `${arr[(Ie)pat]}` | Native array split & search |

**Zsh-specific syntax explained:**
- `${(P)var}` - Indirect reference (like Bash's `${!var}`)
- `${(@s/:/)str}` - Split string by `:` into array (`@` preserves empty elements)
- `${arr[(Ie)pattern]}` - Reverse exact search in array, returns index (0 = not found)

### 4. `run_in_tmux` - Create tmux wrapper alias

| Shell | Implementation | Key Feature |
|-------|---------------|-------------|
| Bash | `alias cmd="__run_in_tmux_wrapper cmd"` | `export -f` exports wrapper to subshells |
| Zsh | `alias cmd="__run_in_tmux_wrapper cmd"` | Functions available without export |

**Shared wrapper function** (in `common.sh`):
```bash
__run_in_tmux_wrapper() {
    local cmd=$1; shift
    if [ -n "$TMUX" ]; then
        command $cmd "$@"              # Already in tmux, run directly
    else
        local suffix=$(head -c 4 /dev/urandom | xxd -p)
        tmux new -s "${cmd}_${suffix}" $cmd "$@"
    fi
}
```

### 5. `loop_check_parent_executable` - Check parent directory permissions

| Shell | Implementation | Key Feature |
|-------|---------------|-------------|
| Bash | `dirname $(realpath "$1")` | External commands |
| Zsh | `${1:A:h}` | Built-in modifiers (`:A` = realpath, `:h` = dirname) |

### 6. `copy_access` - Recursively grant permissions

| Shell | Implementation | Key Feature |
|-------|---------------|-------------|
| Bash | `find -exec bash -c 'func "$0"' {} \;` | `export -f` allows function in subshell |
| Zsh | `find -print0 \| while read -d ''` | No `export -f`, use pipeline instead |

### 7. Script Directory Detection

| Shell | Implementation | Key Feature |
|-------|---------------|-------------|
| Bash | `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` | `BASH_SOURCE[0]` |
| Zsh | `${0:A:h}` | `$0` + `:A` (absolute) + `:h` (head/dirname) |

## Feature Comparison

| Feature | Bash | Zsh |
|---------|------|-----|
| Indirect variable reference | `${!var}` | `${(P)var}` |
| Script path | `${BASH_SOURCE[0]}` | `$0` |
| Source detection | `BASH_SOURCE[0] != $0` | `ZSH_EVAL_CONTEXT =~ :file$` |
| Absolute path | `realpath` command | `${var:A}` modifier |
| Directory name | `dirname` command | `${var:h}` modifier |
| Basename | `basename` command | `${var:t}` modifier |
| String to array | `IFS=: read -ra arr <<< "$s"` | `arr=("${(@s/:/)s}")` |
| Array search | Loop or `grep` | `${arr[(Ie)pattern]}` |
| Export function | `export -f func` | Not supported |

## Running Tests

```bash
# Run all tests
./tests/run_tests.sh

# Run specific test suite
./tests/run_tests.sh common    # Test common.sh
./tests/run_tests.sh bash      # Test lib.bash
./tests/run_tests.sh zsh       # Test lib.zsh

# Verbose output
TEST_VERBOSE=1 ./tests/run_tests.sh
```

### Test Coverage

| Module | Functions Tested | Coverage |
|--------|------------------|----------|
| **common.sh** | `log_err`, `real_dir`, `real_file`, `permission2int`, `int2permission`, `is_user_exist`, `create_link`, `__run_in_tmux_wrapper` | Core utilities |
| **lib.bash** | `is_source`, `require_arg`, `prepend_path`, `run_in_tmux`, `sbat`, `sque` + function exports | Bash-specific |
| **lib.zsh** | `is_source`, `require_arg`, `prepend_path`, `run_in_tmux` + common function availability | Zsh-specific |

**Test Categories:**
- **Constant definitions** - Error codes properly defined
- **Argument validation** - Functions reject invalid arguments
- **Return codes** - Functions return correct exit codes
- **Output verification** - Functions produce expected output
- **Edge cases** - Empty variables, non-existent paths, duplicate paths
- **Alias creation** - `run_in_tmux` creates both `<cmd>` and `<cmd>.raw` aliases

**Not Covered (require manual testing):**
- `conda_mv` - Requires conda environment
- `grant_access`, `get_access`, `copy_access` - Require ACL tools and multi-user setup
- `sbat`, `sque` - Require Slurm cluster
- `port_avail` - Requires network setup

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 0 | `LIBSHELL_DEFAULT_OK` | Success |
| 1 | `LIBSHELL_DEFAULT_ERR` | General error |
| 2 | `LIBSHELL_ARG_ERR` | Argument error |
| 3 | `LIBSHELL_SHELL_NOT_SUPPORTED` | Unsupported shell |
| 4 | `LIBSHELL_CMD_NOT_FOUND` | Command not found |
| 5 | `LIBSHELL_FILE_EXISTED` | File already exists |
| 6 | `LIBSHELL_FILE_TYPE_ERR` | File type error |
| 7 | `LIBSHELL_FILE_IO_ERR` | File I/O error |
| 8 | `LIBSHELL_LINK_ERR` | Symlink error |
| 9 | `LIBSHELL_OS_NOT_SUPPORTED` | Unsupported operating system |

## License

MIT License
