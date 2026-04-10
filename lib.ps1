# lib.ps1 - PowerShell module for general operations
# Target platform: Windows PowerShell 5.1+ / PowerShell Core 7+

# Prevent multiple sourcing
if ($env:LIBSHELL_PS_LOADED -eq "1") {
    return
}

# =============================================================================
# Constants / Error Codes
# =============================================================================
$script:LIBSHELL_VERSION = "1.0.2"
$script:LIBSHELL_DEFAULT_OK = 0
$script:LIBSHELL_DEFAULT_ERR = 1
$script:LIBSHELL_ARG_ERR = 2
$script:LIBSHELL_SHELL_NOT_SUPPORTED = 3
$script:LIBSHELL_CMD_NOT_FOUND = 4
$script:LIBSHELL_FILE_EXISTED = 5
$script:LIBSHELL_FILE_TYPE_ERR = 6
$script:LIBSHELL_FILE_IO_ERR = 7
$script:LIBSHELL_LINK_ERR = 8
$script:LIBSHELL_OS_NOT_SUPPORTED = 9

# Export constants
$env:LIBSHELL_VERSION = $script:LIBSHELL_VERSION

# =============================================================================
# Logging Functions
# =============================================================================
function Write-LogError {
    <#
    .SYNOPSIS
        Output error message to stderr.
    .PARAMETER Message
        The error message to output.
    .PARAMETER ExitCode
        Optional exit code (for reference, does not terminate).
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter(Position = 1)]
        [int]$ExitCode = $script:LIBSHELL_DEFAULT_ERR
    )
    Write-Error $Message
    return $ExitCode
}

function Write-LogWarn {
    <#
    .SYNOPSIS
        Output warning message.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message
    )
    Write-Warning $Message
}

function Write-LogInfo {
    <#
    .SYNOPSIS
        Output info message.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message
    )
    Write-Host "[info] $Message" -ForegroundColor Cyan
}

# =============================================================================
# Path Utility Functions
# =============================================================================
function Get-RealDir {
    <#
    .SYNOPSIS
        Get the absolute path of a directory.
    .PARAMETER Path
        The directory path to resolve.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        Write-LogError "'$Path' does not exist" $script:LIBSHELL_FILE_TYPE_ERR | Out-Null
        return $null
    }

    $item = Get-Item $Path -ErrorAction SilentlyContinue
    if (-not $item.PSIsContainer) {
        Write-LogError "'$Path' is not a directory" $script:LIBSHELL_FILE_TYPE_ERR | Out-Null
        return $null
    }

    return $item.FullName
}

function Get-RealFile {
    <#
    .SYNOPSIS
        Get the absolute path of a file.
    .PARAMETER Path
        The file path to resolve.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        Write-LogError "'$Path' does not exist" $script:LIBSHELL_FILE_TYPE_ERR | Out-Null
        return $null
    }

    $item = Get-Item $Path -ErrorAction SilentlyContinue
    if ($item.PSIsContainer) {
        Write-LogError "'$Path' is not a file" $script:LIBSHELL_FILE_TYPE_ERR | Out-Null
        return $null
    }

    return $item.FullName
}

function Add-PathPrefix {
    <#
    .SYNOPSIS
        Prepend a path to an environment variable if not already present.
    .PARAMETER VarName
        The name of the environment variable (e.g., 'PATH').
    .PARAMETER NewPath
        The path to prepend.
    .PARAMETER Separator
        The separator character (default: ';' for Windows).
    .EXAMPLE
        Add-PathPrefix -VarName PATH -NewPath "C:\tools\bin"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$VarName,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$NewPath,

        [Parameter(Position = 2)]
        [string]$Separator = ";"
    )

    $currentValue = [Environment]::GetEnvironmentVariable($VarName)
    
    if ([string]::IsNullOrEmpty($currentValue)) {
        [Environment]::SetEnvironmentVariable($VarName, $NewPath)
    } else {
        $paths = $currentValue -split [regex]::Escape($Separator)
        if ($paths -notcontains $NewPath) {
            $newValue = $NewPath + $Separator + $currentValue
            [Environment]::SetEnvironmentVariable($VarName, $newValue)
        }
    }
}

