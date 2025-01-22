# a shell module for general operations
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

function exit_err() {
    if [ "$#" -lt 1 ]; then
        exit_err "Usage: exit_err <ERR_MSG> [EXIT_CODE]" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    err_msg=$1
    exit_code=${2:-${LIBSHELL_DEFAULT_ERR}}
    echo -e "$err_msg" >&2
    return $exit_code
}
export -f exit_err

function required_args() {
    if [ "$#" -ne 1 ]; then
        exit_err "Usage: required_args <ARG_NAME>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local arg_name=$1
    if [ -z ${!arg_name} ]; then
        return ${LIBSHELL_ARG_ERR}
    fi
    return ${LIBSHELL_DEFAULT_OK}
}
export -f required_args

function real_dir() {
    if [ "$#" -ne 1 ]; then
        exit_err "Usage: real_dir <DIR_PATH>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local path=$(realpath -e $1) || return $?
    if [ ! -d "$path" ];then
        exit_err "'$1' is not a directory" ${LIBSHELL_FILE_TYPE_ERR}
        return $?
    fi
    echo $path
    return ${LIBSHELL_DEFAULT_OK}
}
export -f real_dir

function real_file() {
    if [ "$#" -ne 1 ]; then
        exit_err "Usage: real_file <FILE_PATH>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local path=$(realpath -e $1) || return $?
    if [ ! -f "$path" ];then
        exit_err "'$1' is not a file" ${LIBSHELL_FILE_TYPE_ERR}
        return $?
    fi
    echo $path
    return 0
}
export -f real_file


function conda_mv() {
    if [ "$#" -ne 2 ]; then
        exit_err "Usage: conda_mv <OLD_CONDA_NAME> <NEW_CONDA_NAME>" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local old_conda_home=$(real_dir $1)
    local new_conda_home=$(realpath $2)
    if [ -e $new_conda_home ]; then
        exit_err "target path should not be existed!" ${LIBSHELL_FILE_EXISTED}
        return $?
    fi
    rsync -av $old_conda_home/ $new_conda_home/
    if [ $? -ne 0 ]; then
        exit_err "Copy conda home failed!" ${LIBSHELL_FILE_IO_ERR}
        return $?
    fi
    find $new_conda_home -type f \
                         -exec grep -Iq . {} \; -and \
                         -exec sed -i "s|$old_conda_home|$new_conda_home|g" {} \; -and \
                         -print
    if [ $? -ne 0 ]; then
        exit_err "Update conda prefix failed!"
        return $?
    fi
    rm -rf $old_conda_home
}
export -f conda_mv


function prepend_path() {
    if [ "$#" -lt 2 ]; then
        exit_err "Usage: prepend_path <VAR_NAME> <PATH> [SEPARATOR]" ${LIBSHELL_ARG_ERR}
        return $?
    fi
    local var_name=$1
    local new_path=$2
    local separator=${3:-:}

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


if is_source; then
    exit_err "LibShell is sourced" ${LIBSHELL_DEFAULT_OK}
else
    exit_err 'LibShell is library, you should source it by `. lib.bash` or `source lib.bash`'
fi
