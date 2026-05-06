function Start-ActionProcess {
    param(
        [Parameter(Mandatory = $true)][string]$ExePath,
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ExePath
    $psi.Arguments = '"{0}"' -f ($FilePath -replace '"', '\"')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WorkingDirectory = Split-Path -Parent $ExePath

    return [System.Diagnostics.Process]::Start($psi)
}

function Show-FormatPicker {
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
    $form.ClientSize = New-Object System.Drawing.Size(360, 144)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(16, 16)
    $label.Size = New-Object System.Drawing.Size(328, 34)
    $label.Text = $LabelText
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
