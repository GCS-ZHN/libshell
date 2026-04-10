# common.sh - Shared constants and POSIX-compatible functions for libshell
# This file should be sourced by lib.bash and lib.zsh

# Prevent multiple sourcing in the same shell session
# Note: Do NOT export this variable - subshells should reload the library
if [ -n "$LIBSHELL_COMMON_LOADED" ]; then
    return 0
fi
LIBSHELL_COMMON_LOADED=1

# =============================================================================
# Constants / Error Codes
# =============================================================================
export LIBSHELL_VERSION=1.0.1

LIBSHELL_DEFAULT_OK=0
LIBSHELL_DEFAULT_ERR=1
LIBSHELL_ARG_ERR=2
LIBSHELL_SHELL_NOT_SUPPORTED=3
LIBSHELL_CMD_NOT_FOUND=4
LIBSHELL_FILE_EXISTED=5
LIBSHELL_FILE_TYPE_ERR=6
LIBSHELL_FILE_IO_ERR=7
LIBSHELL_LINK_ERR=8
LIBSHELL_OS_NOT_SUPPORTED=9

# =============================================================================
# OS Detection
# =============================================================================
__libshell_detect_os() {
    local uname_out
    uname_out=$(uname -s 2>/dev/null)
    case "$uname_out" in
        Linux*)   LIBSHELL_OS="linux" ;;
        Darwin*)  LIBSHELL_OS="macos" ;;
        CYGWIN*)  LIBSHELL_OS="cygwin" ;;
        MINGW*)   LIBSHELL_OS="mingw" ;;
        FreeBSD*) LIBSHELL_OS="freebsd" ;;
        *)        LIBSHELL_OS="unknown" ;;
    esac
    export LIBSHELL_OS
}

__libshell_detect_os

# =============================================================================
# Dependency Check Functions
# =============================================================================
__libshell_check_cmd() {
    # Check if a command exists, print install hint if not
    # Usage: __libshell_check_cmd <cmd> [install_hint]
    # Returns: 0 if exists, 1 if not
    local cmd=$1
    local hint=${2:-""}
    
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi
    
    if [ -n "$hint" ]; then
        echo -e "\033[33m[libshell] Warning: '$cmd' not found. $hint\033[0m" >&2
    fi
    return 1
}

__libshell_get_install_hint() {
    # Get installation hint for a command based on OS
    # Usage: __libshell_get_install_hint <cmd>
    local cmd=$1
    local hint=""
    
    case "$cmd" in
        tmux)
            case "$LIBSHELL_OS" in
                macos)  hint="Install with: brew install tmux" ;;
                linux)  hint="Install with: apt install tmux / yum install tmux" ;;
                *)      hint="Please install tmux" ;;
            esac
            ;;
        nc|netcat)
            case "$LIBSHELL_OS" in
                macos)  hint="Usually pre-installed. If not: brew install netcat" ;;
                linux)  hint="Install with: apt install netcat / yum install nmap-ncat" ;;
                *)      hint="Please install netcat" ;;
            esac
            ;;
        rsync)
            case "$LIBSHELL_OS" in
                macos)  hint="Usually pre-installed. If not: brew install rsync" ;;
                linux)  hint="Install with: apt install rsync / yum install rsync" ;;
                *)      hint="Please install rsync" ;;
            esac
            ;;
        setfacl|getfacl)
            case "$LIBSHELL_OS" in
                macos)  hint="macOS uses different ACL system. Use 'chmod +a' instead" ;;
                linux)  hint="Install with: apt install acl / yum install acl" ;;
                *)      hint="Please install acl utilities" ;;
            esac
            ;;
        perl)
            case "$LIBSHELL_OS" in
                macos)  hint="Usually pre-installed. If not: brew install perl" ;;
                linux)  hint="Install with: apt install perl / yum install perl" ;;
                *)      hint="Please install perl" ;;
            esac
            ;;
        xxd)
            case "$LIBSHELL_OS" in
                macos)  hint="Usually pre-installed (part of vim). If not: brew install vim" ;;
                linux)  hint="Install with: apt install xxd / yum install vim-common" ;;
                *)      hint="Please install xxd (usually part of vim)" ;;
            esac
            ;;
        sbatch|squeue)
            hint="Slurm commands. Only available on HPC clusters with Slurm installed"
            ;;
        *)
            hint="Please install '$cmd'"
            ;;
    esac
    
    echo "$hint"
}

