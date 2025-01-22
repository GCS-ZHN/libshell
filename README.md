# libshell

A shell tool collections for some common operations.
To use it, just use `. libshell/lib.bash` in your shell script.
Add it to `~/.bashrc` if you want use it globally.


## Usage examples

```bash
. lib.bash

require_args arg_name||log_err 'arg_name not found'

```