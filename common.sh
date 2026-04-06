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
export LIBSHELL_VERSION=1.0

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
