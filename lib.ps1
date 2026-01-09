# lib for powershell

$LIBSHELL_DEFAULT_OK=0
$LIBSHELL_DEFAULT_ERR=1
$LIBSHELL_ARG_ERR=2
$LIBSHELL_SHELL_NOT_SUPPORTED=3
$LIBSHELL_CMD_NOT_FOUND=4
$LIBSHELL_FILE_EXISTED=5
$LIBSHELL_FILE_TYPE_ERR=6
$LIBSHELL_FILE_IO_ERR=7


function hashsum {
    <#
    .SYNOPSIS
        Calculate the hash of files.
    .PARAMETER Algorithm
        The hash algorithm to use. E.g. MD5, SHA256, SHA1, etc.
    .PARAMETER Files
        The files to calculate the hash of.
    .EXAMPLE
        hashsum -Algorithm SHA256 file1.txt file2.txt
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet('MD5', 'SHA1', 'SHA256', 'SHA384', 'SHA512')]
        [string]$Algorithm,

        [Parameter(ValueFromRemainingArguments = $true, Position = 1)]
        [string[]]$Files
    )

    if ( -not $Files -or $FIles.Count -eq 0) {
        Write-Error "Usage: hashsum -Algorithm <MD5|SHA1|SHA256|SHA384|SHA512> file1 [file2 ...]"
        return
    }

    foreach ($f in $Files) {
        if (Test-Path $f) {
            try{
                $hash = Get-FileHash -Path $f -Algorithm $Algorithm
                $hashstr = $hash.Hash.ToLower()
                Write-Output "$hashstr $f"
            } catch {
                Write-Error "hashsum: Failed to hash $f with $Algorithm"
            }
        } else {
            Write-Error: "hashsum: ${f}: No such file"
        }
    }
}


function md5sum {
    param (
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$FIles
    )
    hashsum -Algorithm MD5 @Files
}


function sha1sum {
    param (
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$FIles
    )
    hashsum -Algorithm SHA1 @Files
}


function sha256sum {
    param (
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$FIles
    )
    hashsum -Algorithm SHA256 @Files
}


function sha384sum {
    param (
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$FIles
    )
    hashsum -Algorithm SHA384 @Files
}


function sha512sum {
    param (
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$FIles
    )
    hashsum -Algorithm SHA512 @Files
}


Set-Alias which Get-Command
Set-Alias df Get-PSDrive
