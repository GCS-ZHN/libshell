# AGENTS.md - Guidelines for AI Coding Agents

This document provides guidelines for AI agents working on the libshell codebase.

## Project Overview

libshell is a cross-platform shell utility library supporting **Bash 4.0+**, **Zsh 5.0+**, and **PowerShell 5.1+/7+** on **Linux**, **macOS**, and **Windows**.

Architecture:
- `common.sh` - POSIX-compatible shared code (sourced by lib.bash and lib.zsh)
- `lib.bash` - Bash-specific implementations
- `lib.zsh` - Zsh-specific implementations
- `lib.ps1` - PowerShell implementation (standalone, does not source common.sh)

## Build/Lint/Test Commands

```bash
# Run all tests
./tests/run_tests.sh

# Run specific test suite
./tests/run_tests.sh common    # Test common.sh only
./tests/run_tests.sh bash      # Test lib.bash only
./tests/run_tests.sh zsh       # Test lib.zsh only
./tests/run_tests.sh pwsh      # Test lib.ps1 only

# Run single test file directly
bash tests/test_common.sh
bash tests/test_lib_bash.sh
zsh tests/test_lib_zsh.sh
pwsh tests/test_lib_ps1.ps1

# Verbose output
TEST_VERBOSE=1 ./tests/run_tests.sh

# Lint with ShellCheck
shellcheck common.sh lib.bash lib.zsh
```

## Code Style Guidelines

### File Headers
```bash
# filename.sh - Brief description of purpose
# Target platform: Bash 4.0+ / Zsh 5.0+ / PowerShell 5.1+
```

### Guard Against Multiple Sourcing
```bash
# Bash/Zsh (POSIX) - Do NOT export, subshells should reload
if [ -n "$LIBSHELL_COMMON_LOADED" ]; then return 0; fi
LIBSHELL_COMMON_LOADED=1

# PowerShell - env vars are inherited but that's OK for pwsh
if ($env:LIBSHELL_PS_LOADED -eq "1") { return }
$env:LIBSHELL_PS_LOADED = "1"
```

### Naming Conventions
| Type | Shell (Bash/Zsh) | PowerShell |
|------|------------------|------------|
| Public functions | `snake_case` | `Verb-Noun` (PascalCase) |
| Private functions | `__libshell_name` | `_PrivateName` |
| Constants | `LIBSHELL_UPPER_CASE` | `$script:LIBSHELL_UPPER_CASE` |
| Local variables | `local snake_case` | `$camelCase` |
| Aliases | `snake_case` | Unix-style `snake_case` |

### Error Codes (consistent across all shells)
| Code | Constant | Use Case |
|------|----------|----------|
| 0 | `LIBSHELL_DEFAULT_OK` | Success |
| 1 | `LIBSHELL_DEFAULT_ERR` | General error |
| 2 | `LIBSHELL_ARG_ERR` | Invalid arguments |
| 3-4 | `LIBSHELL_SHELL_NOT_SUPPORTED` / `CMD_NOT_FOUND` | Shell/command errors |
| 5-8 | `LIBSHELL_FILE_*` / `LIBSHELL_LINK_ERR` | File/symlink errors |
| 9 | `LIBSHELL_OS_NOT_SUPPORTED` | Unsupported OS |

### Error Handling

**Bash/Zsh**: Use `log_err`, return error codes, never `exit` in library functions:
```bash
function my_function() {
    [ "$#" -ne 2 ] && { log_err "Usage: my_function <A> <B>" ${LIBSHELL_ARG_ERR}; return $?; }
    # ... implementation
    return ${LIBSHELL_DEFAULT_OK}
}
```

**PowerShell**: Use `Write-LogError`, return `$null` on failure, pipe error output to `Out-Null`:
```powershell
function Get-Something {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) {
        Write-LogError "Path not found" $script:LIBSHELL_FILE_TYPE_ERR | Out-Null
        return $null
    }
    # ... implementation
}
```

### Shell-Specific Syntax Reference
| Feature | Bash | Zsh | PowerShell |
|---------|------|-----|------------|
| Indirect var | `${!var}` | `${(P)var}` | `(Get-Item "env:$var").Value` |
| Script path | `${BASH_SOURCE[0]}` | `$0` | `$MyInvocation.MyCommand.Path` |
| Realpath | `realpath` / `cd && pwd -P` | `${var:A}` | `Resolve-Path` |
| Dirname | `dirname` | `${var:h}` | `Split-Path -Parent` |
| Export func | `export -f func` | N/A | N/A (auto-available) |

### OS-Specific Behavior
```bash
if [ "$LIBSHELL_OS" = "macos" ]; then
    sed -i '' "s/old/new/" file    # macOS requires empty string
else
    sed -i "s/old/new/" file       # Linux
fi
```

