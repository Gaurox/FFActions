param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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

function Show-FormatPicker {
    param(
        [Parameter(Mandatory = $true)][string[]]$Formats,
        [Parameter(Mandatory = $true)][string]$SourceExtension
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFActions - Convert Video'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(320, 150)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(16, 16)
    $label.Size = New-Object System.Drawing.Size(288, 34)
    $label.Text = ("Choose the output format for this {0} video." -f $SourceExtension.TrimStart('.').ToUpperInvariant())

    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.Location = New-Object System.Drawing.Point(16, 58)
    $combo.Size = New-Object System.Drawing.Size(288, 24)
    $combo.DropDownStyle = 'DropDownList'
    [void]$combo.Items.AddRange($Formats)
    if ($combo.Items.Count -gt 0) {
        $combo.SelectedIndex = 0
    }

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(148, 104)
    $okButton.Size = New-Object System.Drawing.Size(75, 28)
    $okButton.Text = 'OK'
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(229, 104)
    $cancelButton.Size = New-Object System.Drawing.Size(75, 28)
    $cancelButton.Text = 'Cancel'
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    $form.Controls.AddRange(@($label, $combo, $okButton, $cancelButton))
    $form.AcceptButton = $okButton
    $form.CancelButton = $cancelButton

    $dialogResult = $form.ShowDialog()
    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or $combo.SelectedItem -eq $null) {
        return $null
    }

    return [string]$combo.SelectedItem
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
        '.mp4'  = @('mkv', 'avi', 'mov', 'webm', 'm4v')
        '.mkv'  = @('mp4', 'avi', 'mov', 'webm', 'm4v')
        '.avi'  = @('mp4', 'mkv', 'mov', 'webm', 'm4v')
        '.mov'  = @('mp4', 'mkv', 'avi', 'webm', 'm4v')
        '.webm' = @('mp4', 'mkv', 'avi', 'mov', 'm4v')
        '.m4v'  = @('mp4', 'mkv', 'avi', 'mov', 'webm')
    }

    if (-not $targetsBySource.ContainsKey($sourceExtension)) {
        Show-Error 'Unsupported input format. Only .mp4, .mkv, .avi, .mov, .webm and .m4v are supported.'
        exit 1
    }

    $selectedTarget = Show-FormatPicker -Formats $targetsBySource[$sourceExtension] -SourceExtension $sourceExtension
    if ([string]::IsNullOrWhiteSpace($selectedTarget)) {
        exit 0
    }

    $targetExe = Get-ActionPath ("convert_to_{0}.exe" -f $selectedTarget.ToLowerInvariant())
    if (-not (Test-Path -LiteralPath $targetExe)) {
        Show-Error "Conversion action not found:`r`n$targetExe"
        exit 1
    }

    $process = Start-Process -FilePath $targetExe -ArgumentList @($fullInputPath) -PassThru
    if ($null -eq $process) {
        Show-Error 'Unable to start video conversion.'
        exit 1
    }

    exit 0
}
catch {
    $message = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($message)) { $message = 'Unknown video conversion launcher error.' }
    Show-Error $message
    exit 1
}