__libshell_require_cmd() {
    # Require a command, exit with error if not found
    # Usage: __libshell_require_cmd <cmd>
    local cmd=$1
    local hint=$(__libshell_get_install_hint "$cmd")
    
    if ! __libshell_check_cmd "$cmd" "$hint"; then
        return ${LIBSHELL_CMD_NOT_FOUND}
    fi
    return 0
}

__libshell_check_optional_deps() {
    # Check optional dependencies and print warnings
    # Called during library initialization
    local missing_optional=""
    
    # tmux - for run_in_tmux
    if ! command -v tmux >/dev/null 2>&1; then
        missing_optional="$missing_optional tmux"
    fi
    
    # xxd - for run_in_tmux random suffix
    if ! command -v xxd >/dev/null 2>&1; then
        missing_optional="$missing_optional xxd"
    fi
    
    if [ -n "$missing_optional" ] && [ "${LIBSHELL_QUIET:-0}" != "1" ]; then
        echo -e "\033[33m[libshell] Optional dependencies not found:$missing_optional\033[0m" >&2
        echo -e "\033[33m[libshell] Some features may be unavailable. Set LIBSHELL_QUIET=1 to suppress this warning.\033[0m" >&2
    fi
}

# =============================================================================
# Logging Functions (POSIX compatible)
# =============================================================================
log_err() {
    local default_exit_code=$?
    if [ "$#" -lt 1 ]; then
        log_err "Usage: log_err <ERR_MSG> [EXIT_CODE]" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local err_msg=$1
    local exit_code=${2:-${default_exit_code}}
    echo -e "$err_msg" >&2
    return $exit_code
}

log_warn() {
    if [ "$#" -lt 1 ]; then
        log_err "Usage: log_warn <WARN_MSG>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    echo -e "\033[33m[warning] $1\033[0m" >&2
}

log_info() {
    if [ "$#" -lt 1 ]; then
        log_err "Usage: log_info <INFO_MSG>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    echo -e "\033[34m[info] $1\033[0m" >&2
}

# =============================================================================
# Path Utility Functions (POSIX compatible)
# =============================================================================
real_dir() {
    if [ "$#" -ne 1 ]; then
        log_err "Usage: real_dir <DIR_PATH>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local path
    # macOS realpath doesn't have -e option, use different approach
    if [ -e "$1" ]; then
        path=$(cd "$1" 2>/dev/null && pwd -P) || {
            log_err "'$1' is not accessible" ${LIBSHELL_FILE_TYPE_ERR}
            return $?
        }
    else
        log_err "'$1' does not exist" ${LIBSHELL_FILE_TYPE_ERR}
        return $?
    fi
    if [ ! -d "$path" ]; then
        log_err "'$1' is not a directory" ${LIBSHELL_FILE_TYPE_ERR}
        return $?
    fi
    echo "$path"
    return ${LIBSHELL_DEFAULT_OK}
}

real_file() {
    if [ "$#" -ne 1 ]; then
        log_err "Usage: real_file <FILE_PATH>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    if [ ! -e "$1" ]; then
        log_err "'$1' does not exist" ${LIBSHELL_FILE_TYPE_ERR}
        return $?
    fi
    local dir_path=$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)
    local path="${dir_path}/$(basename "$1")"
    if [ ! -f "$path" ]; then
        log_err "'$1' is not a file" ${LIBSHELL_FILE_TYPE_ERR}
        return $?
    fi
    echo "$path"
    return ${LIBSHELL_DEFAULT_OK}
}

# =============================================================================
# Network Utility Functions (POSIX compatible)
# =============================================================================
port_avail() {
    if [ "$#" -ne 2 ]; then
        log_err "Usage: port_avail <HOST> <PORT>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    
    __libshell_require_cmd nc || return $?
    
    local remote_host=$1
    local remote_port=$2
    nc -z -w1 $remote_host $remote_port &> /dev/null
}

# =============================================================================
# Link Utility Functions (POSIX compatible)
# =============================================================================
create_link() {
    # create_link to target path, if it points to the same path
    # just return it, otherwise, raise an error.
    if [ "$#" -ne 2 ]; then
        log_err "Usage: create_link <SOURCE> <TARGET>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local source=$1
    local target=$2
    if [ -L "$target" ]; then
        local link_target=$(readlink "$target")
        if [ "$link_target" = "$source" ]; then
            return ${LIBSHELL_DEFAULT_OK}
        else
            log_err "Link $target already exists and points to $link_target" ${LIBSHELL_LINK_ERR}
            return $?
        fi
    fi
    ln -s "$source" "$target"
    return ${LIBSHELL_DEFAULT_OK}
}

# =============================================================================
# Permission Utility Functions (POSIX compatible)
# =============================================================================
permission2int() {
    if [ "$#" -ne 1 ]; then
        log_err "Usage: permission2int <PERMISSION_STRING>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local permission=$1
    local result=0
    case "$permission" in
        *r*) result=$((result + 4)) ;;
    esac
    case "$permission" in
        *w*) result=$((result + 2)) ;;
    esac
    case "$permission" in
        *x*) result=$((result + 1)) ;;
    esac
    echo $result
}

