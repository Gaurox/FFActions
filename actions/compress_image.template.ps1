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

function Get-ToolPath([string]$ToolName) {
    $appRoot = Get-AppRoot
    return Join-Path $appRoot "tools\ffmpeg\$ToolName"
}

function Quote-ProcessArgument {
    param([string]$Value)

    if ($null -eq $Value) { return '""' }
    if ($Value -eq '') { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }

    $escaped = $Value -replace '(\\*)"', '$1$1\\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function Join-ProcessArguments {
    param([object[]]$Arguments)

    $quoted = foreach ($arg in $Arguments) {
        Quote-ProcessArgument ([string]$arg)
    }

    return ($quoted -join ' ')
}

function Invoke-HiddenProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][object[]]$Arguments
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = Join-ProcessArguments -Arguments $Arguments
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    [void]$process.Start()

    $stdOut = $process.StandardOutput.ReadToEnd()
    $stdErr = $process.StandardError.ReadToEnd()

    $process.WaitForExit()
    $exitCode = $process.ExitCode
    $process.Dispose()

    return [PSCustomObject]@{
        ExitCode = $exitCode
        StdOut   = $stdOut
        StdErr   = $stdErr
    }
}

function Get-UniqueOutputPath([string]$DesiredPath) {
    if (-not (Test-Path -LiteralPath $DesiredPath)) {
        return $DesiredPath
    }

    $dir = Split-Path -Parent $DesiredPath
    $base = [System.IO.Path]::GetFileNameWithoutExtension($DesiredPath)
    $ext = [System.IO.Path]::GetExtension($DesiredPath)

    for ($i = 1; $i -le 999; $i++) {
        $candidate = Join-Path $dir ("{0}_{1:D3}{2}" -f $base, $i, $ext)
        if (-not (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    throw 'Unable to create a unique output filename.'
}

function Remove-PartialOutput {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (Test-Path -LiteralPath $Path) {
        try { Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue } catch {}
    }
}

function Get-ShortErrorText {
    param([string]$StdErr)

    if (-not [string]::IsNullOrWhiteSpace($StdErr)) {
        $firstLines = ($StdErr -split "`r?`n" | Where-Object { $_.Trim() -ne '' } | Select-Object -First 12) -join "`r`n"
        if (-not [string]::IsNullOrWhiteSpace($firstLines)) {
            return $firstLines
        }
    }

    return 'FFmpeg failed during image compression.'
}

function Format-FileSize([long]$Bytes) {
    if ($Bytes -ge 1MB) {
        return ([Math]::Round(($Bytes / 1MB), 2)).ToString('0.##', [System.Globalization.CultureInfo]::InvariantCulture) + ' MB'
    }
    return ([Math]::Round(($Bytes / 1KB), 0)).ToString('0', [System.Globalization.CultureInfo]::InvariantCulture) + ' KB'
}

function Get-DefaultOutputFormat([string]$SourceExtension) {
    switch ($SourceExtension.ToLowerInvariant()) {
        '.png'  { return '.png' }
        '.jpg'  { return '.jpg' }
        '.jpeg' { return '.jpg' }
        '.webp' { return '.webp' }
        '.bmp'  { return '.png' }
        default { return '.jpg' }
    }
}

function Get-PresetLabel([string]$PresetKey) {
    switch ($PresetKey) {
        'high'     { return 'high' }
        'balanced' { return 'balanced' }
        'small'    { return 'small' }
        default    { return 'custom' }
    }
}

function Get-DefaultQualityForPreset {
    param(
        [Parameter(Mandatory = $true)][string]$OutputExtension,
        [Parameter(Mandatory = $true)][string]$PresetKey
    )

    switch ($OutputExtension.ToLowerInvariant()) {
        '.jpg' {
            switch ($PresetKey) {
                'high'     { return 2 }
                'balanced' { return 6 }
                'small'    { return 12 }
            }
        }
        '.webp' {
            switch ($PresetKey) {
                'high'     { return 92 }
                'balanced' { return 82 }
                'small'    { return 68 }
            }
        }
        '.png' {
            switch ($PresetKey) {
                'high'     { return 30 }
                'balanced' { return 60 }
                'small'    { return 90 }
            }
        }
        default {
            return $null
        }
    }

    return $null
}

function New-FFmpegArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)][string]$OutputExtension,
        [Parameter(Mandatory = $true)][string]$PresetKey,
        [Parameter()][Nullable[int]]$QualityValue
    )

    $args = @(
        '-hide_banner',
        '-loglevel', 'error',
        '-y',
        '-i', $InputFile,
        '-frames:v', '1'
    )

    switch ($OutputExtension.ToLowerInvariant()) {
        '.jpg' {
            $qv = if ($null -ne $QualityValue) { [int]$QualityValue } else { [int](Get-DefaultQualityForPreset -OutputExtension '.jpg' -PresetKey $PresetKey) }
            $args += @('-q:v', [string]$qv)
        }
        '.webp' {
            $quality = if ($null -ne $QualityValue) { [int]$QualityValue } else { [int](Get-DefaultQualityForPreset -OutputExtension '.webp' -PresetKey $PresetKey) }
            $args += @('-c:v', 'libwebp', '-quality', [string]$quality, '-compression_level', '6')
        }
        '.png' {
            $quality = if ($null -ne $QualityValue) { [int]$QualityValue } else { [int](Get-DefaultQualityForPreset -OutputExtension '.png' -PresetKey $PresetKey) }
            $args += @('-c:v', 'png', '-compression_level', '9')
            if ($quality -ge 80) {
                $args += @('-vf', 'scale=iw:ih:flags=lanczos,format=rgb24')
            }
        }
        default {
            throw 'Unsupported output format. Only .png, .jpg and .webp are supported.'
        }
    }

    $args += @($OutputFile)
    return ,$args
}

