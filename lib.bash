# lib.bash - Bash-specific shell module for general operations
# Requires: bash 4.0+

# Prevent multiple sourcing in the same shell session
# Note: Do NOT export this variable - subshells should reload the library
if [ -n "$LIBSHELL_BASH_LOADED" ]; then
    return 0
fi

# Get the directory of this script
LIBSHELL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check shell type
SHELL_NAME=$(basename $(ps -p $$ -o comm=))
if [ "${SHELL_NAME}" != 'bash' ]; then
    echo "Current shell '${SHELL_NAME}' is not supported by lib.bash!" >&2
    return 3  # LIBSHELL_SHELL_NOT_SUPPORTED
fi

# Source common definitions
source "${LIBSHELL_DIR}/common.sh" || {
    echo "Failed to load common.sh" >&2
    return 1
}

LIBSHELL_BASH_LOADED=1

# =============================================================================
# Bash-specific Functions
# =============================================================================

function is_source() {
    [ "${BASH_SOURCE[0]}" != "${0}" ]
    return $?
}
export -f is_source


function require_arg() {
    # Check if a variable is defined (bash-specific: uses ${!var} indirect expansion)
    if [ "$#" -ne 1 ]; then
        log_err "Usage: require_arg <ARG_NAME>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    if [ -z "${!1}" ]; then
        return ${LIBSHELL_ARG_ERR}
    fi
    return ${LIBSHELL_DEFAULT_OK}
}
export -f require_arg


function prepend_path() {
    # Prepend a path to a variable if not already present (bash-specific: uses ${!var})
    if [ "$#" -lt 2 ]; then
        log_err "Usage: prepend_path <VAR_NAME> <PATH> [SEPARATOR]" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    
    __libshell_require_cmd perl || return $?
    
    local var_name=$1
    local new_path=$2
    local separator=${3:-:}

    if [ "${var_name}" == 'var_name' ]; then
        log_err "'var_name' is reserved keyword, not allowed as variable name" ${LIBSHELL_ARG_ERR}
        return $?
    elif [ "${var_name}" == 'new_path' ]; then
        log_err "'new_path' is reserved keyword, not allowed as variable name" ${LIBSHELL_ARG_ERR}
        return $?
    elif [ "${var_name}" == 'separator' ]; then
        log_err "'separator' is reserved keyword, not allowed as variable name" ${LIBSHELL_ARG_ERR}
        return $?
    fi

    local current_value=${!var_name}
    if [ -z "$current_value" ]; then
        export $var_name=$new_path
    elif perl -e "exit (grep{\$_ eq '$new_path'} (split /$separator/, '$current_value'))"; then
        export $var_name=$new_path$separator$current_value
    else
        export $var_name=$current_value
    fi
    return ${LIBSHELL_DEFAULT_OK}
}
export -f prepend_path


function conda_mv() {
    # Move conda environment to a new location (bash-specific: uses bash -c in find)
    if [ "$#" -ne 2 ]; then
        log_err "Usage: conda_mv <OLD_CONDA_NAME> <NEW_CONDA_NAME>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    
    __libshell_require_cmd rsync || return $?
    
    local old_conda_home=$(real_dir "$1")
    local new_conda_home=$(realpath "$2" 2>/dev/null || echo "$2")
    if [ -e "$new_conda_home" ]; then
        log_err "target path should not be existed!" ${LIBSHELL_FILE_EXISTED}
        return $?
    fi
    rsync -av "$old_conda_home/" "$new_conda_home/"
    if [ $? -ne 0 ]; then
        log_err "Copy conda home failed!" ${LIBSHELL_FILE_IO_ERR}
        return $?
    fi
    
    # sed -i syntax differs between Linux and macOS
    local sed_inplace
    if [ "$LIBSHELL_OS" = "macos" ]; then
        sed_inplace="sed -i ''"
    else
        sed_inplace="sed -i"
    fi
    
    find "$new_conda_home" -type f \
                         -exec grep -Iq . {} \; -and \
                         -exec $sed_inplace "s|$old_conda_home|$new_conda_home|g" {} \; -and \
                         -print
    if [ $? -ne 0 ]; then
        log_err "Update conda prefix failed!"
        return $?
    fi
    rm -rf "$old_conda_home"
}
export -f conda_mv


# =============================================================================
# ACL Functions (require setfacl/getfacl)
# =============================================================================

function grant_access() {
    if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
        log_err "Usage: grant_access <TARGET> <USER> [PERMISSION_MASK]" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    
    __libshell_require_cmd setfacl || return $?
    
    local target=$1
    local user=$2
    local permission_mask=${3:-7}
    local owner_access
    
    # Get owner permissions (Linux vs macOS stat)
    if [ "$LIBSHELL_OS" = "linux" ]; then
        owner_access=$(stat --format=%A "$target" 2>/dev/null | cut -c 2-4)
    else
        owner_access=$(stat -f "%Sp" "$target" 2>/dev/null | cut -c 2-4)
    fi
    
    owner_access=$(permission2int "$owner_access")
    local permission=$(($owner_access & $permission_mask))
    permission=$(int2permission $permission)
    setfacl -m u:$user:$permission "$target"
    echo "Granting access $permission to $user for $target"
}
export -f grant_access


