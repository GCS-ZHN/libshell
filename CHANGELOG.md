# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.2] - 2026-04-10

### Fixed
- **`update_libshell`**: Fixed incorrect update behavior - now properly backs up old directory to `.libshell.bak`, extracts full release to installation directory, and cleans up backup on success

## [1.0.1] - 2026-04-08

### Added
- **`setup_editor` function** - Sets EDITOR environment variable automatically
  - Detects VS Code terminal (TERM_PROGRAM='vscode') and sets code/cursor/trae with --wait flag
  - For regular terminals, checks nano > nvim > vim > vi
  - Shows installation hints when no editor is found

## [1.0.0] - 2026-04-08

### Added
- **GitHub Release-based installation and updates** - No longer requires git
  - New `install.sh` for one-liner installation via curl/wget
  - `update_libshell` now downloads from GitHub Releases
  - Auto-update check uses GitHub API
- **Cross-platform support** for Bash 4.0+, Zsh 5.0+, and PowerShell 5.1+/7+
- **Shared `common.sh`** with POSIX-compatible code (OS detection, dependency check, utilities)
- **Comprehensive test suite** with test framework for all shells
- **GitHub Actions CI** for cross-platform testing (Ubuntu, macOS, Windows)
- **Auto-update functionality** with optional `LIBSHELL_AUTO_UPDATE=1`
- Core utility functions:
  - `log_err` - Error logging with exit codes
  - `real_dir` / `real_file` - Resolve real paths
  - `create_link` - Idempotent symlink creation
  - `permission2int` / `int2permission` - Permission conversion
  - `is_user_exist` - User existence check
  - `prepend_path` - PATH manipulation
  - `run_in_tmux` - Run commands in tmux sessions
  - `sbat` / `sque` - Slurm batch job utilities

### Fixed
- Guard variables (`LIBSHELL_*_LOADED`) no longer exported, allowing subshells to properly reload the library
- Cross-platform compatibility issues (macOS vs Linux `sed`, `stat`, etc.)

### Documentation
- MIT LICENSE added
- Comprehensive README with installation and usage instructions
- AGENTS.md guidelines for AI coding agents

[Unreleased]: https://github.com/GCS-ZHN/libshell/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/GCS-ZHN/libshell/releases/tag/v1.0.2
[1.0.1]: https://github.com/GCS-ZHN/libshell/releases/tag/v1.0.1
[1.0.0]: https://github.com/GCS-ZHN/libshell/releases/tag/v1.0.0
