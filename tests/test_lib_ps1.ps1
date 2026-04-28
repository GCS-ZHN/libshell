# test_lib_ps1.ps1 - Tests for lib.ps1 PowerShell module
# Run with: pwsh tests/test_lib_ps1.ps1

$ErrorActionPreference = "Continue"

# Get script directory
$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ProjectDir = Split-Path -Parent $script:ScriptDir

# =============================================================================
# Test Framework
# =============================================================================
$script:TestPassed = 0
$script:TestFailed = 0
$script:TestSkipped = 0
$script:TestTotal = 0
$script:CurrentTest = ""

function Test-Start {
    param([string]$Description)
    $script:CurrentTest = $Description
    $script:TestTotal++
}

function Test-Pass {
    $script:TestPassed++
    Write-Host "[PASS] $script:CurrentTest" -ForegroundColor Green
}

function Test-Fail {
    param([string]$Message = "")
    $script:TestFailed++
    if ($Message) {
        Write-Host "[FAIL] $script:CurrentTest: $Message" -ForegroundColor Red
    } else {
        Write-Host "[FAIL] $script:CurrentTest" -ForegroundColor Red
    }
}

function Test-Skip {
    param([string]$Reason = "")
    $script:TestSkipped++
    if ($Reason) {
        Write-Host "[SKIP] $script:CurrentTest: $Reason" -ForegroundColor Yellow
    } else {
        Write-Host "[SKIP] $script:CurrentTest" -ForegroundColor Yellow
    }
}

function Assert-Equals {
    param($Expected, $Actual, [string]$Message = "")
    if ($Expected -eq $Actual) {
        Test-Pass
        return $true
    } else {
        if (-not $Message) {
            $Message = "Expected '$Expected' but got '$Actual'"
        }
        Test-Fail $Message
        return $false
    }
}

function Assert-True {
    param($Value, [string]$Message = "Expected true")
    if ($Value) {
        Test-Pass
        return $true
    } else {
        Test-Fail $Message
        return $false
    }
}

function Assert-False {
    param($Value, [string]$Message = "Expected false")
    if (-not $Value) {
        Test-Pass
        return $true
    } else {
        Test-Fail $Message
        return $false
    }
}

function Assert-NotNull {
    param($Value, [string]$Message = "Expected non-null value")
    if ($null -ne $Value -and $Value -ne "") {
        Test-Pass
        return $true
    } else {
        Test-Fail $Message
        return $false
    }
}

function Test-Summary {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "Test Summary"
    Write-Host "=========================================="
    Write-Host "Total:   $script:TestTotal"
    Write-Host "Passed:  $script:TestPassed" -ForegroundColor Green
    Write-Host "Failed:  $script:TestFailed" -ForegroundColor Red
    Write-Host "Skipped: $script:TestSkipped" -ForegroundColor Yellow
    Write-Host "=========================================="
    
    if ($script:TestFailed -eq 0) {
        Write-Host "All tests passed!" -ForegroundColor Green
        return 0
    } else {
        Write-Host "Some tests failed!" -ForegroundColor Red
        return 1
    }
}

# =============================================================================
# Reset and Load Library
# =============================================================================
$env:LIBSHELL_PS_LOADED = $null
$env:LIBSHELL_QUIET = "1"

# Source the library
. "$script:ProjectDir/lib.ps1"

# =============================================================================
# Test: Library Loading
# =============================================================================

Test-Start "lib.ps1 sets LIBSHELL_PS_LOADED"
Assert-Equals "1" $env:LIBSHELL_PS_LOADED

Test-Start "LIBSHELL_VERSION is set"
Assert-Equals "1.1.1" $script:LIBSHELL_VERSION

Test-Start "Error codes are defined"
if ($script:LIBSHELL_DEFAULT_OK -eq 0 -and 
    $script:LIBSHELL_DEFAULT_ERR -eq 1 -and 
    $script:LIBSHELL_ARG_ERR -eq 2) {
    Test-Pass
} else {
    Test-Fail "Error codes not properly defined"
}

