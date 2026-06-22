#====================================================
# Git.ps1
# Git Functions
#====================================================

$ErrorActionPreference = "Stop"

#----------------------------------------------------
# Execute Git Command
#----------------------------------------------------
function Invoke-Git {

    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $displayArguments = $Arguments | ForEach-Object {
        if ($_ -match '\s') {
            '"' + $_.Replace('"', '\"') + '"'
        }
        else {
            $_
        }
    }

    $command = "git " + ($displayArguments -join " ")

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor DarkGray
    Write-Host $command -ForegroundColor Yellow
    Write-Host "==================================================" -ForegroundColor DarkGray

    $start = Get-Date

    $output = & $script:GitExe @Arguments 2>&1
    $exitCode = $LASTEXITCODE

    foreach($line in $output){
        Write-Host $line
    }

    $elapsed = (Get-Date) - $start

    Write-Host ("Completed ({0:N2} sec)" -f $elapsed.TotalSeconds) -ForegroundColor Green

    if($exitCode -ne 0){
        throw ($output -join "`n")
    }

    return @($output)
}

#----------------------------------------------------
# Execute Git Command (Return String)
#----------------------------------------------------
function Invoke-GitOutput {

    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $result = @(Invoke-Git $Arguments)

    $script:LastGitExitCode = $LASTEXITCODE

    return ($result | Out-String).Trim()

}

#----------------------------------------------------
# Current Branch
#----------------------------------------------------
function Get-CurrentBranch {

    $branch = Invoke-GitOutput @(
        "rev-parse",
        "--abbrev-ref",
        "HEAD"
    )

    return $branch.Trim()

}

#----------------------------------------------------
# Current Commit
#----------------------------------------------------
function Get-HeadCommitHash {

    return Invoke-GitOutput @(
        "rev-parse",
        "--short",
        "HEAD"
    )

}

#----------------------------------------------------
# Ensure Feature Branch
#----------------------------------------------------
function Ensure-FeatureBranch {

    param(

        [Parameter(Mandatory)]
        [string]$FeaturePrefix

    )

    $branch = Get-CurrentBranch

    Write-Host ""
    Write-Host "Current Branch : $branch"

    if(!$branch.StartsWith($FeaturePrefix))
    {

        throw "現在のブランチはFeatureではありません。"

    }

}

#----------------------------------------------------
# Working Tree Clean ?
#----------------------------------------------------
function Ensure-CleanWorkingTree {

    $status = Invoke-GitOutput @(
        "status",
        "--porcelain"
    )

    if($status)
    {

        throw @"

未コミットの変更があります。

$status

"@

    }

}

#----------------------------------------------------
# Local Branch Exists
#----------------------------------------------------
function Test-LocalBranchExists {

    param(

        [Parameter(Mandatory)]
        [string]$Branch

    )

    cmd /c "`"$script:GitExe`" show-ref --verify --quiet refs/heads/$Branch"

    return ($LASTEXITCODE -eq 0)

}

#----------------------------------------------------
# Remote Branch Exists
#----------------------------------------------------
function Test-RemoteBranchExists {

    param(

        [Parameter(Mandatory)]
        [string]$Remote,

        [Parameter(Mandatory)]
        [string]$Branch

    )

    $result = Invoke-GitOutput @(
        "ls-remote"
        "--heads"
        $Remote
        $Branch
    )

    return (-not [string]::IsNullOrWhiteSpace($result))

}

#----------------------------------------------------
# Local Tag Exists
#----------------------------------------------------
function Test-LocalTagExists {

    param(

        [Parameter(Mandatory)]
        [string]$Tag

    )

    cmd /c "`"$script:GitExe`" show-ref --verify --quiet refs/tags/$Tag"

    return ($LASTEXITCODE -eq 0)

}

#----------------------------------------------------
# Remote Tag Exists
#----------------------------------------------------
function Test-RemoteTagExists {

    param(

        [Parameter(Mandatory)]
        [string]$Remote,

        [Parameter(Mandatory)]
        [string]$Tag

    )

    $result = Invoke-GitOutput @(
        "ls-remote",
        "--tags",
        $Remote,
        $Tag
    )

    return (-not [string]::IsNullOrWhiteSpace($result))

}