int2permission() {
    if [ "$#" -ne 1 ]; then
        log_err "Usage: int2permission <PERMISSION_INT>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local permission_int=$1
    local result=""
    if [ $permission_int -ge 4 ]; then
        result="${result}r"
        permission_int=$((permission_int - 4))
    fi
    if [ $permission_int -ge 2 ]; then
        result="${result}w"
        permission_int=$((permission_int - 2))
    fi
    if [ $permission_int -ge 1 ]; then
        result="${result}x"
    fi
    echo "$result"
}

# =============================================================================
# User Utility Functions (POSIX compatible)
# =============================================================================
is_user_exist() {
    if [ "$#" -ne 1 ]; then
        log_err "Usage: is_user_exist <USER>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    if ! id -u "$1" > /dev/null 2>&1; then
        echo -e "\\033[31mUser $1 does not exist\\033[0m"
        return ${LIBSHELL_DEFAULT_ERR}
    fi
}

setup_editor() {
    if [ "$TERM_PROGRAM" = "vscode" ]; then
        local vscode_editors="code cursor trae"
        for editor in $vscode_editors; do
            if command -v "$editor" > /dev/null 2>&1; then
                export EDITOR="$editor --wait"
                if [ "$LIBSHELL_QUIET" != "1" ]; then
                    echo -e "[libshell] EDITOR set to \033[32m$EDITOR\033[0m"
                fi
                return ${LIBSHELL_DEFAULT_OK}
            fi
        done
        if [ "$LIBSHELL_QUIET" != "1" ]; then
            echo -e "[libshell] \033[33mNo VS Code-style editor found (code, cursor, trae).\033[0m"
            echo -e "[libshell] To install VS Code editor, visit: https://code.visualstudio.com/"
            echo -e "[libshell] To install Cursor editor, visit: https://cursor.com/"
            echo -e "[libshell] To install Trae editor, visit: https://trae.ai/"
        fi
    else
        local terminal_editors="nano nvim vim vi"
        for editor in $terminal_editors; do
            if command -v "$editor" > /dev/null 2>&1; then
                export EDITOR="$editor"
                if [ "$LIBSHELL_QUIET" != "1" ]; then
                    echo -e "[libshell] EDITOR set to \033[32m$EDITOR\033[0m"
                fi
                return ${LIBSHELL_DEFAULT_OK}
            fi
        done
        if [ "$LIBSHELL_QUIET" != "1" ]; then
            echo -e "[libshell] \033[31mNo terminal editor found (tried: nano, nvim, vim, vi).\033[0m"
            echo -e "[libshell] To install nano: \033[36msudo apt install nano\033[0m"
            echo -e "[libshell] To install neovim: \033[36msudo apt install neovim\033[0m"
        fi
    fi
    return ${LIBSHELL_DEFAULT_ERR}
}

# =============================================================================
# Slurm Utility Functions (POSIX compatible)
# =============================================================================
sbat() {
    # a parsable slurm sbatch command
    if [ "$#" -lt 1 ]; then
        log_err "Usage: sbat [ARGS...] <SCRIPT> [ARGS...]" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    
    # check if sbatch available
    if ! command -v sbatch >/dev/null; then
        log_err "Slurm sbatch not detected!" ${LIBSHELL_CMD_NOT_FOUND}
        return $?
    fi

    local job_id
    job_id=$(sbatch --parsable "$@")
    if [ $? -ne 0 ]; then
        log_err "Submit batch job failed" ${LIBSHELL_DEFAULT_ERR}
        return $?
    fi
    
    echo -e "Submitted batch job \033[32m$job_id\033[0m"
    export PREV_SLURM_JOB_ID=$job_id
}

sque() {
    squeue -u ${USER} "$@"
}

