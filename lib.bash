# a shell module for general operations
# if LIBSHELL_VERSION not defined
if [ -z "$LIBSHELL_VERSION" ]; then

export LIBSHELL_VERSION=1.0

LIBSHELL_DEFAULT_OK=0
LIBSHELL_DEFAULT_ERR=1
LIBSHELL_ARG_ERR=2
LIBSHELL_SHELL_NOT_SUPPORTED=3
LIBSHELL_CMD_NOT_FOUND=4
LIBSHELL_FILE_EXISTED=5
LIBSHELL_FILE_TYPE_ERR=6
LIBSHELL_FILE_IO_ERR=7

SHELL_NAME=$(basename $(ps -p $$ -o comm=))

if [ ${SHELL_NAME} != 'bash' ]; then
    echo "Current shell '${SHELL_NAME}' is not supported!"
    return $LIBSHELL_SHELL_NOT_SUPPORTED
fi


function is_source() {
    [ ${BASH_SOURCE[0]} != ${0} ]
    return $?
}
export -f is_source


function log_err() {
    local default_exit_code=$?
    if [ "$#" -lt 1 ]; then
        log_err "Usage: log_err <ERR_MSG> [EXIT_CODE]" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    err_msg=$1
    exit_code=${2:-${default_exit_code}}
    echo -e "$err_msg" >&2
    return $exit_code
}
export -f log_err


function require_arg() {
    if [ "$#" -ne 1 ]; then
        log_err "Usage: require_arg <ARG_NAME>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    if [ -z ${!1} ]; then
        return ${LIBSHELL_ARG_ERR}
    fi
    return ${LIBSHELL_DEFAULT_OK}
}
export -f require_arg


function real_dir() {
    if [ "$#" -ne 1 ]; then
        log_err "Usage: real_dir <DIR_PATH>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local path=$(realpath -e $1) || return $?
    if [ ! -d "$path" ];then
        log_err "'$1' is not a directory" ${LIBSHELL_FILE_TYPE_ERR}
        return $?
    fi
    echo $path
    return ${LIBSHELL_DEFAULT_OK}
}
export -f real_dir

function real_file() {
    if [ "$#" -ne 1 ]; then
        log_err "Usage: real_file <FILE_PATH>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local path=$(realpath -e $1) || return $?
    if [ ! -f "$path" ];then
        log_err "'$1' is not a file" ${LIBSHELL_FILE_TYPE_ERR}
        return $?
    fi
    echo $path
    return 0
}
export -f real_file


function conda_mv() {
    if [ "$#" -ne 2 ]; then
        log_err "Usage: conda_mv <OLD_CONDA_NAME> <NEW_CONDA_NAME>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local old_conda_home=$(real_dir $1)
    local new_conda_home=$(realpath $2)
    if [ -e $new_conda_home ]; then
        log_err "target path should not be existed!" ${LIBSHELL_FILE_EXISTED}
        return $?
    fi
    rsync -av $old_conda_home/ $new_conda_home/
    if [ $? -ne 0 ]; then
        log_err "Copy conda home failed!" ${LIBSHELL_FILE_IO_ERR}
        return $?
    fi
    find $new_conda_home -type f \
                         -exec grep -Iq . {} \; -and \
                         -exec sed -i "s|$old_conda_home|$new_conda_home|g" {} \; -and \
                         -print
    if [ $? -ne 0 ]; then
        log_err "Update conda prefix failed!"
        return $?
    fi
    rm -rf $old_conda_home
}
export -f conda_mv


function prepend_path() {
    if [ "$#" -lt 2 ]; then
        log_err "Usage: prepend_path <VAR_NAME> <PATH> [SEPARATOR]" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    
    local var_name=$1
    local new_path=$2
    local separator=${3:-:}

    if [ ${var_name} == 'var_name' ]; then
        log_err "'var_name' is reserved keyword, not allowed as variable name" ${LIBSHELL_ARG_ERR}
        return $?
    elif [ ${var_name} == 'new_path' ]; then
        log_err "'new_path' is reserved keyword, not allowed as variable name" ${LIBSHELL_ARG_ERR}
        return $?
    elif [ ${var_name} == 'separator' ]; then
        log_err "'separator' is reserved keyword, not allowed as variable name" ${LIBSHELL_ARG_ERR}
        return $?
    fi

    local current_value=${!var_name}
    if [ -z $current_value ]; then
        export $var_name=$new_path
    elif perl -e "exit (grep{\$_ eq '$new_path'} (split /$separator/, '$current_value'))"; then
        export $var_name=$new_path$separator$current_value
    else
        export $var_name=$current_value
    fi
    return ${LIBSHELL_DEFAULT_OK}
}
export -f prepend_path


function port_avail() {
    if [ "$#" -ne 2 ]; then
        log_err "Usage: port_avail <HOST> <PORT>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local remote_host=$1
    local remote_port=$2
    nc -z -w1 $remote_host $remote_port &> /dev/null
}
export -f port_avail


