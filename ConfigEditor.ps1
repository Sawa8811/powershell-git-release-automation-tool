param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "Config.json")
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Read-Config {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (!(Test-Path -LiteralPath $Path)) {
        throw "Config file does not exist: $Path"
    }

    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function ConvertTo-Boolean {
    param(
        [object]$Value,
        [bool]$Default = $false
    )

    if ($null -eq $Value) {
        return $Default
    }

    return [bool]$Value
}

function New-Label {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size(150, 22)
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    return $label
}

function New-TextBox {
    param(
        [int]$X,
        [int]$Y,
        [int]$Width = 390
    )

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point($X, $Y)
    $textBox.Size = New-Object System.Drawing.Size($Width, 24)
    return $textBox
}

function Set-TextValue {
    param(
        [System.Windows.Forms.TextBox]$TextBox,
        [object]$Value
    )

    if ($null -eq $Value) {
        $TextBox.Text = ""
        return
    }

    $TextBox.Text = [string]$Value
}

function Add-ProjectRows {
    param(
        [System.Windows.Forms.DataGridView]$Grid,
        [object]$Projects
    )

    $Grid.Rows.Clear()

    if ($null -eq $Projects) {
        return
    }

    foreach ($property in $Projects.PSObject.Properties) {
        [void]$Grid.Rows.Add($property.Name, [string]$property.Value)
    }
}

function Get-ProjectMap {
    param(
        [System.Windows.Forms.DataGridView]$Grid
    )

    $projects = [ordered]@{}

    foreach ($row in $Grid.Rows) {
        if ($row.IsNewRow) {
            continue
        }

        $name = [string]$row.Cells[0].Value
        $path = [string]$row.Cells[1].Value

        if ([string]::IsNullOrWhiteSpace($name) -and [string]::IsNullOrWhiteSpace($path)) {
            continue
        }

        if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($path)) {
            throw "Each project row must include both Project Name and Repository Path."
        }

        if ($projects.Contains($name)) {
            throw "Duplicate project name: $name"
        }

        $projects[$name.Trim()] = $path.Trim()
    }

    return $projects
}

function ConvertTo-ConfigJson {
    param(
        [hashtable]$Values
    )

    $config = [ordered]@{
        GitExe              = $Values.GitExe
        LogDirectory        = $Values.LogDirectory
        Remote              = $Values.Remote
        MainBranch          = $Values.MainBranch
        CommitMessage       = $Values.CommitMessage
        DefaultProject      = $Values.DefaultProject
        VersionPattern      = $Values.VersionPattern
        VersionExample      = $Values.VersionExample
        FeaturePrefix       = $Values.FeaturePrefix
        ReleaseBranchPrefix = $Values.ReleaseBranchPrefix
        ReleaseTagPrefix    = $Values.ReleaseTagPrefix
        DryRun              = $Values.DryRun
        ConfirmBeforePush   = $Values.ConfirmBeforePush
        ReleaseNotes        = [ordered]@{
            Enabled   = $Values.ReleaseNotesEnabled
            Directory = $Values.ReleaseNotesDirectory
        }
        Projects            = $Values.Projects
    }

    return $config | ConvertTo-Json -Depth 8
}

$config = Read-Config -Path $ConfigPath

$form = New-Object System.Windows.Forms.Form
$form.Text = "Release Tool Config Editor"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(760, 760)
$form.MinimumSize = New-Object System.Drawing.Size(760, 760)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(12, 12)
$tabs.Size = New-Object System.Drawing.Size(720, 650)
$tabs.Anchor = "Top, Bottom, Left, Right"

$generalTab = New-Object System.Windows.Forms.TabPage
$generalTab.Text = "General"

$optionsTab = New-Object System.Windows.Forms.TabPage
$optionsTab.Text = "Options"

$projectsTab = New-Object System.Windows.Forms.TabPage
$projectsTab.Text = "Projects"