function get_access() {
    if [ "$#" -ne 2 ]; then
        log_err "Usage: get_access <TARGET> <USER>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    
    __libshell_require_cmd getfacl || return $?
    
    local target=$1
    local user=$2
    local owner_group=$(id -g)
    local user_group=$(id -g "$user")
    local access=$(getfacl -c -p "$target" 2>/dev/null | grep "user:$user" | cut -d: -f3)
    if [ -z "$access" ]; then
        access=$(getfacl -c -p "$target" 2>/dev/null | grep "group:$user_group" | cut -d: -f3)
    fi
    if [ -z "$access" ]; then
        if [ "$owner_group" -eq "$user_group" ]; then
            access=$(getfacl -c -p "$target" 2>/dev/null | grep "group::" | cut -d: -f3)
        else
            access=$(getfacl -c -p "$target" 2>/dev/null | grep "other::" | cut -d: -f3)
        fi
    fi
    echo "$access"
}
export -f get_access


function check_executable() {
    if [ "$#" -ne 2 ]; then
        log_err "Usage: check_executable <TARGET> <USER>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local target=$1
    local user=$2
    local access=$(get_access "$target" "$user")
    if [ $(echo "$access" | grep -c "x") -eq 0 ]; then
        echo -e "User $user \\033[31mdoesn't have execute permission\\033[0m on $target."
        echo -e "Please grant it to $user on $target by: "
        echo -e ""
        echo -e "    \\033[32msetfacl -m u:$user:x $target\\033[0m"
        echo -e ""
        echo -e "\\033[31mBut you should be sure not expose other files to $user.\\033[0m"
        return ${LIBSHELL_DEFAULT_ERR}
    fi
}
export -f check_executable


function loop_check_parent_executable() {
    if [ "$#" -ne 2 ]; then
        log_err "Usage: loop_check_parent_executable <TARGET> <USER>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local target=$(dirname $(realpath "$1"))
    local user=$2
    while [ "$target" != "/" ]; do
        check_executable "$target" "$user"
        target=$(dirname "$target")
    done
}
export -f loop_check_parent_executable


function copy_access() {
    if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
        log_err "Usage: copy_access <TARGET> <USER> [PERMISSION_MASK]" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local target_dir=$1
    local user=$2
    local permission_mask=${3:-5}

    if [ ! -d "$target_dir" ]; then
        echo -e "\\033[31mDirectory $target_dir does not exist\\033[0m"
        return ${LIBSHELL_FILE_TYPE_ERR}
    fi

    # Check if the user exists
    is_user_exist "$user" || return $?

    # Check if the user has execute permission on all parent directories
    loop_check_parent_executable "$target_dir" "$user" || return $?

    # Grant access to all files and directories in the target directory
    find "$target_dir" -exec bash -c 'grant_access "$0" "$1" "$2"' {} "$user" "$permission_mask" \;
}
export -f copy_access


# =============================================================================
# Tmux Functions (Bash-specific alias handling)
# =============================================================================

function run_in_tmux() {
    # Create an alias for a command to run it in a tmux session
    # Usage: run_in_tmux <cmd>
    # If already in tmux, the command runs directly without creating nested session
    # Also creates <cmd>.raw alias to invoke the original command directly
    if [ "$#" -ne 1 ]; then
        log_err "Usage: run_in_tmux <cmd>" ${LIBSHELL_ARG_ERR}
        return $?
    fi

    # Check if tmux is available
    local hint=$(__libshell_get_install_hint tmux)
    if ! __libshell_check_cmd tmux "$hint"; then
        log_err "tmux is not installed, skipping alias creation" ${LIBSHELL_CMD_NOT_FOUND}
        return $?
    fi

    local cmd=$1
    
    # Check if the command exists
    if ! command -v "$cmd" >/dev/null; then
        log_err "Command '$cmd' not found" ${LIBSHELL_CMD_NOT_FOUND}
        return $?
    fi

    # Create alias for tmux wrapper
    alias $cmd="__run_in_tmux_wrapper $cmd"
    # Create alias for raw command (useful for --help, --version, etc.)
    alias $cmd.raw="command $cmd"
    
    echo "Created aliases:"
    echo "  $cmd     -> auto tmux wrapper (detects nested tmux)"
    echo "  $cmd.raw -> original command (for --help, --version, etc.)"
    return ${LIBSHELL_DEFAULT_OK}
}
export -f run_in_tmux


# =============================================================================
# Export common functions for subshells (bash-specific)
# =============================================================================
export -f log_err
export -f log_warn
export -f log_info
export -f real_dir
export -f real_file
export -f port_avail
export -f create_link
export -f permission2int
export -f int2permission
export -f is_user_exist
export -f sbat
export -f sque
export -f __run_in_tmux_wrapper
export -f __libshell_check_cmd
export -f __libshell_get_install_hint
export -f __libshell_require_cmd


# =============================================================================
# Initialization Message
# =============================================================================
if is_source; then
    log_err "LibShell (bash) is sourced" ${LIBSHELL_DEFAULT_OK}
else
    log_err 'LibShell is library, you should source it by `. lib.bash` or `source lib.bash`'
fi
