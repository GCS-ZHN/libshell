# lib.ps1 - PowerShell module for general operations
# Target platform: Windows PowerShell 5.1+ / PowerShell Core 7+

# Prevent multiple sourcing
if ($env:LIBSHELL_PS_LOADED -eq "1") {
    return
}

# =============================================================================
# Constants / Error Codes
# =============================================================================
$script:LIBSHELL_VERSION = "1.0"
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

# Internal function to check if updates are available
# Returns: $true if updates available, $false otherwise
function _CheckLibshellUpdate {
    [CmdletBinding()]
    param()
    
    $script:LIBSHELL_UPDATE_AVAILABLE = $false
    
    # Check if git is available
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        return $false
    }
    
    # Get script directory
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $scriptDir) {
        $scriptDir = $PSScriptRoot
    }
    
    # Check if it's a git repository
    if (-not (Test-Path (Join-Path $scriptDir ".git"))) {
        return $false
    }
    
    # Save current location
    $originalDir = Get-Location
    Set-Location $scriptDir
    
    try {
        # Fetch latest from remote
        $null = git fetch origin 2>&1
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
        
        # Get local and remote revisions
        $localRev = git rev-parse HEAD 2>&1
        $remoteRev = git rev-parse origin/HEAD 2>&1
        if ($LASTEXITCODE -ne 0) {
            $remoteRev = git rev-parse origin/main 2>&1
        }
        if ($LASTEXITCODE -ne 0) {
            $remoteRev = git rev-parse origin/master 2>&1
        }
        
        if ($localRev -ne $remoteRev) {
            # Check if local is behind remote
            $null = git merge-base --is-ancestor $localRev $remoteRev 2>&1
            if ($LASTEXITCODE -eq 0) {
                $script:LIBSHELL_UPDATE_AVAILABLE = $true
                return $true
            }
        }
        
        return $false
    }
    finally {
        Set-Location $originalDir
    }
}

# Update libshell from remote repository
function Update-Libshell {
    <#
    .SYNOPSIS
        Update libshell from the remote git repository.
    .DESCRIPTION
        Checks for updates and pulls the latest changes from the remote repository.
    .EXAMPLE
        Update-Libshell
    #>
    [CmdletBinding()]
    param()
    
    # Check if git is available
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-LogError "[libshell] git command not found, cannot update" $script:LIBSHELL_CMD_NOT_FOUND | Out-Null
        return $false
    }
    
    # Get script directory
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $scriptDir) {
        $scriptDir = $PSScriptRoot
    }
    
    # Check if it's a git repository
    if (-not (Test-Path (Join-Path $scriptDir ".git"))) {
        Write-LogError "[libshell] Not a git repository, cannot update" $script:LIBSHELL_DEFAULT_ERR | Out-Null
        return $false
    }
    
    # Save current location
    $originalDir = Get-Location
    Set-Location $scriptDir
    
    try {
        # Check for updates
        $hasUpdates = _CheckLibshellUpdate
        
        if (-not $hasUpdates -and -not $script:LIBSHELL_UPDATE_AVAILABLE) {
            if ($env:LIBSHELL_QUIET -ne "1") {
                Write-Host "[libshell] Already up-to-date (v$script:LIBSHELL_VERSION)" -ForegroundColor Green
            }
            return $true
        }
        
        # Check for local modifications
        $status = git status --porcelain 2>&1
        if ($status) {
            Write-LogError "[libshell] Local modifications detected. Please commit or stash changes before updating." $script:LIBSHELL_DEFAULT_ERR | Out-Null
            return $false
        }
        
        # Perform the update
        if ($env:LIBSHELL_QUIET -ne "1") {
            Write-Host "[libshell] Updating from remote..." -ForegroundColor Yellow
        }
        
        $result = git pull --ff-only origin 2>&1
        if ($LASTEXITCODE -eq 0) {
            # Get new version
            $versionLine = Get-Content (Join-Path $scriptDir "lib.ps1") | Where-Object { $_ -match '^\$script:LIBSHELL_VERSION\s*=' }
            $newVersion = if ($versionLine -match '"([^"]+)"') { $matches[1] } else { "unknown" }
            
            if ($env:LIBSHELL_QUIET -ne "1") {
                Write-Host "[libshell] Updated successfully to v$newVersion" -ForegroundColor Green
                Write-Host "[libshell] Please restart your shell or re-source the library to apply changes." -ForegroundColor Yellow
            }
            return $true
        }
        else {
            Write-LogError "[libshell] Update failed. There may be conflicts with local changes." $script:LIBSHELL_DEFAULT_ERR | Out-Null
            Write-LogError "[libshell] Try: cd $scriptDir; git status" $script:LIBSHELL_DEFAULT_ERR | Out-Null
            return $false
        }
    }
    finally {
        Set-Location $originalDir
    }
}

# Unix-style alias
Set-Alias -Name update_libshell -Value Update-Libshell

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
                Write-Host "[libshell] Updates available. Run 'Update-Libshell' or 'update_libshell' to update." -ForegroundColor Yellow
            }
        }
    }
}

# Note: Export-ModuleMember only works when used as a module (.psm1).
# When dot-sourcing this file, all functions and aliases are automatically
# available in the caller's scope.