[void]$tabs.TabPages.Add($generalTab)
[void]$tabs.TabPages.Add($optionsTab)
[void]$tabs.TabPages.Add($projectsTab)

$textBoxes = @{}

$generalFields = @(
    @{ Name = "GitExe"; Label = "Git Executable"; Y = 24 },
    @{ Name = "LogDirectory"; Label = "Log Directory"; Y = 64 },
    @{ Name = "Remote"; Label = "Remote"; Y = 104 },
    @{ Name = "MainBranch"; Label = "Main Branch"; Y = 144 },
    @{ Name = "CommitMessage"; Label = "Commit Message"; Y = 184 },
    @{ Name = "DefaultProject"; Label = "Default Project"; Y = 224 }
)

foreach ($field in $generalFields) {
    $generalTab.Controls.Add((New-Label -Text $field.Label -X 18 -Y $field.Y))
    $box = New-TextBox -X 180 -Y $field.Y -Width 430
    $textBoxes[$field.Name] = $box
    $generalTab.Controls.Add($box)
}

$browseGitButton = New-Object System.Windows.Forms.Button
$browseGitButton.Text = "Browse"
$browseGitButton.Location = New-Object System.Drawing.Point(620, 22)
$browseGitButton.Size = New-Object System.Drawing.Size(74, 28)
$generalTab.Controls.Add($browseGitButton)

$browseLogButton = New-Object System.Windows.Forms.Button
$browseLogButton.Text = "Browse"
$browseLogButton.Location = New-Object System.Drawing.Point(620, 62)
$browseLogButton.Size = New-Object System.Drawing.Size(74, 28)
$generalTab.Controls.Add($browseLogButton)

$optionFields = @(
    @{ Name = "VersionPattern"; Label = "Version Pattern"; Y = 24 },
    @{ Name = "VersionExample"; Label = "Version Example"; Y = 64 },
    @{ Name = "FeaturePrefix"; Label = "Feature Prefix"; Y = 104 },
    @{ Name = "ReleaseBranchPrefix"; Label = "Release Branch Prefix"; Y = 144 },
    @{ Name = "ReleaseTagPrefix"; Label = "Release Tag Prefix"; Y = 184 },
    @{ Name = "ReleaseNotesDirectory"; Label = "Release Notes Directory"; Y = 304 }
)

foreach ($field in $optionFields) {
    $optionsTab.Controls.Add((New-Label -Text $field.Label -X 18 -Y $field.Y))
    $box = New-TextBox -X 190 -Y $field.Y -Width 420
    $textBoxes[$field.Name] = $box
    $optionsTab.Controls.Add($box)
}

$dryRunCheckBox = New-Object System.Windows.Forms.CheckBox
$dryRunCheckBox.Text = "Dry run by default"
$dryRunCheckBox.Location = New-Object System.Drawing.Point(190, 224)
$dryRunCheckBox.Size = New-Object System.Drawing.Size(250, 24)
$optionsTab.Controls.Add($dryRunCheckBox)

$confirmPushCheckBox = New-Object System.Windows.Forms.CheckBox
$confirmPushCheckBox.Text = "Confirm before pushing to main branch"
$confirmPushCheckBox.Location = New-Object System.Drawing.Point(190, 254)
$confirmPushCheckBox.Size = New-Object System.Drawing.Size(330, 24)
$optionsTab.Controls.Add($confirmPushCheckBox)

$releaseNotesCheckBox = New-Object System.Windows.Forms.CheckBox
$releaseNotesCheckBox.Text = "Generate release notes"
$releaseNotesCheckBox.Location = New-Object System.Drawing.Point(190, 284)
$releaseNotesCheckBox.Size = New-Object System.Drawing.Size(250, 24)
$optionsTab.Controls.Add($releaseNotesCheckBox)