function Try-CompressWithTargetSize {
    param(
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)][string]$OutputExtension,
        [Parameter(Mandatory = $true)][string]$PresetKey,
        [Parameter(Mandatory = $true)][long]$TargetBytes
    )

    $candidates = @()
    switch ($OutputExtension.ToLowerInvariant()) {
        '.jpg'  { $candidates = @(2,3,4,5,6,7,8,10,12,14,16,18,20,24,28,31) }
        '.webp' { $candidates = @(95,90,86,82,78,74,70,66,62,58,54,50,46,42,38,34,30) }
        default { throw 'Target size is only supported for JPG and WEBP.' }
    }

    $bestUnder = $null
    $bestOver = $null

    foreach ($candidate in $candidates) {
        Remove-PartialOutput -Path $OutputFile
        $args = New-FFmpegArguments -InputFile $InputFile -OutputFile $OutputFile -OutputExtension $OutputExtension -PresetKey $PresetKey -QualityValue $candidate
        $result = Invoke-HiddenProcess -FilePath $FfmpegPath -Arguments $args

        if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $OutputFile)) {
            Remove-PartialOutput -Path $OutputFile
            return [PSCustomObject]@{
                Success  = $false
                StdErr   = $result.StdErr
                FileSize = 0
            }
        }

        $size = (Get-Item -LiteralPath $OutputFile).Length
        $entry = [PSCustomObject]@{
            Quality = $candidate
            FileSize = $size
        }

        if ($size -le $TargetBytes) {
            if ($null -eq $bestUnder -or $size -gt $bestUnder.FileSize) {
                $bestUnder = $entry
            }
        }
        else {
            if ($null -eq $bestOver -or $size -lt $bestOver.FileSize) {
                $bestOver = $entry
            }
        }
    }

    $chosen = if ($bestUnder) { $bestUnder } else { $bestOver }
    if ($null -eq $chosen) {
        return [PSCustomObject]@{ Success = $false; StdErr = 'Unable to compute target size output.'; FileSize = 0 }
    }

    Remove-PartialOutput -Path $OutputFile
    $finalArgs = New-FFmpegArguments -InputFile $InputFile -OutputFile $OutputFile -OutputExtension $OutputExtension -PresetKey $PresetKey -QualityValue $chosen.Quality
    $finalResult = Invoke-HiddenProcess -FilePath $FfmpegPath -Arguments $finalArgs
    if ($finalResult.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $OutputFile)) {
        Remove-PartialOutput -Path $OutputFile
        return [PSCustomObject]@{
            Success = $false
            StdErr = $finalResult.StdErr
            FileSize = 0
        }
    }

    return [PSCustomObject]@{
        Success  = $true
        StdErr   = $finalResult.StdErr
        FileSize = (Get-Item -LiteralPath $OutputFile).Length
    }
}

