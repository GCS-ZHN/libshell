# a shell module for general operations

function required_args() {
    if [ -z "$1" ]; then
        return 1
    fi
    return 0
}

function exit_err() {
    echo $1 >&2
    exit 1
}

function real_dir() {
    path=$(realpath -e $1) || return $?
    if [ ! -d "$path" ];then
        exit_err "'$1' is not a directory"
    fi
    echo $path
    return 0
}

function real_file() {
    path=$(realpath -e $1) || return $?
    if [ ! -f "$path" ];then
        exit_err "'$1' is not a file"
    fi
    echo $path
    return 0
}