### PowerShell Aliases
Avoid overwriting Windows built-in AllScope aliases (`ls`, `cat`, `rm`, `cp`, `mv`). These are only set on Linux/macOS:
```powershell
if ($IsLinux -or $IsMacOS) {
    Set-Alias -Name ls -Value Get-ChildItem -ErrorAction SilentlyContinue
}
```

## Testing Guidelines

### Test Framework (Bash/Zsh)
```bash
test_start "description"           # Start test case
test_pass / test_fail "message"    # Mark result
assert_equals expected actual      # Assert equality
test_summary                       # Print summary at end
```

### Testing Subshell Behavior
Unset guard variables in temp scripts to ensure fresh load:
```bash
unset LIBSHELL_COMMON_LOADED
unset LIBSHELL_BASH_LOADED
source "$PROJECT_DIR/lib.bash"
```

### PowerShell Tests
```powershell
$env:LIBSHELL_PS_LOADED = $null    # Reset before sourcing
$env:LIBSHELL_QUIET = "1"          # Suppress load message
. "$ProjectDir/lib.ps1"
```

## Common Pitfalls

1. **Zsh `is_source` pattern**: Use `*:file*` not `:file$` (context changes in function calls)
2. **Exported guard variables**: Subshells inherit `LIBSHELL_*_LOADED`, causing early returns
3. **macOS `sed -i`**: Requires empty string argument `sed -i ''`
4. **macOS `stat`**: Use `-f "%Sp"` not `--format=%A`
5. **PowerShell `Write-LogError`**: Returns exit code to pipeline; use `| Out-Null` when calling
6. **PowerShell `Export-ModuleMember`**: Only works in `.psm1` modules, not dot-sourced scripts
7. **Heredoc variable expansion**: Use `<< 'EOF'` to prevent expansion, `<< EOF` to allow it
8. **Version test race condition**: Test files (`test_lib_*.sh`, `test_lib_ps1.ps1`) contain hardcoded version assertions. When releasing:
   - **Always update test file versions BEFORE creating the git tag**
   - Otherwise CI runs against the OLD test files before your version bump commit
   - The tag triggers CI immediately upon push, before test file updates can reach CI
   - **Solution**: Sequence: (1) update version everywhere, (2) commit, (3) update test files, (4) commit, (5) tag and push
   - Or use force-push to update the tag after all updates are committed

## CI/CD

GitHub Actions runs tests on:
- Ubuntu (bash, zsh, pwsh)
- macOS (bash, zsh, pwsh)  
- Windows (pwsh only)

Workflow file: `.github/workflows/ci.yml`

## Versioning and Releases

### Version Management

- Version is defined in `common.sh` (`LIBSHELL_VERSION`) and `lib.ps1` (`$script:LIBSHELL_VERSION`)
- **Both files must have the same version number** (e.g., `1.0.0`)
- Test files may assert the version - update them when bumping version
- Version format: `MAJOR.MINOR.PATCH` (Semantic Versioning)
- Git tags use `v` prefix: `v1.0.0`

### CHANGELOG.md Format

Maintain `CHANGELOG.md` following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/):

```markdown
## [Unreleased]

## [X.Y.Z] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes in existing functionality

### Fixed
- Bug fixes

### Removed
- Removed features
```

**Important**: The CI workflow extracts the section for the tagged version and includes it in the GitHub Release notes.

### Creating a Release

1. **Update version numbers** in:
   - `common.sh`: `export LIBSHELL_VERSION=X.Y.Z`
   - `lib.ps1`: `$script:LIBSHELL_VERSION = "X.Y.Z"`
   - Test files if they assert version

2. **Update CHANGELOG.md**:
   - Move items from `[Unreleased]` to new version section
   - Add release date: `## [X.Y.Z] - YYYY-MM-DD`
   - Add comparison link at bottom

3. **Commit, tag, and push**:
   ```bash
   git add -A
   git commit -m "chore: release vX.Y.Z"
   git tag vX.Y.Z
   git push origin main --tags
   ```

4. **CI will automatically**:
   - Run all tests
   - Extract changelog section for this version
   - Create GitHub Release with:
     - Changelog content
     - Installation instructions
     - `libshell-vX.Y.Z.tar.gz` asset

### Release Notes Content

GitHub Release notes are auto-generated from:
1. **Changelog section** for the version (from CHANGELOG.md)
2. **Installation instructions** (hardcoded in CI workflow)

To modify installation instructions in release notes, edit `.github/workflows/ci.yml` release job.

### Post-Push Monitoring

After pushing code or tags, **always monitor GitHub Actions until success**:
```bash
# Watch workflow status
gh run list --limit 3

# View failure logs
gh run view <run-id> --log-failed

# Wait for completion
gh run watch <run-id>
```

**Never consider the task complete until CI passes.** Common issues to watch for:
- Version test race conditions (test files vs library version mismatch)
- Export errors ("not a function" indicates function defined after export statement)
- Network/auth failures in macOS runners
- Permission/ACL issues on specific OS platforms