function Show-CompressWindow {
    param(
        [Parameter(Mandatory = $true)][string]$SourceExtension,
        [Parameter(Mandatory = $true)][long]$SourceBytes
    )

    [System.Windows.Forms.Application]::EnableVisualStyles()
    $script:syncing = $false

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFActions - Compress image'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(500, 340)
    $form.TopMost = $true

    $labelInfo = New-Object System.Windows.Forms.Label
    $labelInfo.Location = New-Object System.Drawing.Point(20, 18)
    $labelInfo.Size = New-Object System.Drawing.Size(450, 22)
    $labelInfo.Text = 'Original: ' + $SourceExtension.TrimStart('.').ToUpperInvariant() + '    Size: ' + (Format-FileSize -Bytes $SourceBytes)
    $form.Controls.Add($labelInfo)

    $groupPreset = New-Object System.Windows.Forms.GroupBox
    $groupPreset.Text = 'Compression profile'
    $groupPreset.Location = New-Object System.Drawing.Point(18, 50)
    $groupPreset.Size = New-Object System.Drawing.Size(464, 88)
    $form.Controls.Add($groupPreset)

    $radioHigh = New-Object System.Windows.Forms.RadioButton
    $radioHigh.Text = 'High quality'
    $radioHigh.Location = New-Object System.Drawing.Point(18, 30)
    $radioHigh.Size = New-Object System.Drawing.Size(110, 24)
    $radioHigh.Checked = $true
    $groupPreset.Controls.Add($radioHigh)

    $radioBalanced = New-Object System.Windows.Forms.RadioButton
    $radioBalanced.Text = 'Balanced'
    $radioBalanced.Location = New-Object System.Drawing.Point(170, 30)
    $radioBalanced.Size = New-Object System.Drawing.Size(90, 24)
    $groupPreset.Controls.Add($radioBalanced)

    $radioSmall = New-Object System.Windows.Forms.RadioButton
    $radioSmall.Text = 'Small file'
    $radioSmall.Location = New-Object System.Drawing.Point(312, 30)
    $radioSmall.Size = New-Object System.Drawing.Size(90, 24)
    $groupPreset.Controls.Add($radioSmall)

    $labelPresetHint = New-Object System.Windows.Forms.Label
    $labelPresetHint.Location = New-Object System.Drawing.Point(18, 58)
    $labelPresetHint.Size = New-Object System.Drawing.Size(420, 18)
    $labelPresetHint.Text = 'PNG keeps lossless compression. JPG/WEBP give the biggest file size reduction.'
    $groupPreset.Controls.Add($labelPresetHint)

    $groupFormat = New-Object System.Windows.Forms.GroupBox
    $groupFormat.Text = 'Output format'
    $groupFormat.Location = New-Object System.Drawing.Point(18, 146)
    $groupFormat.Size = New-Object System.Drawing.Size(464, 62)
    $form.Controls.Add($groupFormat)

    $labelFormat = New-Object System.Windows.Forms.Label
    $labelFormat.Text = 'Format'
    $labelFormat.Location = New-Object System.Drawing.Point(18, 28)
    $labelFormat.Size = New-Object System.Drawing.Size(60, 20)
    $groupFormat.Controls.Add($labelFormat)

    $comboFormat = New-Object System.Windows.Forms.ComboBox
    $comboFormat.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboFormat.Location = New-Object System.Drawing.Point(96, 24)
    $comboFormat.Size = New-Object System.Drawing.Size(120, 24)
    [void]$comboFormat.Items.AddRange(@('PNG', 'JPG', 'WEBP'))
    $comboFormat.SelectedItem = (Get-DefaultOutputFormat -SourceExtension $SourceExtension).TrimStart('.').ToUpperInvariant()
    $groupFormat.Controls.Add($comboFormat)

    $groupTarget = New-Object System.Windows.Forms.GroupBox
    $groupTarget.Text = 'Optional target size'
    $groupTarget.Location = New-Object System.Drawing.Point(18, 216)
    $groupTarget.Size = New-Object System.Drawing.Size(464, 82)
    $form.Controls.Add($groupTarget)

    $checkTarget = New-Object System.Windows.Forms.CheckBox
    $checkTarget.Text = 'Target file size'
    $checkTarget.Location = New-Object System.Drawing.Point(18, 25)
    $checkTarget.Size = New-Object System.Drawing.Size(110, 24)
    $groupTarget.Controls.Add($checkTarget)

    $textTarget = New-Object System.Windows.Forms.TextBox
    $textTarget.Location = New-Object System.Drawing.Point(145, 24)
    $textTarget.Size = New-Object System.Drawing.Size(80, 23)
    $textTarget.Enabled = $false
    $textTarget.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Right
    $groupTarget.Controls.Add($textTarget)

    $comboUnit = New-Object System.Windows.Forms.ComboBox
    $comboUnit.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboUnit.Location = New-Object System.Drawing.Point(234, 24)
    $comboUnit.Size = New-Object System.Drawing.Size(70, 24)
    [void]$comboUnit.Items.AddRange(@('KB', 'MB'))
    $comboUnit.SelectedItem = 'KB'
    $comboUnit.Enabled = $false
    $groupTarget.Controls.Add($comboUnit)

    $labelTargetHint = New-Object System.Windows.Forms.Label
    $labelTargetHint.Location = New-Object System.Drawing.Point(315, 17)
    $labelTargetHint.Size = New-Object System.Drawing.Size(130, 40)
    $groupTarget.Controls.Add($labelTargetHint)

    $buttonOK = New-Object System.Windows.Forms.Button
    $buttonOK.Text = 'OK'
    $buttonOK.Location = New-Object System.Drawing.Point(286, 304)
    $buttonOK.Size = New-Object System.Drawing.Size(90, 28)
    $buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($buttonOK)

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.Location = New-Object System.Drawing.Point(388, 304)
    $buttonCancel.Size = New-Object System.Drawing.Size(90, 28)
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($buttonCancel)

    $form.AcceptButton = $buttonOK
    $form.CancelButton = $buttonCancel

    function Update-TargetUi {
        $selectedFormat = '.' + $comboFormat.SelectedItem.ToString().ToLowerInvariant()
        $supportsTarget = $selectedFormat -in @('.jpg', '.webp')
        $checkTarget.Enabled = $supportsTarget
        if (-not $supportsTarget) {
            $checkTarget.Checked = $false
            $textTarget.Enabled = $false
            $comboUnit.Enabled = $false
            $labelTargetHint.Text = 'Target size only for' + "`r`n" + 'JPG/WEBP'
        }
        else {
            $textTarget.Enabled = $checkTarget.Checked
            $comboUnit.Enabled = $checkTarget.Checked
            $labelTargetHint.Text = 'Best-effort target'
        }
    }

    $comboFormat.Add_SelectedIndexChanged({ Update-TargetUi })
    $checkTarget.Add_CheckedChanged({ Update-TargetUi })
    Update-TargetUi

    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        $form.Dispose()
        return $null
    }

    try {
        $presetKey = if ($radioHigh.Checked) { 'high' } elseif ($radioBalanced.Checked) { 'balanced' } else { 'small' }
        $outputExtension = '.' + $comboFormat.SelectedItem.ToString().ToLowerInvariant()
        $targetBytes = $null

        if ($checkTarget.Checked) {
            $raw = $textTarget.Text.Trim().Replace(',', '.')
            $value = 0.0
            if (-not [double]::TryParse($raw, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$value) -or $value -le 0) {
                throw 'Target size must be a positive number.'
            }

            if ($comboUnit.SelectedItem -eq 'MB') {
                $targetBytes = [long][Math]::Round($value * 1MB)
            }
            else {
                $targetBytes = [long][Math]::Round($value * 1KB)
            }
        }

        $payload = [PSCustomObject]@{
            PresetKey       = $presetKey
            OutputExtension = $outputExtension
            TargetBytes     = $targetBytes
        }

        $form.Dispose()
        return $payload
    }
    catch {
        $message = $_.Exception.Message
        $form.Dispose()
        Show-Error $message
        exit 1
    }
}