# =============================================================================
# Network Utility Functions
# =============================================================================
function Test-PortAvailable {
    <#
    .SYNOPSIS
        Check if a remote port is accessible.
    .PARAMETER Host
        The remote host to check.
    .PARAMETER Port
        The port number to check.
    .PARAMETER Timeout
        Timeout in milliseconds (default: 1000).
    .EXAMPLE
        Test-PortAvailable -Host "localhost" -Port 8080
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$RemoteHost,

        [Parameter(Mandatory = $true, Position = 1)]
        [int]$Port,

        [Parameter(Position = 2)]
        [int]$Timeout = 1000
    )

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect($RemoteHost, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne($Timeout, $false)
        
        if ($wait) {
            $tcpClient.EndConnect($connect)
            $tcpClient.Close()
            return $true
        } else {
            $tcpClient.Close()
            return $false
        }
    } catch {
        return $false
    }
}

# =============================================================================
# Link Utility Functions
# =============================================================================
function New-SymbolicLinkSafe {
    <#
    .SYNOPSIS
        Create a symbolic link (idempotent).
    .PARAMETER Source
        The source path (link target).
    .PARAMETER Target
        The target path (link location).
    .EXAMPLE
        New-SymbolicLinkSafe -Source "C:\actual\path" -Target "C:\link\path"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Source,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Target
    )

    if (Test-Path $Target) {
        $item = Get-Item $Target -Force
        if ($item.LinkType -eq "SymbolicLink") {
            $existingTarget = $item.Target
            if ($existingTarget -eq $Source) {
                return $script:LIBSHELL_DEFAULT_OK
            } else {
                Write-LogError "Link $Target already exists and points to $existingTarget" $script:LIBSHELL_LINK_ERR
                return $script:LIBSHELL_LINK_ERR
            }
        }
    }

    try {
        New-Item -ItemType SymbolicLink -Path $Target -Target $Source -Force | Out-Null
        return $script:LIBSHELL_DEFAULT_OK
    } catch {
        Write-LogError "Failed to create symbolic link: $_" $script:LIBSHELL_LINK_ERR
        return $script:LIBSHELL_LINK_ERR
    }
}

# =============================================================================
# User Utility Functions
# =============================================================================
function Test-UserExist {
    <#
    .SYNOPSIS
        Check if a local user exists.
    .PARAMETER UserName
        The username to check.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$UserName
    )

    try {
        $user = Get-LocalUser -Name $UserName -ErrorAction Stop
        return $true
    } catch {
        Write-Host "User $UserName does not exist" -ForegroundColor Red
        return $false
    }
}

