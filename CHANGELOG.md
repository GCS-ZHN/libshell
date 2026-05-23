# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.1] - 2026-05-23

### Changed
- **`trun`**: Renamed from `run_in_tmux`. The old name is kept as a deprecated alias
- **`trun`**: Added guard to prevent wrapping `tmux` command (avoid nested sessions)

### Added
- **`tattach`**: New function to attach to tmux sessions by name prefix
- **`tkill`**: New function to kill tmux sessions by prefix with interactive confirmation
- **`tattach`/`tkill`**: Both accept empty prefix to list all sessions

### Deprecated
- **`run_in_tmux`**: Use `trun` instead. Deprecated alias will warn users to switch

## [1.2.0] - 2026-05-23

### Added
- **`tattach`**: New function to attach to tmux sessions by name prefix. If only one session matches, attach directly; if multiple, show interactive selection menu
- **`tkill`**: New function to kill tmux sessions by name prefix. Supports interactive confirmation with options to kill specific session, all matching sessions, or cancel
- **`tattach`/`tkill`**: Both functions now accept empty prefix to list all available sessions

## [1.1.1] - 2026-04-28

### Fixed
- **`run_in_tmux`**: Sanitize tmux session name by replacing invalid characters (`#`, `:`, `.`) to prevent session creation failure when directory name contains these characters

## [1.1.0] - 2026-04-10

### Changed
- **`run_in_tmux`**: tmux session name format changed to `<cmd>_<cwd_name>_<random_id>` for better identification

### Fixed
- **Update notification**: Now shows both current and available versions (e.g., "v1.0.2 -> v1.1.0")

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
  - `trun` - Run commands in tmux sessions (renamed from `run_in_tmux`)
  - `sbat` / `sque` - Slurm batch job utilities

### Fixed
- Guard variables (`LIBSHELL_*_LOADED`) no longer exported, allowing subshells to properly reload the library
- Cross-platform compatibility issues (macOS vs Linux `sed`, `stat`, etc.)

### Documentation
- MIT LICENSE added
- Comprehensive README with installation and usage instructions
- AGENTS.md guidelines for AI coding agents

[Unreleased]: https://github.com/GCS-ZHN/libshell/compare/v1.2.1...HEAD
[1.2.1]: https://github.com/GCS-ZHN/libshell/releases/tag/v1.2.1
[1.2.0]: https://github.com/GCS-ZHN/libshell/releases/tag/v1.2.0
[1.1.1]: https://github.com/GCS-ZHN/libshell/releases/tag/v1.1.1
[1.1.0]: https://github.com/GCS-ZHN/libshell/releases/tag/v1.1.0
[1.0.2]: https://github.com/GCS-ZHN/libshell/releases/tag/v1.0.2
[1.0.1]: https://github.com/GCS-ZHN/libshell/releases/tag/v1.0.1
[1.0.0]: https://github.com/GCS-ZHN/libshell/releases/tag/v1.0.0