#__FFCOMMON_INJECT_HERE__

try {
    if ([string]::IsNullOrWhiteSpace($InputFile)) {
        Show-Error 'Input file is missing.'
        exit 1
    }

    if (-not (Test-Path -LiteralPath $InputFile)) {
        Show-Error 'Input file not found.'
        exit 1
    }

    $sourceExtension = [System.IO.Path]::GetExtension($InputFile).ToLowerInvariant()
    if ($sourceExtension -notin @('.png', '.jpg', '.jpeg', '.webp', '.bmp')) {
        Show-Error 'Unsupported input format. Only .png, .jpg, .jpeg, .webp and .bmp are supported.'
        exit 1
    }

    $ffmpeg = Get-ToolPath 'ffmpeg.exe'
    if (-not (Test-Path -LiteralPath $ffmpeg)) {
        Show-Error 'ffmpeg.exe not found.'
        exit 1
    }

    $sourceBytes = (Get-Item -LiteralPath $InputFile).Length
    $compressConfig = Show-CompressWindow -SourceExtension $sourceExtension -SourceBytes $sourceBytes
    if ($null -eq $compressConfig) {
        exit 0
    }

    $inputDir = Split-Path -Parent $InputFile
    $inputBase = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $presetLabel = Get-PresetLabel -PresetKey $compressConfig.PresetKey
    $formatLabel = $compressConfig.OutputExtension.TrimStart('.')
    $desiredOutput = Join-Path $inputDir ("{0}_compress_{1}_{2}{3}" -f $inputBase, $presetLabel, $formatLabel, $compressConfig.OutputExtension)
    $script:OutputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

    if ($null -ne $compressConfig.TargetBytes) {
        $result = Try-CompressWithTargetSize -FfmpegPath $ffmpeg -InputFile $InputFile -OutputFile $script:OutputFile -OutputExtension $compressConfig.OutputExtension -PresetKey $compressConfig.PresetKey -TargetBytes $compressConfig.TargetBytes
        if (-not $result.Success -or -not (Test-Path -LiteralPath $script:OutputFile)) {
            Remove-PartialOutput -Path $script:OutputFile
            Show-Error (Get-ShortErrorText -StdErr $result.StdErr)
            exit 1
        }
    }
    else {
        $ffmpegArgs = New-FFmpegArguments -InputFile $InputFile -OutputFile $script:OutputFile -OutputExtension $compressConfig.OutputExtension -PresetKey $compressConfig.PresetKey
        $result = Invoke-HiddenProcess -FilePath $ffmpeg -Arguments $ffmpegArgs
        if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $script:OutputFile)) {
            Remove-PartialOutput -Path $script:OutputFile
            Show-Error (Get-ShortErrorText -StdErr $result.StdErr)
            exit 1
        }
    }

    exit 0
}
catch {
    $message = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($message)) { $message = 'Unknown image compression error.' }
    Show-Error $message
    exit 1
}