function Setup-Editor {
    <#
    .SYNOPSIS
        Set the default EDITOR environment variable.
    .DESCRIPTION
        Detects the environment (VS Code terminal or regular terminal) and sets
        EDITOR to an appropriate editor. VS Code-style editors use --wait flag.
    .EXAMPLE
        Setup-Editor
    #>
    [CmdletBinding()]
    param()

    if ($env:TERM_PROGRAM -eq "vscode") {
        $vscodeEditors = @("code", "cursor", "trae")
        foreach ($editor in $vscodeEditors) {
            if (Get-Command $editor -ErrorAction SilentlyContinue) {
                $env:EDITOR = "$editor --wait"
                if ($env:LIBSHELL_QUIET -ne "1") {
                    Write-Host "[libshell] EDITOR set to $env:EDITOR" -ForegroundColor Green
                }
                return $true
            }
        }
        if ($env:LIBSHELL_QUIET -ne "1") {
            Write-Host "[libshell] No VS Code-style editor found (code, cursor, trae)." -ForegroundColor Yellow
            Write-Host "[libshell] To install VS Code: https://code.visualstudio.com/"
            Write-Host "[libshell] To install Cursor: https://cursor.com/"
            Write-Host "[libshell] To install Trae: https://trae.ai/"
        }
    } else {
        $terminalEditors = @("nano", "nvim", "vim", "vi")
        foreach ($editor in $terminalEditors) {
            if (Get-Command $editor -ErrorAction SilentlyContinue) {
                $env:EDITOR = $editor
                if ($env:LIBSHELL_QUIET -ne "1") {
                    Write-Host "[libshell] EDITOR set to $env:EDITOR" -ForegroundColor Green
                }
                return $true
            }
        }
        if ($env:LIBSHELL_QUIET -ne "1") {
            Write-Host "[libshell] No terminal editor found (tried: nano, nvim, vim, vi)." -ForegroundColor Red
            Write-Host "[libshell] To install nano: sudo apt install nano" -ForegroundColor Cyan
            Write-Host "[libshell] To install neovim: sudo apt install neovim" -ForegroundColor Cyan
        }
    }
    return $false
}

# =============================================================================
# Hash/Checksum Functions
# =============================================================================
function Get-HashSum {
    <#
    .SYNOPSIS
        Calculate the hash of files.
    .PARAMETER Algorithm
        The hash algorithm to use. E.g. MD5, SHA256, SHA1, etc.
    .PARAMETER Files
        The files to calculate the hash of.
    .EXAMPLE
        Get-HashSum -Algorithm SHA256 file1.txt file2.txt
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet('MD5', 'SHA1', 'SHA256', 'SHA384', 'SHA512')]
        [string]$Algorithm,

        [Parameter(ValueFromRemainingArguments = $true, Position = 1)]
        [string[]]$Files
    )

    if (-not $Files -or $Files.Count -eq 0) {
        Write-Error "Usage: Get-HashSum -Algorithm <MD5|SHA1|SHA256|SHA384|SHA512> file1 [file2 ...]"
        return
    }

    foreach ($f in $Files) {
        if (Test-Path $f) {
            try {
                $hash = Get-FileHash -Path $f -Algorithm $Algorithm
                $hashstr = $hash.Hash.ToLower()
                Write-Output "$hashstr  $f"
            } catch {
                Write-Error "Get-HashSum: Failed to hash $f with $Algorithm"
            }
        } else {
            Write-Error "Get-HashSum: ${f}: No such file"
        }
    }
}

# Unix-style hash aliases
function md5sum {
    param ([Parameter(ValueFromRemainingArguments = $true)][string[]]$Files)
    Get-HashSum -Algorithm MD5 @Files
}

function sha1sum {
    param ([Parameter(ValueFromRemainingArguments = $true)][string[]]$Files)
    Get-HashSum -Algorithm SHA1 @Files
}

function sha256sum {
    param ([Parameter(ValueFromRemainingArguments = $true)][string[]]$Files)
    Get-HashSum -Algorithm SHA256 @Files
}

function sha384sum {
    param ([Parameter(ValueFromRemainingArguments = $true)][string[]]$Files)
    Get-HashSum -Algorithm SHA384 @Files
}

function sha512sum {
    param ([Parameter(ValueFromRemainingArguments = $true)][string[]]$Files)
    Get-HashSum -Algorithm SHA512 @Files
}