#----------------------------------------------------
# Fetch
#----------------------------------------------------
function Fetch-Remote {

    param(
        [string]$Remote = "origin"
    )

    $null = Invoke-Git @(
        "fetch",
        $Remote
    )

}

#----------------------------------------------------
# Checkout
#----------------------------------------------------
function Checkout-Branch {

    param(
        [Parameter(Mandatory)]
        [string]$Branch
    )

    if((Get-CurrentBranch) -eq $Branch){
        return
    }

    $null = Invoke-Git @(
        "checkout",
        $Branch
    )
}

#----------------------------------------------------
# Pull
#----------------------------------------------------
function Pull-Remote {

    param(
        [Parameter(Mandatory)]
        [string]$Branch,

        [string]$Remote = "origin"
    )

    if((Get-CurrentBranch) -ne $Branch){
        Checkout-Branch $Branch
    }

    $null = Invoke-Git @(
        "pull",
        $Remote,
        $Branch
    )
}

#----------------------------------------------------
# Create Release Branch
#----------------------------------------------------
function Create-ReleaseBranch {

    param(

        [Parameter(Mandatory)]
        [string]$ReleaseBranch,

        [string]$Remote = "origin",

        [string]$MainBranch = "master"

    )

    if(Test-LocalBranchExists $ReleaseBranch){

        throw "ローカルブランチが既に存在します。`n$ReleaseBranch"

    }

    if(Test-RemoteBranchExists $Remote $ReleaseBranch){

        throw "リモートブランチが既に存在します。`n$Remote/$ReleaseBranch"

    }

    $null = Invoke-Git @(
        "checkout",
        "-b",
        $ReleaseBranch,
        "$Remote/$MainBranch"
    )

}

#----------------------------------------------------
# Replace Current Branch By Remote Main Branch
#----------------------------------------------------
function Replace-ByRemoteMainBranch {

    param(
        [string]$Remote = "origin",

        [string]$MainBranch = "master"
    )

    $null = Invoke-Git @(
        "checkout",
        "$Remote/$MainBranch",
        "--",
        "."
    )

}

function Rebase-ReleaseBranch {

    param(
        [Parameter(Mandatory)]
        [string]$ReleaseBranch,

        [string]$Remote = "origin",

        [string]$MainBranch = "master"
    )

    Checkout-Branch $ReleaseBranch

    $null = Invoke-Git @(
        "rebase",
        "$Remote/$MainBranch"
    )

}

#----------------------------------------------------
# Commit If Needed
#----------------------------------------------------
function Commit-IfNeeded {

    param(

        [Parameter(Mandatory)]
        [string]$CommitMessage

    )

    $status = Invoke-GitOutput @(
        "status",
        "--porcelain"
    )

    if([string]::IsNullOrWhiteSpace($status)){

        Write-Host ""
        Write-Host "No changes. Commit skipped." -ForegroundColor Yellow

        return $false

    }

    $null = Invoke-Git @(
        "add",
        "."
    )

    $null = Invoke-Git @(
        "commit",
        "-m",
        $CommitMessage
    )

    return $true

}

#----------------------------------------------------
# Push Master
#----------------------------------------------------
function Push-MainBranch {

    param(

        [Parameter(Mandatory)]
        [string]$ReleaseBranch,

        [string]$Remote = "origin",

        [string]$MainBranch = "master"

    )

    Write-Host ""
    Write-Host "Push"
    Write-Host " Local  : $ReleaseBranch"
    Write-Host " Remote : $Remote/$MainBranch"
    Write-Host ""

    $null = Invoke-Git @(
        "push",
        $Remote,
        "${ReleaseBranch}:$MainBranch"
    )

}

#----------------------------------------------------
# Abort Rebase
#----------------------------------------------------
function Abort-Rebase {

    $null = Invoke-Git @(
        "rebase",
        "--abort"
    )

}

#----------------------------------------------------
# Abort Merge
#----------------------------------------------------
function Abort-Merge {

    $null = Invoke-Git @(
        "merge",
        "--abort"
    )

}

#----------------------------------------------------
# Is Working Tree Clean
#----------------------------------------------------
function Test-WorkingTreeClean {

    $status = Invoke-GitOutput @(
        "status",
        "--porcelain"
    )

    return [string]::IsNullOrWhiteSpace($status)

}

#----------------------------------------------------
# Get Current HEAD
#----------------------------------------------------
function Get-HeadHash {

    return Invoke-GitOutput @(
        "rev-parse",
        "--short",
        "HEAD"
    )

}

