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


function conda_mv() {
    local old_conda_home=$(real_dir $1)
    local new_conda_home=$(realpath $2)
    if [ -e $new_conda_home ]; then
        exit_err "target path should not be existed!"
    fi
    rsync -av $old_conda_home/ $new_conda_home/
    if [ $? -ne 0 ]; then
        exit_err "Copy conda home failed!"
    fi
    find $new_conda_home -type f \
                         -exec grep -Iq . {} \; -and \
                         -exec sed -i "s|$old_conda_home|$new_conda_home|g" {} \; -and \
                         -print
    if [ $? -ne 0 ]; then
        exit_err "Update conda prefix failed!"
    fi
    rm -rf $old_conda_home
}
export -f conda_mv