# =============================================================================
# Argument Validation Functions
# =============================================================================
function Test-RequiredArg {
    <#
    .SYNOPSIS
        Check if a variable/environment variable is defined and not empty.
    .PARAMETER VarName
        The name of the variable to check.
    .PARAMETER Value
        Optional: the value to check directly.
    .EXAMPLE
        Test-RequiredArg -VarName "MY_VAR"
        Test-RequiredArg -Value $myVariable
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]$VarName,

        [Parameter(Position = 1)]
        [string]$Value
    )

    if ($VarName) {
        $val = [Environment]::GetEnvironmentVariable($VarName)
        if ([string]::IsNullOrEmpty($val)) {
            # Also check PowerShell variable scope
            $val = Get-Variable -Name $VarName -ValueOnly -ErrorAction SilentlyContinue
        }
        return -not [string]::IsNullOrEmpty($val)
    } elseif ($PSBoundParameters.ContainsKey('Value')) {
        return -not [string]::IsNullOrEmpty($Value)
    } else {
        Write-Error "Usage: Test-RequiredArg -VarName <name> or Test-RequiredArg -Value <value>"
        return $false
    }
}

# =============================================================================
# Conda Functions (Windows-specific paths)
# =============================================================================
function Move-CondaEnv {
    <#
    .SYNOPSIS
        Move conda environment to a new location.
    .PARAMETER OldPath
        The current conda environment path.
    .PARAMETER NewPath
        The new location for the conda environment.
    .EXAMPLE
        Move-CondaEnv -OldPath "C:\Users\me\miniconda3\envs\myenv" -NewPath "D:\conda\myenv"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$OldPath,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$NewPath
    )

    $oldCondaHome = Get-RealDir $OldPath
    if (-not $oldCondaHome) {
        return $script:LIBSHELL_FILE_TYPE_ERR
    }

    if (Test-Path $NewPath) {
        Write-LogError "Target path should not exist!" $script:LIBSHELL_FILE_EXISTED
        return $script:LIBSHELL_FILE_EXISTED
    }

    # Copy the environment
    try {
        Write-LogInfo "Copying conda environment..."
        Copy-Item -Path $oldCondaHome -Destination $NewPath -Recurse -Force
    } catch {
        Write-LogError "Copy conda home failed: $_" $script:LIBSHELL_FILE_IO_ERR
        return $script:LIBSHELL_FILE_IO_ERR
    }

    # Update paths in text files
    Write-LogInfo "Updating paths in conda environment..."
    $textFiles = Get-ChildItem -Path $NewPath -Recurse -File | Where-Object {
        $_.Extension -in @('.py', '.cfg', '.json', '.yaml', '.yml', '.txt', '.sh', '.bat', '.cmd', '.ps1', '')
    }

    foreach ($file in $textFiles) {
        try {
            $content = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -and $content.Contains($oldCondaHome)) {
                $newContent = $content.Replace($oldCondaHome, $NewPath)
                Set-Content -Path $file.FullName -Value $newContent -NoNewline
                Write-Output "Updated: $($file.FullName)"
            }
        } catch {
            # Skip binary or locked files
        }
    }

    # Remove old environment
    Write-LogInfo "Removing old conda environment..."
    Remove-Item -Path $oldCondaHome -Recurse -Force

    Write-LogInfo "Conda environment moved successfully!"
    return $script:LIBSHELL_DEFAULT_OK
}

# =============================================================================
# Unix-style Aliases
# =============================================================================
# Note: On Windows, ls, cat, rm, cp, mv are built-in AllScope aliases that
# cannot be overwritten. We only set aliases that don't conflict.
Set-Alias -Name which -Value Get-Command -ErrorAction SilentlyContinue
Set-Alias -Name df -Value Get-PSDrive -ErrorAction SilentlyContinue
Set-Alias -Name pwd -Value Get-Location -ErrorAction SilentlyContinue
Set-Alias -Name touch -Value New-Item -ErrorAction SilentlyContinue

# These aliases may fail on Windows due to AllScope restrictions - that's OK
if ($IsLinux -or $IsMacOS) {
    Set-Alias -Name ls -Value Get-ChildItem -ErrorAction SilentlyContinue
    Set-Alias -Name cat -Value Get-Content -ErrorAction SilentlyContinue
    Set-Alias -Name rm -Value Remove-Item -ErrorAction SilentlyContinue
    Set-Alias -Name cp -Value Copy-Item -ErrorAction SilentlyContinue
    Set-Alias -Name mv -Value Move-Item -ErrorAction SilentlyContinue
}