# =============================================================================
# Test: Logging Functions
# =============================================================================

Test-Start "Write-LogError function exists"
if (Get-Command Write-LogError -ErrorAction SilentlyContinue) {
    Test-Pass
} else {
    Test-Fail "Function not defined"
}

Test-Start "Write-LogWarn function exists"
if (Get-Command Write-LogWarn -ErrorAction SilentlyContinue) {
    Test-Pass
} else {
    Test-Fail "Function not defined"
}

Test-Start "Write-LogInfo function exists"
if (Get-Command Write-LogInfo -ErrorAction SilentlyContinue) {
    Test-Pass
} else {
    Test-Fail "Function not defined"
}

# =============================================================================
# Test: Path Utility Functions
# =============================================================================

Test-Start "Get-RealDir returns absolute path for existing directory"
$result = Get-RealDir $script:ProjectDir
if ($result -and [System.IO.Path]::IsPathRooted($result)) {
    Test-Pass
} else {
    Test-Fail "Expected absolute path, got: $result"
}

Test-Start "Get-RealDir returns null for non-existent directory"
$result = Get-RealDir "/nonexistent/path/12345" 2>$null
Assert-True ($null -eq $result) "Expected null for non-existent path"

Test-Start "Get-RealFile returns absolute path for existing file"
$testFile = "$script:ProjectDir/lib.ps1"
$result = Get-RealFile $testFile
if ($result -and [System.IO.Path]::IsPathRooted($result)) {
    Test-Pass
} else {
    Test-Fail "Expected absolute path, got: $result"
}

Test-Start "Get-RealFile returns null for non-existent file"
$result = Get-RealFile "/nonexistent/file/12345.txt" 2>$null
Assert-True ($null -eq $result) "Expected null for non-existent file"

# =============================================================================
# Test: Add-PathPrefix Function
# =============================================================================

Test-Start "Add-PathPrefix adds path to empty variable"
$env:TEST_PATH_VAR = $null
Add-PathPrefix -VarName "TEST_PATH_VAR" -NewPath "/new/path"
Assert-Equals "/new/path" $env:TEST_PATH_VAR

Test-Start "Add-PathPrefix prepends to existing path"
$env:TEST_PATH_VAR = "/existing/path"
Add-PathPrefix -VarName "TEST_PATH_VAR" -NewPath "/new/path"
Assert-Equals "/new/path;/existing/path" $env:TEST_PATH_VAR

Test-Start "Add-PathPrefix does not duplicate existing path"
$env:TEST_PATH_VAR = "/existing/path"
Add-PathPrefix -VarName "TEST_PATH_VAR" -NewPath "/existing/path"
Assert-Equals "/existing/path" $env:TEST_PATH_VAR

# Cleanup
$env:TEST_PATH_VAR = $null

# =============================================================================
# Test: Test-PortAvailable Function
# =============================================================================

Test-Start "Test-PortAvailable function exists"
if (Get-Command Test-PortAvailable -ErrorAction SilentlyContinue) {
    Test-Pass
} else {
    Test-Fail "Function not defined"
}

Test-Start "Test-PortAvailable returns false for closed port"
$result = Test-PortAvailable -RemoteHost "localhost" -Port 59999 -Timeout 500
Assert-False $result "Expected false for closed port"

# =============================================================================
# Test: New-SymbolicLinkSafe Function
# =============================================================================

Test-Start "New-SymbolicLinkSafe function exists"
if (Get-Command New-SymbolicLinkSafe -ErrorAction SilentlyContinue) {
    Test-Pass
} else {
    Test-Fail "Function not defined"
}

# =============================================================================
# Test: Test-RequiredArg Function
# =============================================================================

Test-Start "Test-RequiredArg returns true for defined variable"
$env:TEST_DEFINED_VAR = "hello"
$result = Test-RequiredArg -VarName "TEST_DEFINED_VAR"
Assert-True $result

