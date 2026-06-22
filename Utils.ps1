#====================================================
# Utils.ps1
# Common Utility Functions
#====================================================

#----------------------------------------------------
# Info
#----------------------------------------------------
function Write-Info {
    param(
        [string]$Message
    )

    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

#----------------------------------------------------
# Success
#----------------------------------------------------
function Write-Success {
    param(
        [string]$Message
    )

    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

#----------------------------------------------------
# Warning
#----------------------------------------------------
function Write-WarningMessage {
    param(
        [string]$Message
    )

    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

#----------------------------------------------------
# Error
#----------------------------------------------------
function Write-ErrorMessage {
    param(
        [string]$Message
    )

    Write-Host ""
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    Write-Host ""
}

#----------------------------------------------------
# Step
#----------------------------------------------------
function Write-Step {
    param(
        [string]$Title
    )

    Write-Host ""
    Write-Host "===================================================" -ForegroundColor DarkCyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor DarkCyan
    Write-Host ""
}

#----------------------------------------------------
# Pause
#----------------------------------------------------
function Pause-Step {
    param(
        [string]$Message = "Press ENTER to continue..."
    )

    Write-Host ""
    Read-Host $Message
}

#----------------------------------------------------
# Yes / No
#----------------------------------------------------
function Confirm-YesNo {

    param(
        [string]$Message
    )

    while ($true) {

        $ans = Read-Host "$Message (Y/N)"

        switch ($ans.ToUpper()) {

            "Y" { return $true }

            "N" { return $false }

            default {

                Write-WarningMessage "Please input Y or N."

            }

        }

    }

}

#----------------------------------------------------
# Input Required
#----------------------------------------------------
function Read-RequiredInput {

    param(

        [string]$Title

    )

    while ($true) {

        $value = Read-Host $Title

        if (![string]::IsNullOrWhiteSpace($value)) {

            return $value.Trim()

        }

        Write-WarningMessage "$Title is required."

    }

}

#----------------------------------------------------
# Validate Version
# ex)
# 1.0.0
# 1.0.15
#----------------------------------------------------
function Test-Version {

    param(

        [string]$Version,

        [string]$Pattern = '^\d+\.\d+\.\d+$'

    )

    return ($Version -match $Pattern)

}

#----------------------------------------------------
# Resolve Configured Path
#----------------------------------------------------
function Resolve-ConfiguredPath {

    param(

        [Parameter(Mandatory)]
        [string]$Path,

        [string]$BasePath = $PSScriptRoot

    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path $BasePath $Path

}

#----------------------------------------------------
# Get Config Boolean
#----------------------------------------------------
function Get-ConfigBoolean {

    param(

        [object]$Config,

        [Parameter(Mandatory)]
        [string]$Name,

        [bool]$Default = $false

    )

    if ($null -eq $Config) {
        return $Default
    }

    $property = $Config.PSObject.Properties[$Name]

    if ($null -eq $property -or $null -eq $property.Value) {
        return $Default
    }

    return [bool]$property.Value

}

#----------------------------------------------------
# Write Release Note
#----------------------------------------------------
function New-ReleaseNote {

    param(

        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter(Mandatory)]
        [string]$Project,

        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [string]$Branch,

        [Parameter(Mandatory)]
        [string]$Tag,

        [Parameter(Mandatory)]
        [string]$CommitMessage,

        [Parameter(Mandatory)]
        [string]$Remote,

        [Parameter(Mandatory)]
        [string]$MainBranch,

        [string]$CommitHash

    )

    if (!(Test-Path $Directory)) {
        New-Item -ItemType Directory -Path $Directory | Out-Null
    }

    $fileName = "{0}_{1}.md" -f $Project, $Version
    $filePath = Join-Path $Directory $fileName
    $createdAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $content = @"
# Release Note

| Item | Value |
| --- | --- |
| Project | $Project |
| Version | $Version |
| Branch | $Branch |
| Tag | $Tag |
| Commit | $CommitHash |
| Remote | $Remote |
| Main Branch | $MainBranch |
| Commit Message | $CommitMessage |
| Created At | $createdAt |

## Summary

- Release branch and tag were created by the PowerShell Git Release Automation Tool.
- Update this section with release highlights before publishing externally.

"@

    Set-Content -LiteralPath $filePath -Value $content -Encoding UTF8

    return $filePath

}

#----------------------------------------------------
# Print Summary
#----------------------------------------------------
function Show-ReleaseSummary {

    param(

        [string]$Project,

        [string]$Version,

        [string]$ReleaseBranch,

        [string]$ReleaseTag,

        [string]$CommitMessage

    )

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " Release Summary"
    Write-Host "==========================================" -ForegroundColor Cyan

    Write-Host ""
    Write-Host " Project         : $Project"
    Write-Host " Version         : $Version"
    Write-Host " Release Branch  : $ReleaseBranch"
    Write-Host " Release Tag     : $ReleaseTag"
    Write-Host " Commit Message  : $CommitMessage"
    Write-Host ""

}

#----------------------------------------------------
# Log Directory
#----------------------------------------------------
function Initialize-Log {

    param(
        [string]$LogDirectory = "Log"
    )

    if ([System.IO.Path]::IsPathRooted($LogDirectory)) {
        $dir = $LogDirectory
    }
    else {
        $dir = Join-Path $PSScriptRoot $LogDirectory
    }

    if (!(Test-Path $dir)) {

        New-Item `
            -ItemType Directory `
            -Path $dir | Out-Null

    }

    $time = Get-Date -Format "yyyyMMdd_HHmmss"

    $Global:LogFile = Join-Path $dir "$time.log"

}

#----------------------------------------------------
# Write Log
#----------------------------------------------------
function Write-Log {

    param(

        [string]$Message

    )

    if ($Global:LogFile) {

        Add-Content `
            -Path $Global:LogFile `
            -Value "$(Get-Date -Format 'yyyy/MM/dd HH:mm:ss')  $Message"

    }

}

#----------------------------------------------------
# Execute With Log
#----------------------------------------------------
function Invoke-Step {

    param(

        [string]$Title,

        [scriptblock]$Action

    )

    Write-Step $Title
    Write-Log $Title

    try {

        & $Action

        Write-Success "$Title Completed"

        Write-Log "$Title Success"

    }
    catch {

        Write-ErrorMessage $_

        Write-Log $_

        throw

    }

}

#----------------------------------------------------
# Finish
#----------------------------------------------------
function Show-Finish {

    param(

        [string]$CommitHash

    )

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host " Release Complete"
    Write-Host "==========================================" -ForegroundColor Green

    Write-Host ""

    if ($CommitHash) {

        Write-Host " Commit : $CommitHash"

    }

    Write-Host ""

}