# Alias mappings to Unix-style names
Set-Alias -Name log_err -Value Write-LogError
Set-Alias -Name log_warn -Value Write-LogWarn
Set-Alias -Name log_info -Value Write-LogInfo
Set-Alias -Name real_dir -Value Get-RealDir
Set-Alias -Name real_file -Value Get-RealFile
Set-Alias -Name prepend_path -Value Add-PathPrefix
Set-Alias -Name port_avail -Value Test-PortAvailable
Set-Alias -Name create_link -Value New-SymbolicLinkSafe
Set-Alias -Name is_user_exist -Value Test-UserExist
Set-Alias -Name require_arg -Value Test-RequiredArg
Set-Alias -Name hashsum -Value Get-HashSum
Set-Alias -Name conda_mv -Value Move-CondaEnv

# =============================================================================
# Auto-update Functions
# =============================================================================

# GitHub repository for updates
$script:LIBSHELL_GITHUB_REPO = if ($env:LIBSHELL_GITHUB_REPO) { $env:LIBSHELL_GITHUB_REPO } else { "GCS-ZHN/libshell" }

# Internal function to check if updates are available
# Returns: $true if updates available, $false otherwise
# Sets: $script:LIBSHELL_UPDATE_AVAILABLE and $script:LIBSHELL_LATEST_VERSION
function _CheckLibshellUpdate {
    [CmdletBinding()]
    param()
    
    $script:LIBSHELL_UPDATE_AVAILABLE = $false
    $script:LIBSHELL_LATEST_VERSION = ""
    
    try {
        # Fetch latest release info from GitHub API
        $apiUrl = "https://api.github.com/repos/$script:LIBSHELL_GITHUB_REPO/releases/latest"
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop
        
        $latestTag = $response.tag_name
        if (-not $latestTag) {
            return $false
        }
        
        $script:LIBSHELL_LATEST_VERSION = $latestTag
        
        # Compare versions (strip 'v' prefix if present)
        $currentVer = $script:LIBSHELL_VERSION -replace '^v', ''
        $latestVer = $latestTag -replace '^v', ''
        
        if ($currentVer -ne $latestVer) {
            $script:LIBSHELL_UPDATE_AVAILABLE = $true
            return $true
        }
        
        return $false
    }
    catch {
        return $false
    }
}

