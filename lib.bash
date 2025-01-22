# a shell module for general operations

SHELL_NAME=$(basename $(ps -p $$ -o comm=))

if [ ${SHELL_NAME} != 'bash' ]; then
    echo "Current shell '${SHELL_NAME}' is not supported!"
    return 1
fi

function is_source() {
    [ ${BASH_SOURCE[0]} != ${0} ]
    return $?
}
export -f is_source

function exit_err() {
    echo $1 >&2
    return 1
}
export -f exit_err

function required_args() {
    if [ "$#" -lt 1 ]; then
        exit_err "Usage: required_args <ARG_NAME>"
        return $?
    fi
    local arg_name=$1
    echo ${arg_name}
    if [ -z ${!arg_name} ]; then
        return 1
    fi
    return 0
}
export -f required_args

function real_dir() {
    local path=$(realpath -e $1) || return $?
    if [ ! -d "$path" ];then
        exit_err "'$1' is not a directory"
        return $?
    fi
    echo $path
    return 0
}
export -f real_dir

function real_file() {
    local path=$(realpath -e $1) || return $?
    if [ ! -f "$path" ];then
        exit_err "'$1' is not a file"
        return $?
    fi
    echo $path
    return 0
}
export -f real_file


function conda_mv() {
    local old_conda_home=$(real_dir $1)
    local new_conda_home=$(realpath $2)
    if [ -e $new_conda_home ]; then
        exit_err "target path should not be existed!"
        return $?
    fi
    rsync -av $old_conda_home/ $new_conda_home/
    if [ $? -ne 0 ]; then
        exit_err "Copy conda home failed!"
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
        exit_err "Usage: prepend_path VAR_NAME PATH [SEPARATOR]"
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
    return 0
}
export -f prepend_path