#----------------------------------------------------
# Create Release Tag
#----------------------------------------------------
function Create-ReleaseTag {

    param(

        [Parameter(Mandatory)]
        [string]$TagName,

        [Parameter(Mandatory)]
        [string]$Message,

        [string]$Remote = "origin"

    )

    if(Test-LocalTagExists $TagName){

        throw "ローカルタグが既に存在します。`n$TagName"

    }

    if(Test-RemoteTagExists $Remote $TagName){

        throw "リモートタグが既に存在します。`n$Remote/$TagName"

    }

    $null = Invoke-Git @(
        "tag",
        "-a",
        $TagName,
        "-m",
        $Message
    )

}

#----------------------------------------------------
# Push Release Tag
#----------------------------------------------------
function Push-ReleaseTag {

    param(

        [Parameter(Mandatory)]
        [string]$TagName,

        [string]$Remote = "origin"

    )

    $null = Invoke-Git @(
        "push",
        $Remote,
        $TagName
    )

}

#----------------------------------------------------
# Delete Local Branch
#----------------------------------------------------
function Remove-LocalBranch {

    param(

        [Parameter(Mandatory)]
        [string]$Branch

    )

    $null = Invoke-Git @(
        "branch",
        "-D",
        $Branch
    )

}

#----------------------------------------------------
# Delete Remote Branch
#----------------------------------------------------
function Remove-RemoteBranch {

    param(

        [Parameter(Mandatory)]
        [string]$Branch,

        [string]$Remote = "origin"

    )

    $null = Invoke-Git @(
        "push",
        $Remote,
        "--delete",
        $Branch
    )

}

#----------------------------------------------------
# Delete Local Tag
#----------------------------------------------------
function Remove-LocalTag {

    param(

        [Parameter(Mandatory)]
        [string]$Tag

    )

    $null = Invoke-Git @(
        "tag",
        "-d",
        $Tag
    )

}

#----------------------------------------------------
# Delete Remote Tag
#----------------------------------------------------
function Remove-RemoteTag {

    param(

        [Parameter(Mandatory)]
        [string]$Tag,

        [string]$Remote = "origin"

    )

    $null = Invoke-Git @(
        "push",
        $Remote,
        "--delete",
        $Tag
    )

}

#----------------------------------------------------
# Last Commit Message
#----------------------------------------------------
function Get-LastCommitMessage {

    Invoke-GitOutput @(
        "log",
        "-1",
        "--pretty=%B"
    )

}

#----------------------------------------------------
# Repository Root
#----------------------------------------------------
function Get-RepositoryRoot {

    Invoke-GitOutput @(
        "rev-parse",
        "--show-toplevel"
    )

}

#----------------------------------------------------
# Current Remote URL
#----------------------------------------------------
function Get-RemoteUrl {

    param(

        [string]$Remote="origin"

    )

    Invoke-GitOutput @(
        "remote",
        "get-url",
        $Remote
    )

}

#----------------------------------------------------
# Git Version
#----------------------------------------------------
function Show-GitVersion {

    Invoke-Git @(
        "--version"
    )

}

#----------------------------------------------------
# Current Status
#----------------------------------------------------
function Show-GitStatus {

    Invoke-Git @(
        "status"
    )

}

#----------------------------------------------------
# Current Log
#----------------------------------------------------
function Show-GitLog {

    Invoke-Git @(
        "log",
        "--oneline",
        "-5"
    )

}

#----------------------------------------------------
# Verify Repository
#----------------------------------------------------
function Verify-Repository {

    try{

        Get-RepositoryRoot | Out-Null

    }
    catch{

        throw "Git Repositoryではありません。"

    }

}

#----------------------------------------------------
# Finish Banner
#----------------------------------------------------
function Show-ReleaseResult {

    param(

        [string]$Project,

        [string]$Version,

        [string]$Branch,

        [string]$Tag

    )

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host " Release Complete"
    Write-Host "==========================================" -ForegroundColor Green

    Write-Host ""
    Write-Host "Project        : $Project"
    Write-Host "Version        : $Version"
    Write-Host "Branch         : $Branch"
    Write-Host "Tag            : $Tag"
    Write-Host "Commit         : $(Get-HeadCommitHash)"
    Write-Host ""

}