$projectGrid = New-Object System.Windows.Forms.DataGridView
$projectGrid.Location = New-Object System.Drawing.Point(18, 18)
$projectGrid.Size = New-Object System.Drawing.Size(670, 540)
$projectGrid.Anchor = "Top, Bottom, Left, Right"
$projectGrid.AllowUserToAddRows = $true
$projectGrid.AllowUserToDeleteRows = $true
$projectGrid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
$projectGrid.RowHeadersWidth = 28

$projectNameColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$projectNameColumn.HeaderText = "Project Name"
$projectNameColumn.FillWeight = 35

$projectPathColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$projectPathColumn.HeaderText = "Repository Path"
$projectPathColumn.FillWeight = 65

[void]$projectGrid.Columns.Add($projectNameColumn)
[void]$projectGrid.Columns.Add($projectPathColumn)
$projectsTab.Controls.Add($projectGrid)

$validateButton = New-Object System.Windows.Forms.Button
$validateButton.Text = "Validate"
$validateButton.Location = New-Object System.Drawing.Point(360, 678)
$validateButton.Size = New-Object System.Drawing.Size(88, 32)
$validateButton.Anchor = "Bottom, Right"

$reloadButton = New-Object System.Windows.Forms.Button
$reloadButton.Text = "Reload"
$reloadButton.Location = New-Object System.Drawing.Point(454, 678)
$reloadButton.Size = New-Object System.Drawing.Size(88, 32)
$reloadButton.Anchor = "Bottom, Right"

$saveButton = New-Object System.Windows.Forms.Button
$saveButton.Text = "Save"
$saveButton.Location = New-Object System.Drawing.Point(548, 678)
$saveButton.Size = New-Object System.Drawing.Size(88, 32)
$saveButton.Anchor = "Bottom, Right"

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "Close"
$closeButton.Location = New-Object System.Drawing.Point(642, 678)
$closeButton.Size = New-Object System.Drawing.Size(88, 32)
$closeButton.Anchor = "Bottom, Right"

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Config: $ConfigPath"
$statusLabel.Location = New-Object System.Drawing.Point(14, 680)
$statusLabel.Size = New-Object System.Drawing.Size(330, 28)
$statusLabel.Anchor = "Bottom, Left"
$statusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

$form.Controls.Add($tabs)
$form.Controls.Add($statusLabel)
$form.Controls.Add($validateButton)
$form.Controls.Add($reloadButton)
$form.Controls.Add($saveButton)
$form.Controls.Add($closeButton)

function Set-FormValues {
    param(
        [object]$Source
    )

    Set-TextValue -TextBox $textBoxes.GitExe -Value $Source.GitExe
    Set-TextValue -TextBox $textBoxes.LogDirectory -Value $Source.LogDirectory
    Set-TextValue -TextBox $textBoxes.Remote -Value $Source.Remote
    Set-TextValue -TextBox $textBoxes.MainBranch -Value $Source.MainBranch
    Set-TextValue -TextBox $textBoxes.CommitMessage -Value $Source.CommitMessage
    Set-TextValue -TextBox $textBoxes.DefaultProject -Value $Source.DefaultProject
    Set-TextValue -TextBox $textBoxes.VersionPattern -Value $Source.VersionPattern
    Set-TextValue -TextBox $textBoxes.VersionExample -Value $Source.VersionExample
    Set-TextValue -TextBox $textBoxes.FeaturePrefix -Value $Source.FeaturePrefix
    Set-TextValue -TextBox $textBoxes.ReleaseBranchPrefix -Value $Source.ReleaseBranchPrefix
    Set-TextValue -TextBox $textBoxes.ReleaseTagPrefix -Value $Source.ReleaseTagPrefix

    $dryRunCheckBox.Checked = ConvertTo-Boolean -Value $Source.DryRun
    $confirmPushCheckBox.Checked = ConvertTo-Boolean -Value $Source.ConfirmBeforePush -Default $true

    if ($Source.ReleaseNotes) {
        $releaseNotesCheckBox.Checked = ConvertTo-Boolean -Value $Source.ReleaseNotes.Enabled
        Set-TextValue -TextBox $textBoxes.ReleaseNotesDirectory -Value $Source.ReleaseNotes.Directory
    }
    else {
        $releaseNotesCheckBox.Checked = $false
        Set-TextValue -TextBox $textBoxes.ReleaseNotesDirectory -Value ".\ReleaseNotes"
    }

    Add-ProjectRows -Grid $projectGrid -Projects $Source.Projects
}