function create_link() {
    # create_link to target path, if it point the same path
    # just return it, otherwise, raise an error.
    if [ "$#" -ne 2 ]; then
        log_err "Usage: create_link <SOURCE> <TARGET>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local source=$1
    local target=$2
    if [ -L $target ]; then
        local link_target=$(readlink $target)
        if [ "$link_target" == "$source" ]; then
            return ${LIBSHELL_DEFAULT_OK}
        else
            log_err "Link $target already exists and points to $link_target" ${LIBSHELL_LINK_ERR}
            return $?
        fi
    fi
    ln -s $source $target
    return ${LIBSHELL_DEFAULT_OK}
}
export -f create_link


function sbat() {
    # a parsable slurm sbatch command
    if [ "$#" -lt 1 ]; then
        log_err "Usage: sbat [ARGS...] <SCRIPT> [ARGS...]" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    
    # check if sbatch available
    if ! command -v sbatch >/dev/null; then
        log_err "Slurm sbatch not detected!" ${LIBSHELL_CMD_NOT_FOUND}
    fi

    job_id=$(sbatch --parsable $@)
    if [ $? -ne 0 ]; then
        log_err "Submit batch job failed" ${LIBSHELL_DEFAULT_ERR}
        return $?
    fi
    
    echo -e "Submitted batch job \033[32m$job_id\033[0m"
    export PREV_SLURM_JOB_ID=$job_id
}
export -f sbat


function sque() {
    squeue -u ${USER} $@
}
export -f sque


function permission2int() {
    if [ "$#" -ne 1 ]; then
        log_err "Usage: permission2int <PERMISSION_STRING>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local permission=$1
    local result=0
    if [[ $permission == *"r"* ]]; then
        result=$((result + 4))
    fi
    if [[ $permission == *"w"* ]]; then
        result=$((result + 2))
    fi
    if [[ $permission == *"x"* ]]; then
        result=$((result + 1))
    fi
    echo $result
}

export -f permission2int


function int2permission() {
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
    echo $result
}

export -f int2permission


function grant_access() {
    if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
        log_err "Usage: grant_access <TARGET> <USER> [PERMISSION_MASK]" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local target=$1
    local user=$2
    local permission_mask=${3:-7}
    owner_access=$(stat --format=%A $target | cut -c 2-4)
    owner_access=$(permission2int $owner_access)
    permission=$(($owner_access & $permission_mask))
    permission=$(int2permission $permission)
    setfacl -m u:$user:$permission $target
    echo "Granting access $permission to $user for $target"
}

export -f grant_access


function get_access() {
    if [ "$#" -ne 2 ]; then
        log_err "Usage: get_access <TARGET> <USER>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local target=$1
    local user=$2
    owner_group=$(id -g)
    user_group=$(id -g $user)
    access=$(getfacl  -c -p $target | grep "user:$user" | cut -d: -f3)
    if [ -z $access ]; then
        access=$(getfacl -c -p $target | grep "group:$user_group" | cut -d: -f3)
    fi
    if [ -z $access ]; then
        if [ $owner_group -eq $user_group ]; then
            access=$(getfacl -c -p $target | grep "group::" | cut -d: -f3)
        else
            access=$(getfacl -c -p $target | grep "other::" | cut -d: -f3)
        fi
    fi
    echo $access
}

export -f get_access


function check_executable() {
    if [ "$#" -ne 2 ]; then
        log_err "Usage: check_executable <TARGET> <USER>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local target=$1
    local user=$2
    access=$(get_access $target $user)
    if [ $(echo $access | grep -c "x") -eq 0 ]; then
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
    local target=$(dirname $(realpath $1))
    local user=$2
    while [ "$target" != "/" ]; do
        check_executable $target $user
        target=$(dirname $target)
    done
}

export -f loop_check_parent_executable


function is_user_exist() {
    if [ "$#" -ne 1 ]; then
        log_err "Usage: is_user_exist <USER>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
 
    if [ $(id -u $1 > /dev/null 2>&1; echo $?) -ne 0 ]; then
        echo -e "\\033[31mUser $1 does not exist\\033[0m"
        return ${LIBSHELL_DEFAULT_ERR}
    fi
}

export -f is_user_exist


function copy_access() {
    if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
        log_err "Usage: copy_access <TARGET> <USER> [PERMISSION_MASK]" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local target_dir=$1
    local user=$2
    local permission_mask=${3:-5}

    if [ ! -d $target_dir ]; then
        echo -e "\\033[31mDirectory $target_dir does not exist\\033[0m"
        return ${LIBSHELL_FILE_TYPE_ERR}
    fi

    # Check if the user exists
    is_user_exist $user || return $?

    # Check if the user has execute permission on all parent directories
    loop_check_parent_executable $target_dir $user || return $?

    # Grant access to all files and directories in the target directory
    find $target_dir -exec bash -c 'grant_access "$0" "$1" "$2"' {} $user $permission_mask \;
}

export -f copy_access


if is_source; then
    log_err "LibShell is sourced" ${LIBSHELL_DEFAULT_OK}
else
    log_err 'LibShell is library, you should source it by `. lib.bash` or `source lib.bash`'
fi

fi