Test-Start "Test-RequiredArg returns false for undefined variable"
$env:TEST_UNDEFINED_VAR = $null
$result = Test-RequiredArg -VarName "TEST_UNDEFINED_VAR"
Assert-False $result

Test-Start "Test-RequiredArg returns false for empty variable"
$env:TEST_EMPTY_VAR = ""
$result = Test-RequiredArg -VarName "TEST_EMPTY_VAR"
Assert-False $result

Test-Start "Test-RequiredArg -Value returns true for non-empty value"
$result = Test-RequiredArg -Value "somevalue"
Assert-True $result

Test-Start "Test-RequiredArg -Value returns false for empty value"
$result = Test-RequiredArg -Value ""
Assert-False $result

# Cleanup
$env:TEST_DEFINED_VAR = $null
$env:TEST_UNDEFINED_VAR = $null
$env:TEST_EMPTY_VAR = $null

# =============================================================================
# Test: Hash Functions
# =============================================================================

Test-Start "Get-HashSum function exists"
if (Get-Command Get-HashSum -ErrorAction SilentlyContinue) {
    Test-Pass
} else {
    Test-Fail "Function not defined"
}

Test-Start "md5sum function exists"
if (Get-Command md5sum -ErrorAction SilentlyContinue) {
    Test-Pass
} else {
    Test-Fail "Function not defined"
}

Test-Start "sha256sum function exists"
if (Get-Command sha256sum -ErrorAction SilentlyContinue) {
    Test-Pass
} else {
    Test-Fail "Function not defined"
}

# Test actual hash computation
Test-Start "Get-HashSum computes correct MD5 hash"
$tempFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tempFile -Value "test content" -NoNewline
$result = Get-HashSum -Algorithm MD5 $tempFile
if ($result -match "^[a-f0-9]{32}\s+") {
    Test-Pass
} else {
    Test-Fail "Invalid hash format: $result"
}
Remove-Item $tempFile -Force

# =============================================================================
# Test: Unix-style Aliases
# =============================================================================

Test-Start "Alias 'which' exists"
if (Get-Alias which -ErrorAction SilentlyContinue) {
    Test-Pass
} else {
    Test-Fail "Alias not defined"
}

Test-Start "Alias 'log_err' maps to Write-LogError"
$alias = Get-Alias log_err -ErrorAction SilentlyContinue
if ($alias -and $alias.Definition -eq "Write-LogError") {
    Test-Pass
} else {
    Test-Fail "Alias not properly mapped"
}

Test-Start "Alias 'real_dir' maps to Get-RealDir"
$alias = Get-Alias real_dir -ErrorAction SilentlyContinue
if ($alias -and $alias.Definition -eq "Get-RealDir") {
    Test-Pass
} else {
    Test-Fail "Alias not properly mapped"
}

Test-Start "Alias 'prepend_path' maps to Add-PathPrefix"
$alias = Get-Alias prepend_path -ErrorAction SilentlyContinue
if ($alias -and $alias.Definition -eq "Add-PathPrefix") {
    Test-Pass
} else {
    Test-Fail "Alias not properly mapped"
}

Test-Start "Alias 'require_arg' maps to Test-RequiredArg"
$alias = Get-Alias require_arg -ErrorAction SilentlyContinue
if ($alias -and $alias.Definition -eq "Test-RequiredArg") {
    Test-Pass
} else {
    Test-Fail "Alias not properly mapped"
}

# =============================================================================
# Test: Move-CondaEnv Function
# =============================================================================

Test-Start "Move-CondaEnv function exists"
if (Get-Command Move-CondaEnv -ErrorAction SilentlyContinue) {
    Test-Pass
} else {
    Test-Fail "Function not defined"
}

# =============================================================================
# Test: Test-UserExist Function
# =============================================================================

Test-Start "Test-UserExist function exists"
if (Get-Command Test-UserExist -ErrorAction SilentlyContinue) {
    Test-Pass
} else {
    Test-Fail "Function not defined"
}

# =============================================================================
# Print Summary
# =============================================================================

$exitCode = Test-Summary
exit $exitCode