# =============================================================================
# Tmux Wrapper Functions (POSIX compatible core logic)
# =============================================================================
__run_in_tmux_wrapper() {
    # Internal wrapper function to handle tmux session creation
    # Usage: __run_in_tmux_wrapper <cmd> [args...]
    local cmd=$1
    shift
    
    # If already in tmux, run the command directly
    if [ -n "$TMUX" ]; then
        command $cmd "$@"
    else
        # Generate random suffix, fallback to $RANDOM or timestamp if xxd unavailable
        local random_suffix
        if command -v xxd >/dev/null 2>&1; then
            random_suffix=$(head -c 4 /dev/urandom | xxd -p)
        elif [ -n "$RANDOM" ]; then
            random_suffix=$RANDOM
        else
            random_suffix=$(date +%s)
        fi
        tmux new -s "${cmd}_${random_suffix}" $cmd "$@"
    fi
}

# =============================================================================
# Initialization
# =============================================================================
# Check optional dependencies (only show warning once)
if [ "${LIBSHELL_DEPS_CHECKED:-0}" != "1" ]; then
    __libshell_check_optional_deps
    export LIBSHELL_DEPS_CHECKED=1
fi

# =============================================================================
# Auto-update Functions
# =============================================================================

# GitHub repository for updates
LIBSHELL_GITHUB_REPO="${LIBSHELL_GITHUB_REPO:-GCS-ZHN/libshell}"

# Internal helper: download content from URL
# Usage: __libshell_download URL [OUTPUT_FILE]
# If OUTPUT_FILE is omitted, outputs to stdout
__libshell_download() {
    local url="$1"
    local output="$2"
    
    if command -v curl >/dev/null 2>&1; then
        if [ -n "$output" ]; then
            curl -fsSL "$url" -o "$output" 2>/dev/null
        else
            curl -fsSL "$url" 2>/dev/null
        fi
    elif command -v wget >/dev/null 2>&1; then
        if [ -n "$output" ]; then
            wget -q "$url" -O "$output" 2>/dev/null
        else
            wget -qO- "$url" 2>/dev/null
        fi
    else
        return 1
    fi
}

# Internal helper: parse JSON value (simple, no jq dependency)
# Usage: __libshell_json_value JSON KEY
__libshell_json_value() {
    local json="$1"
    local key="$2"
    echo "$json" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | \
        sed 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
}

# Internal function to check if updates are available
# Returns: 0 if updates available, 1 if up-to-date, 2 if error
# Sets: __LIBSHELL_UPDATE_AVAILABLE=1 if updates found
# Sets: __LIBSHELL_LATEST_VERSION to the latest version tag
__libshell_check_update() {
    __LIBSHELL_UPDATE_AVAILABLE=0
    __LIBSHELL_LATEST_VERSION=""
    
    # Check if curl or wget is available
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        return 2
    fi
    
    # Fetch latest release info from GitHub API
    local api_url="https://api.github.com/repos/${LIBSHELL_GITHUB_REPO}/releases/latest"
    local response
    response=$(__libshell_download "$api_url")
    
    if [ -z "$response" ]; then
        return 2
    fi
    
    # Parse tag_name from response
    local latest_tag
    latest_tag=$(__libshell_json_value "$response" "tag_name")
    
    if [ -z "$latest_tag" ]; then
        return 2
    fi
    
    __LIBSHELL_LATEST_VERSION="$latest_tag"
    
    # Compare versions (strip 'v' prefix if present)
    local current_ver="${LIBSHELL_VERSION#v}"
    local latest_ver="${latest_tag#v}"
    
    if [ "$current_ver" != "$latest_ver" ]; then
        __LIBSHELL_UPDATE_AVAILABLE=1
        return 0
    fi
    
    return 1
}

