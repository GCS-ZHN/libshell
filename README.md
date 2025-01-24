# libshell

A shell tool collections for some common operations.
To use it, just use `. libshell/lib.bash` in your shell script.
Add it to `~/.bashrc` if you want use it globally.


## Usage examples

```bash
. lib.bash

require_arg arg_name||log_err 'arg_name not found'

```

## function description

| Function | Description | Usage |
|----------|-------------|-------|
| is_source | Check if script is called by `source` | `is_source` |
| log_err | Output error message to stderr | `log_err <ERROR_MSG> [EXIT_CODE]` |
| require_arg | Check if variable is defined | `require_arg <ARG_NAME>` |
| real_dir | Get real path of directory | `real_dir <DIR_PATH>` |
| real_file | Get real path of file | `real_file <FILE_PATH>` |
| conda_mv | Move conda environment to new location | `conda_mv <OLD_CONDA_PATH> <NEW_CONDA_PATH>` |
| prepend_path | Prepend new path to PATH-like environment variable | `prepend_path <VAR_NAME> <NEW_PATH> [SEPARATOR]` |
| port_avail | Check if remote port is available | `port_avail <HOST> <PORT>` |

