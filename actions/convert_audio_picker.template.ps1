param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

function Show-Error([string]$Message) {
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        'FFActions - Error',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function Get-AppRoot {
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $exeDir = Split-Path -Parent $exePath
    return Split-Path -Parent $exeDir
}

function Get-ActionPath([string]$ActionName) {
    $appRoot = Get-AppRoot
    return Join-Path $appRoot ("actions\{0}" -f $ActionName)
}

function Quote-LauncherArgument {
    param([string]$Value)

    if ($null -eq $Value) {
        return ''
    }

    if ($Value -eq '') {
        return '""'
    }

    if ($Value -notmatch '[\s"]') {
        return $Value
    }

    $escaped = $Value -replace '(\\*)"', '$1$1\\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function Start-AudioActionProcess {
    param(
        [Parameter(Mandatory = $true)][string]$ExePath,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string]$ProfileName
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ExePath
    $psi.Arguments = ((Quote-LauncherArgument -Value $FilePath), (Quote-LauncherArgument -Value $ProfileName) -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WorkingDirectory = Split-Path -Parent $ExePath

    return [System.Diagnostics.Process]::Start($psi)
}

function Get-AudioProfileItems {
    $items = New-Object System.Collections.Generic.List[object]
    $items.Add([PSCustomObject]@{
        Id          = 'standard'
        Label       = 'Standard'
        Description = 'Recommended for most files. Good quality without oversized output.'
    })
    $items.Add([PSCustomObject]@{
        Id          = 'high'
        Label       = 'High quality'
        Description = 'Higher bitrate or quality settings when the target format supports it.'
    })
    $items.Add([PSCustomObject]@{
        Id          = 'small'
        Label       = 'Small file'
        Description = 'Lower bitrate or lighter settings to reduce output size.'
    })

    return $items.ToArray()
}

function Show-AudioConvertPicker {
    param(
        [Parameter(Mandatory = $true)][string[]]$Formats,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$LabelText
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(392, 228)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(16, 16)
    $label.Size = New-Object System.Drawing.Size(360, 34)
    $label.Text = $LabelText
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter

    $buttonPanel = New-Object System.Windows.Forms.Panel
    $buttonPanel.Location = New-Object System.Drawing.Point(16, 58)
    $buttonPanel.Size = New-Object System.Drawing.Size(360, 42)

    $buttonWidth = 56
    $buttonSpacing = 8
    $rowWidth = ($Formats.Count * $buttonWidth) + ([Math]::Max(0, $Formats.Count - 1) * $buttonSpacing)
    $startX = [Math]::Max(0, [int](($buttonPanel.Width - $rowWidth) / 2))

    $profileItems = @(Get-AudioProfileItems)

    for ($i = 0; $i -lt $Formats.Count; $i++) {
        $format = [string]$Formats[$i]
        $button = New-Object System.Windows.Forms.Button
        $button.Text = $format.ToUpperInvariant()
        $button.Size = New-Object System.Drawing.Size($buttonWidth, 30)
        $button.Location = New-Object System.Drawing.Point(($startX + ($i * ($buttonWidth + $buttonSpacing))), 6)
        $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Standard
        $button.Tag = $format
        $button.Add_Click({
            param($sender, $eventArgs)
            $profileId = [string]$profileItems[0].Id
            if ($comboProfile.SelectedIndex -ge 0 -and $comboProfile.SelectedIndex -lt $profileItems.Count) {
                $profileId = [string]$profileItems[$comboProfile.SelectedIndex].Id
            }
            $form.Tag = [PSCustomObject]@{
                Format  = [string]$sender.Tag
                Profile = $profileId
            }
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Close()
        })
        $buttonPanel.Controls.Add($button)
    }

    $labelProfile = New-Object System.Windows.Forms.Label
    $labelProfile.Location = New-Object System.Drawing.Point(16, 116)
    $labelProfile.Size = New-Object System.Drawing.Size(80, 20)
    $labelProfile.Text = 'Profile:'

    $comboProfile = New-Object System.Windows.Forms.ComboBox
    $comboProfile.Location = New-Object System.Drawing.Point(96, 113)
    $comboProfile.Size = New-Object System.Drawing.Size(280, 24)
    $comboProfile.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    foreach ($profileItem in $profileItems) {
        [void]$comboProfile.Items.Add($profileItem.Label)
    }
    $comboProfile.SelectedIndex = 0

    $labelDescription = New-Object System.Windows.Forms.Label
    $labelDescription.Location = New-Object System.Drawing.Point(16, 146)
    $labelDescription.Size = New-Object System.Drawing.Size(360, 40)
    $labelDescription.Text = $profileItems[0].Description

    $comboProfile.Add_SelectedIndexChanged({
        if ($comboProfile.SelectedIndex -ge 0 -and $comboProfile.SelectedIndex -lt $profileItems.Count) {
            $labelDescription.Text = $profileItems[$comboProfile.SelectedIndex].Description
        }
    })

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(301, 192)
    $cancelButton.Size = New-Object System.Drawing.Size(75, 28)
    $cancelButton.Text = 'Cancel'
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    $form.Controls.AddRange(@(
        $label,
        $buttonPanel,
        $labelProfile,
        $comboProfile,
        $labelDescription,
        $cancelButton
    ))
    $form.CancelButton = $cancelButton

    $dialogResult = $form.ShowDialog()
    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or $null -eq $form.Tag) {
        return $null
    }

    return $form.Tag
}

#__FFCOMMON_INJECT_HERE__


try {
    if ([string]::IsNullOrWhiteSpace($InputFile)) {
        Show-Error 'Input file is missing.'
        exit 1
    }

    $fullInputPath = [System.IO.Path]::GetFullPath($InputFile)
    if (-not (Test-Path -LiteralPath $fullInputPath)) {
        Show-Error "Input file not found:`r`n$fullInputPath"
        exit 1
    }

    $sourceExtension = [System.IO.Path]::GetExtension($fullInputPath).ToLowerInvariant()
    $targetsBySource = @{
        '.mp3'  = @('wav', 'flac', 'm4a', 'ogg')
        '.wav'  = @('mp3', 'flac', 'm4a', 'ogg')
        '.wave' = @('mp3', 'flac', 'm4a', 'ogg')
        '.flac' = @('mp3', 'wav', 'm4a', 'ogg')
        '.m4a'  = @('mp3', 'wav', 'flac', 'ogg')
        '.ogg'  = @('mp3', 'wav', 'flac', 'm4a')
    }

    if (-not $targetsBySource.ContainsKey($sourceExtension)) {
        Show-Error 'Unsupported input format. Only .mp3, .wav, .flac, .m4a and .ogg are supported.'
        exit 1
    }

    $selection = Show-AudioConvertPicker `
        -Formats $targetsBySource[$sourceExtension] `
        -Title 'FFActions - Convert Audio' `
        -LabelText ("Choose the output format for this {0} audio file." -f $sourceExtension.TrimStart('.').ToUpperInvariant())
    if ($null -eq $selection -or [string]::IsNullOrWhiteSpace([string]$selection.Format)) {
        exit 0
    }

    $selectedTarget = [string]$selection.Format
    $selectedProfile = [string]$selection.Profile
    $targetExe = Get-ActionPath ("convert_audio_to_{0}.exe" -f $selectedTarget.ToLowerInvariant())
    if (-not (Test-Path -LiteralPath $targetExe)) {
        Show-Error "Conversion action not found:`r`n$targetExe"
        exit 1
    }

    $process = Start-AudioActionProcess -ExePath $targetExe -FilePath $fullInputPath -ProfileName $selectedProfile
    if ($null -eq $process) {
        Show-Error 'Unable to start audio conversion.'
        exit 1
    }

    exit 0
}
catch {
    $message = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($message)) { $message = 'Unknown audio conversion launcher error.' }
    Show-Error $message
    exit 1
}