# Update libshell from GitHub Release
# Usage: update_libshell
# Returns: 0 on success, 1 if already up-to-date, 2 on error
update_libshell() {
    # Check if curl or wget is available
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        log_err "[libshell] Neither curl nor wget found, cannot update" ${LIBSHELL_CMD_NOT_FOUND}
        return 2
    fi
    
    # Check if LIBSHELL_DIR is set
    if [ -z "$LIBSHELL_DIR" ]; then
        log_err "[libshell] LIBSHELL_DIR not set, cannot update" ${LIBSHELL_DEFAULT_ERR}
        return 2
    fi
    
    # Check for updates first
    __libshell_check_update
    local check_result=$?
    
    if [ $check_result -eq 2 ]; then
        log_err "[libshell] Failed to check for updates" ${LIBSHELL_DEFAULT_ERR}
        return 2
    fi
    
    if [ $check_result -eq 1 ]; then
        if [ "$LIBSHELL_QUIET" != "1" ]; then
            echo -e "\033[32m[libshell] Already up-to-date (v${LIBSHELL_VERSION})\033[0m"
        fi
        return 1
    fi
    
    local version="${__LIBSHELL_LATEST_VERSION}"
    if [ -z "$version" ]; then
        log_err "[libshell] Could not determine latest version" ${LIBSHELL_DEFAULT_ERR}
        return 2
    fi
    
    if [ "$LIBSHELL_QUIET" != "1" ]; then
        echo -e "\033[33m[libshell] Updating from v${LIBSHELL_VERSION} to ${version}...\033[0m"
    fi
    
    # Create temporary directory
    local tmp_dir
    tmp_dir=$(mktemp -d 2>/dev/null || mktemp -d -t 'libshell')
    local tmp_file="${tmp_dir}/libshell.tar.gz"
    
    # Download release tarball
    local download_url="https://github.com/${LIBSHELL_GITHUB_REPO}/releases/download/${version}/libshell-${version}.tar.gz"
    
    if ! __libshell_download "$download_url" "$tmp_file"; then
        # Fallback: try source tarball from GitHub
        download_url="https://github.com/${LIBSHELL_GITHUB_REPO}/archive/refs/tags/${version}.tar.gz"
        if ! __libshell_download "$download_url" "$tmp_file"; then
            rm -rf "$tmp_dir"
            log_err "[libshell] Failed to download release ${version}" ${LIBSHELL_FILE_IO_ERR}
            return 2
        fi
    fi
    
    # Extract to temporary location
    local extract_dir="${tmp_dir}/extract"
    mkdir -p "$extract_dir"
    
    if ! tar -xzf "$tmp_file" -C "$extract_dir" 2>/dev/null; then
        rm -rf "$tmp_dir"
        log_err "[libshell] Failed to extract release" ${LIBSHELL_FILE_IO_ERR}
        return 2
    fi
    
    # Find extracted directory (handle both libshell-vX.X.X and libshell-X.X.X patterns)
    local source_dir
    source_dir=$(find "$extract_dir" -maxdepth 1 -type d -name "libshell*" | head -1)
    
    if [ -z "$source_dir" ]; then
        # Files may be extracted directly without subdirectory
        source_dir="$extract_dir"
    fi
    
    # Copy files to LIBSHELL_DIR (preserve existing config)
    local files_to_copy="common.sh lib.bash lib.zsh lib.ps1"
    local copy_failed=0
    
    for file in $files_to_copy; do
        if [ -f "${source_dir}/${file}" ]; then
            if ! cp "${source_dir}/${file}" "${LIBSHELL_DIR}/${file}"; then
                copy_failed=1
                break
            fi
        fi
    done
    
    # Cleanup
    rm -rf "$tmp_dir"
    
    if [ $copy_failed -eq 1 ]; then
        log_err "[libshell] Failed to copy files to ${LIBSHELL_DIR}" ${LIBSHELL_FILE_IO_ERR}
        return 2
    fi
    
    if [ "$LIBSHELL_QUIET" != "1" ]; then
        echo -e "\033[32m[libshell] Updated successfully to ${version}\033[0m"
        echo -e "\033[33m[libshell] Please restart your shell or re-source the library to apply changes.\033[0m"
    fi
    
    return 0
}

# Auto-update check on load (if enabled)
if [ "${LIBSHELL_UPDATE_CHECKED:-0}" != "1" ]; then
    export LIBSHELL_UPDATE_CHECKED=1
    
    if [ "$LIBSHELL_AUTO_UPDATE" = "1" ]; then
        # Auto-update enabled: check and update silently
        if __libshell_check_update && [ "$__LIBSHELL_UPDATE_AVAILABLE" = "1" ]; then
            update_libshell
        fi
    else
        # Auto-update disabled: just notify if updates available
        if __libshell_check_update && [ "$__LIBSHELL_UPDATE_AVAILABLE" = "1" ]; then
            if [ "$LIBSHELL_QUIET" != "1" ]; then
                echo -e "\033[33m[libshell] Updates available. Run 'update_libshell' to update.\033[0m"
            fi
        fi
    fi
fi
