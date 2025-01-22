# a shell module for general operations

function required_args() {
    if [ -z "$1" ]; then
        return 1
    fi
    return 0
}
export -f required_args

function exit_err() {
    echo $1 >&2
    exit 1
}
export -f exit_err

function real_dir() {
    local path=$(realpath -e $1) || return $?
    if [ ! -d "$path" ];then
        exit_err "'$1' is not a directory"
    fi
    echo $path
    return 0
}
export -f real_dir

function real_file() {
    local path=$(realpath -e $1) || return $?
    if [ ! -f "$path" ];then
        exit_err "'$1' is not a file"
    fi
    echo $path
    return 0
}
export -f real_file