# Update libshell from GitHub Release
function Update-Libshell {
    <#
    .SYNOPSIS
        Update libshell from GitHub Release.
    .DESCRIPTION
        Checks for updates and downloads the latest release from GitHub.
    .EXAMPLE
        Update-Libshell
    #>
    [CmdletBinding()]
    param()
    
    # Get script directory (installation directory)
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $scriptDir) {
        $scriptDir = $PSScriptRoot
    }
    
    if (-not $scriptDir -or -not (Test-Path $scriptDir)) {
        Write-LogError "[libshell] Cannot determine installation directory" $script:LIBSHELL_DEFAULT_ERR | Out-Null
        return $false
    }
    
    # Check for updates
    $hasUpdates = _CheckLibshellUpdate
    
    if (-not $hasUpdates -and -not $script:LIBSHELL_UPDATE_AVAILABLE) {
        if ($env:LIBSHELL_QUIET -ne "1") {
            Write-Host "[libshell] Already up-to-date (v$script:LIBSHELL_VERSION)" -ForegroundColor Green
        }
        return $true
    }
    
    $version = $script:LIBSHELL_LATEST_VERSION
    if (-not $version) {
        Write-LogError "[libshell] Could not determine latest version" $script:LIBSHELL_DEFAULT_ERR | Out-Null
        return $false
    }
    
    if ($env:LIBSHELL_QUIET -ne "1") {
        Write-Host "[libshell] Updating from v$script:LIBSHELL_VERSION to $version..." -ForegroundColor Yellow
    }
    
    try {
        # Create temporary directory
        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "libshell-update-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
        $tmpFile = Join-Path $tmpDir "libshell.tar.gz"
        $backupDir = "$scriptDir.bak"
        
        # Download release tarball
        $downloadUrl = "https://github.com/$script:LIBSHELL_GITHUB_REPO/releases/download/$version/libshell-$version.tar.gz"
        
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tmpFile -ErrorAction Stop
        }
        catch {
            # Fallback: try source tarball from GitHub
            $downloadUrl = "https://github.com/$script:LIBSHELL_GITHUB_REPO/archive/refs/tags/$version.tar.gz"
            try {
                Invoke-WebRequest -Uri $downloadUrl -OutFile $tmpFile -ErrorAction Stop
            }
            catch {
                Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
                Write-LogError "[libshell] Failed to download release $version" $script:LIBSHELL_FILE_IO_ERR | Out-Null
                return $false
            }
        }
        
        # Backup existing installation
        if (Test-Path $scriptDir) {
            if ($env:LIBSHELL_QUIET -ne "1") {
                Write-Host "[libshell] Backing up existing installation to ${backupDir}" -ForegroundColor Cyan
            }
            Remove-Item -Path $backupDir -Recurse -Force -ErrorAction SilentlyContinue
            Move-Item -Path $scriptDir -Destination $backupDir -Force
        }
        
        # Extract release directly to installation directory
        try {
            New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
            tar -xzf $tmpFile -C $scriptDir --strip-components=1
            if ($LASTEXITCODE -ne 0) {
                throw "tar extraction failed"
            }
        }
        catch {
            # Restore backup on failure
            Remove-Item -Path $scriptDir -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path $backupDir) {
                Move-Item -Path $backupDir -Destination $scriptDir -Force
            }
            Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-LogError "[libshell] Failed to extract release" $script:LIBSHELL_FILE_IO_ERR | Out-Null
            return $false
        }
        
        # Cleanup: remove backup and temp directory
        Remove-Item -Path $backupDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        
        if ($env:LIBSHELL_QUIET -ne "1") {
            Write-Host "[libshell] Updated successfully to $version" -ForegroundColor Green
            Write-Host "[libshell] Please restart your shell or re-source the library to apply changes." -ForegroundColor Yellow
        }
        return $true
    }
    catch {
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-LogError "[libshell] Update failed: $_" $script:LIBSHELL_DEFAULT_ERR | Out-Null
        return $false
    }
}

# Unix-style alias
Set-Alias -Name update_libshell -Value Update-Libshell
Set-Alias -Name setup_editor -Value Setup-Editor

# =============================================================================
# Initialization
# =============================================================================
$env:LIBSHELL_PS_LOADED = "1"

# Display load message if not quiet
if ($env:LIBSHELL_QUIET -ne "1") {
    Write-Host "LibShell (PowerShell) v$script:LIBSHELL_VERSION loaded" -ForegroundColor Green
}

# Auto-update check on load (if enabled)
if ($env:LIBSHELL_UPDATE_CHECKED -ne "1") {
    $env:LIBSHELL_UPDATE_CHECKED = "1"
    
    if ($env:LIBSHELL_AUTO_UPDATE -eq "1") {
        # Auto-update enabled: check and update
        if (_CheckLibshellUpdate) {
            Update-Libshell | Out-Null
        }
    }
    else {
        # Auto-update disabled: just notify if updates available
        if (_CheckLibshellUpdate) {
            if ($env:LIBSHELL_QUIET -ne "1") {
                Write-Host "[libshell] Updates available: v$script:LIBSHELL_VERSION -> $script:LIBSHELL_LATEST_VERSION. Run 'Update-Libshell' or 'update_libshell' to update." -ForegroundColor Yellow
            }
        }
    }
}

# Note: Export-ModuleMember only works when used as a module (.psm1).
# When dot-sourcing this file, all functions and aliases are automatically
# available in the caller's scope.
