#==========================
# Start Transcript Log
#==========================

$ErrorActionPreference = "Stop"

$config = Get-Content "$PSScriptRoot\Config.json" | ConvertFrom-Json

if ([System.IO.Path]::IsPathRooted($config.LogDirectory)) {
    $logDir = $config.LogDirectory
}
else {
    $logDir = Join-Path $PSScriptRoot $config.LogDirectory
}

if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

$logName = "Release_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss")
$logFile = Join-Path $logDir $logName

Start-Transcript -Path $logFile -Force

#====================================================
# Release.ps1
# Release Tool Ver1.0
#====================================================

try {

    #----------------------------------------------------
    # Load Modules
    #----------------------------------------------------
    . "$PSScriptRoot\Git.ps1"
    . "$PSScriptRoot\Utils.ps1"

    $script:GitExe = $config.GitExe
    $remote = $config.Remote
    $mainBranch = $config.MainBranch

    #----------------------------------------------------
    # Show Title
    #----------------------------------------------------
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "        Release Tool Ver1.0"
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""

    #----------------------------------------------------
    # Input Project
    #----------------------------------------------------
    $project = Read-Host "Project Name (ex:sample)"

    if ([string]::IsNullOrWhiteSpace($project)) {
        throw "Project Name is empty."
    }

    if (-not $config.Projects.PSObject.Properties.Name.Contains($project)) {
        throw "Project '$project' does not exist in Config.json."
    }

    $repository = $config.Projects.$project

    Write-Host ""
    Write-Host "Repository : $repository"

    if (!(Test-Path $repository)) {
        throw "Repository does not exist.`n$repository"
    }

    Set-Location $repository

    #----------------------------------------------------
    # Verify Repository
    #----------------------------------------------------
    Verify-Repository

    Ensure-CleanWorkingTree

    Ensure-FeatureBranch $config.FeaturePrefix

    #----------------------------------------------------
    # Input Version
    #----------------------------------------------------
    $version = Read-Host "Version (ex:1.0.0)"

    if ([string]::IsNullOrWhiteSpace($version)) {
        throw "Version is empty."
    }

    if (!(Test-Version $version)) {
        throw "Version format error. ex) 1.0.0"
    }

    $releaseBranch = "$($config.ReleaseBranchPrefix)-$project-$version"
    $releaseTag = "$($config.ReleaseTagPrefix)-$project-$version"

    Write-Host ""
    Write-Host "Release Branch : $releaseBranch"
    Write-Host "Release Tag    : $releaseTag"
    Write-Host ""

    Write-Host "Flow:"
    Write-Host "  STEP1  Feature Pull"
    Write-Host "  STEP2  Fetch Remote"
    Write-Host "  STEP3  Create Release Branch from $remote/$mainBranch"
    Write-Host "  STEP4  Replace by $remote/$mainBranch"
    Write-Host "  STEP5  Commit if needed"
    Write-Host "  STEP6  Rebase $remote/$mainBranch"
    Write-Host "  STEP7  Push RB -> Remote $mainBranch"
    Write-Host "  STEP8  Create Tag"
    Write-Host "  STEP9  Push Tag"

    $answer = Read-Host "Continue ? (Y/N)"

    if ($answer.ToUpper() -ne "Y") {
        Write-Host "Canceled."
        return
    }

    #----------------------------------------------------
    # STEP1 Feature Pull
    #----------------------------------------------------
    Write-Step "STEP1 Feature Pull"

    $currentBranch = Get-CurrentBranch
    Pull-Remote `
        -Branch $currentBranch `
        -Remote $remote

    #----------------------------------------------------
    # STEP2 Fetch Remote
    #----------------------------------------------------
    Write-Step "STEP2 Fetch Remote"

    Fetch-Remote $remote

    #----------------------------------------------------
    # STEP3 Create Release Branch
    #----------------------------------------------------
    Write-Step "STEP3 Create Release Branch"

    Create-ReleaseBranch `
        -ReleaseBranch $releaseBranch `
        -Remote $remote `
        -MainBranch $mainBranch

    #----------------------------------------------------
    # STEP4 Replace by Remote Main Branch
    #----------------------------------------------------
    Write-Step "STEP4 Replace by $remote/$mainBranch"

    Replace-ByRemoteMainBranch `
        -Remote $remote `
        -MainBranch $mainBranch

    #----------------------------------------------------
    # STEP5 Commit
    #----------------------------------------------------
    Write-Step "STEP5 Commit"

    $committed = Commit-IfNeeded $config.CommitMessage

    #----------------------------------------------------
    # STEP6 Rebase
    #----------------------------------------------------
    Write-Step "STEP6 Rebase"

    Rebase-ReleaseBranch `
        -ReleaseBranch $releaseBranch `
        -Remote $remote `
        -MainBranch $mainBranch

    #----------------------------------------------------
    # STEP7 Push Release Branch to Remote Main Branch
    #----------------------------------------------------
    Write-Step "STEP7 Push Release Branch to remote $mainBranch"
    Write-Host ""
    Write-Host "===================================="
    Write-Host "Local Branch : $releaseBranch"
    Write-Host "Remote       : $remote/$mainBranch"
    Write-Host "===================================="
    Write-Host ""

    Write-Host "The following command will be executed."
    Write-Host ""
    Write-Host "git push $remote ${releaseBranch}:$mainBranch"
    Write-Host ""

    $pushAnswer = Read-Host "Push to remote $mainBranch ? (Y/N)"

    if ($pushAnswer.ToUpper() -ne "Y") {
        throw "Push $mainBranch canceled."
    }

    Push-MainBranch `
        -ReleaseBranch $releaseBranch `
        -Remote $remote `
        -MainBranch $mainBranch

    #----------------------------------------------------
    # STEP8 Create Tag
    #----------------------------------------------------
    Write-Step "STEP8 Create Tag"

    Create-ReleaseTag `
        -TagName $releaseTag `
        -Message $config.CommitMessage `
        -Remote $remote

    #----------------------------------------------------
    # STEP9 Push Tag
    #----------------------------------------------------
    Write-Step "STEP9 Push Tag"

    Push-ReleaseTag `
        -TagName $releaseTag `
        -Remote $remote

    #----------------------------------------------------
    # Show Result
    #----------------------------------------------------
    Show-ReleaseResult `
        -Project $project `
        -Version $version `
        -Branch $releaseBranch `
        -Tag $releaseTag

}
catch {

    Write-ErrorMessage $_

}
finally {

    Stop-Transcript

}
