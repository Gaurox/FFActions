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
    $form.Text = 'FFActions - Convert Image'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(360, 144)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(16, 16)
    $label.Size = New-Object System.Drawing.Size(328, 34)
    $label.Text = ("Choose the output format for this {0} image." -f $SourceExtension.TrimStart('.').ToUpperInvariant())
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter

    $buttonPanel = New-Object System.Windows.Forms.Panel
    $buttonPanel.Location = New-Object System.Drawing.Point(16, 60)
    $buttonPanel.Size = New-Object System.Drawing.Size(328, 42)

    $buttonWidth = 56
    $buttonSpacing = 8
    $rowWidth = ($Formats.Count * $buttonWidth) + ([Math]::Max(0, $Formats.Count - 1) * $buttonSpacing)
    $startX = [Math]::Max(0, [int](($buttonPanel.Width - $rowWidth) / 2))

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
            $form.Tag = [string]$sender.Tag
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Close()
        })
        $buttonPanel.Controls.Add($button)
    }

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(269, 104)
    $cancelButton.Size = New-Object System.Drawing.Size(75, 28)
    $cancelButton.Text = 'Cancel'
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    $form.Controls.AddRange(@($label, $buttonPanel, $cancelButton))
    $form.CancelButton = $cancelButton

    $dialogResult = $form.ShowDialog()
    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or [string]::IsNullOrWhiteSpace([string]$form.Tag)) {
        return $null
    }

    return [string]$form.Tag
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
        '.png'  = @('jpg', 'webp', 'bmp')
        '.jpg'  = @('png', 'webp', 'bmp')
        '.jpeg' = @('png', 'webp', 'bmp')
        '.webp' = @('png', 'jpg', 'bmp')
        '.bmp'  = @('png', 'jpg', 'webp')
    }

    if (-not $targetsBySource.ContainsKey($sourceExtension)) {
        Show-Error 'Unsupported input format. Only .png, .jpg, .jpeg, .webp and .bmp are supported.'
        exit 1
    }

    $selectedTarget = Show-FormatPicker -Formats $targetsBySource[$sourceExtension] -SourceExtension $sourceExtension
    if ([string]::IsNullOrWhiteSpace($selectedTarget)) {
        exit 0
    }

    $targetExe = Get-ActionPath ("convert_image_to_{0}.exe" -f $selectedTarget.ToLowerInvariant())
    if (-not (Test-Path -LiteralPath $targetExe)) {
        Show-Error "Conversion action not found:`r`n$targetExe"
        exit 1
    }

    $process = Start-Process -FilePath $targetExe -ArgumentList @($fullInputPath) -PassThru
    if ($null -eq $process) {
        Show-Error 'Unable to start image conversion.'
        exit 1
    }

    exit 0
}
catch {
    $message = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($message)) { $message = 'Unknown image conversion launcher error.' }
    Show-Error $message
    exit 1
}
