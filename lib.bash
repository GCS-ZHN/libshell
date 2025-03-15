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


if is_source; then
    log_err "LibShell is sourced" ${LIBSHELL_DEFAULT_OK}
else
    log_err 'LibShell is library, you should source it by `. lib.bash` or `source lib.bash`'
fi

fi