function Get-FormValues {
    $projects = Get-ProjectMap -Grid $projectGrid

    if ([string]::IsNullOrWhiteSpace($textBoxes.GitExe.Text)) {
        throw "Git Executable is required."
    }

    if ([string]::IsNullOrWhiteSpace($textBoxes.Remote.Text)) {
        throw "Remote is required."
    }

    if ([string]::IsNullOrWhiteSpace($textBoxes.MainBranch.Text)) {
        throw "Main Branch is required."
    }

    if ([string]::IsNullOrWhiteSpace($textBoxes.VersionPattern.Text)) {
        throw "Version Pattern is required."
    }

    if ($projects.Count -eq 0) {
        throw "At least one project is required."
    }

    return @{
        GitExe                 = $textBoxes.GitExe.Text.Trim()
        LogDirectory           = $textBoxes.LogDirectory.Text.Trim()
        Remote                 = $textBoxes.Remote.Text.Trim()
        MainBranch             = $textBoxes.MainBranch.Text.Trim()
        CommitMessage          = $textBoxes.CommitMessage.Text.Trim()
        DefaultProject         = $textBoxes.DefaultProject.Text.Trim()
        VersionPattern         = $textBoxes.VersionPattern.Text.Trim()
        VersionExample         = $textBoxes.VersionExample.Text.Trim()
        FeaturePrefix          = $textBoxes.FeaturePrefix.Text.Trim()
        ReleaseBranchPrefix    = $textBoxes.ReleaseBranchPrefix.Text.Trim()
        ReleaseTagPrefix       = $textBoxes.ReleaseTagPrefix.Text.Trim()
        DryRun                 = $dryRunCheckBox.Checked
        ConfirmBeforePush      = $confirmPushCheckBox.Checked
        ReleaseNotesEnabled    = $releaseNotesCheckBox.Checked
        ReleaseNotesDirectory  = $textBoxes.ReleaseNotesDirectory.Text.Trim()
        Projects               = $projects
    }
}

$browseGitButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "Git executable (git.exe)|git.exe|Executable files (*.exe)|*.exe|All files (*.*)|*.*"
    $dialog.Title = "Select git.exe"

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $textBoxes.GitExe.Text = $dialog.FileName
    }
})

$browseLogButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select log output directory"

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $textBoxes.LogDirectory.Text = $dialog.SelectedPath
    }
})

$validateButton.Add_Click({
    try {
        $null = Get-FormValues
        [System.Windows.Forms.MessageBox]::Show(
            "Config values look good.",
            "Validation",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            "Validation Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})

$reloadButton.Add_Click({
    try {
        $script:config = Read-Config -Path $ConfigPath
        Set-FormValues -Source $script:config
        $statusLabel.Text = "Reloaded: $ConfigPath"
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            "Reload Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})

$saveButton.Add_Click({
    try {
        $values = Get-FormValues
        $json = ConvertTo-ConfigJson -Values $values
        Set-Content -LiteralPath $ConfigPath -Value $json -Encoding UTF8
        $statusLabel.Text = "Saved: $ConfigPath"

        [System.Windows.Forms.MessageBox]::Show(
            "Config saved successfully.",
            "Saved",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            "Save Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})

$closeButton.Add_Click({
    $form.Close()
})

Set-FormValues -Source $config

[void]$form.ShowDialog()
