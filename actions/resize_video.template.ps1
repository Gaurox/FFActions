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

function Get-VideoInfo {
    param(
        [Parameter(Mandatory = $true)][string]$FfprobePath,
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    $probeResult = Invoke-HiddenProcess -FilePath $FfprobePath -Arguments @(
        '-v', 'error',
        '-select_streams', 'v:0',
        '-show_entries', 'format=duration:stream=width,height',
        '-of', 'default=nokey=0:noprint_wrappers=1',
        $FilePath
    )

    if ($probeResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($probeResult.StdOut)) {
        $probeErr = $probeResult.StdErr.Trim()
        if ([string]::IsNullOrWhiteSpace($probeErr)) {
            $probeErr = 'ffprobe failed to read video information.'
        }
        throw $probeErr
    }

    $map = @{}
    foreach ($line in ($probeResult.StdOut -split "`r?`n")) {
        if ($line -match '^(?<k>[^=]+)=(?<v>.*)$') {
            $map[$matches['k']] = $matches['v']
        }
    }

    if (-not $map.ContainsKey('duration')) {
        throw 'Unable to determine video duration.'
    }

    $durationSeconds = [double]::Parse($map['duration'].Replace(',', '.'), [System.Globalization.CultureInfo]::InvariantCulture)
    if ($durationSeconds -le 0) {
        throw 'Invalid video duration.'
    }

    $width = 0
    $height = 0
    if ($map.ContainsKey('width') -and $map['width'] -match '^\d+$') { $width = [int]$map['width'] }
    if ($map.ContainsKey('height') -and $map['height'] -match '^\d+$') { $height = [int]$map['height'] }

    if ($width -le 0 -or $height -le 0) {
        throw 'Invalid video dimensions.'
    }

    return [PSCustomObject]@{
        DurationSeconds = $durationSeconds
        Width           = $width
        Height          = $height
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

    return 'FFmpeg failed during video resize.'
}

function Try-ParsePositiveInt {
    param([string]$Text)
    $value = 0
    if ([int]::TryParse($Text, [ref]$value) -and $value -gt 0) {
        return $value
    }
    return $null
}

function Try-ParsePositiveDouble {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $styles = [System.Globalization.NumberStyles]::Float
    $cultures = @(
        [System.Globalization.CultureInfo]::CurrentCulture,
        [System.Globalization.CultureInfo]::InvariantCulture
    )

    foreach ($culture in $cultures) {
        $value = 0.0
        if ([double]::TryParse($Text.Trim(), $styles, $culture, [ref]$value) -and $value -gt 0) {
            return $value
        }
    }

    return $null
}

function Format-PercentText {
    param([double]$Value)
    $rounded = [Math]::Round($Value, 2)
    if ([Math]::Abs($rounded - [Math]::Round($rounded)) -lt 0.0000001) {
        return ([int][Math]::Round($rounded)).ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }
    return $rounded.ToString('0.##', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Format-ScaleButtonText {
    param([double]$Scale)
    return ('x' + $Scale.ToString('0.##', [System.Globalization.CultureInfo]::CurrentCulture))
}

function Normalize-VideoDimensions {
    param(
        [Parameter(Mandatory = $true)][int]$Width,
        [Parameter(Mandatory = $true)][int]$Height
    )

    if ($Width -lt 1) { $Width = 1 }
    if ($Height -lt 1) { $Height = 1 }

    if ($Width -gt 1 -and ($Width % 2) -ne 0) {
        $Width--
    }
    if ($Height -gt 1 -and ($Height % 2) -ne 0) {
        $Height--
    }

    if ($Width -lt 1) { $Width = 1 }
    if ($Height -lt 1) { $Height = 1 }

    return [PSCustomObject]@{
        Width  = $Width
        Height = $Height
    }
}

function Test-NvencAvailable([string]$FfmpegPath) {
    $probeResult = Invoke-HiddenProcess -FilePath $FfmpegPath -Arguments @('-hide_banner', '-encoders')
    if ($probeResult.ExitCode -ne 0) {
        return $false
    }

    $allText = ($probeResult.StdOut + "`r`n" + $probeResult.StdErr)
    return ($allText -match '(^|\s)h264_nvenc(\s|$)')
}

function Get-EncodingPlan([string]$TargetExtension, [bool]$NvencAvailable) {
    switch ($TargetExtension.ToLowerInvariant()) {
        '.mp4' {
            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'libx264'
                VideoArgs  = @('-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                AudioCodec = 'aac'
                AudioArgs  = @('-b:a', '320k')
            }

            if ($NvencAvailable) {
                $gpu = [PSCustomObject]@{
                    ModeLabel  = 'NVIDIA GPU'
                    VideoCodec = 'h264_nvenc'
                    VideoArgs  = @('-preset', 'p5', '-cq', '21', '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                    AudioCodec = 'aac'
                    AudioArgs  = @('-b:a', '320k')
                }

                return [PSCustomObject]@{ Primary = $gpu; Fallback = $cpu }
            }

            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        '.mkv' {
            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'libx264'
                VideoArgs  = @('-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p')
                AudioCodec = 'aac'
                AudioArgs  = @('-b:a', '320k')
            }

            if ($NvencAvailable) {
                $gpu = [PSCustomObject]@{
                    ModeLabel  = 'NVIDIA GPU'
                    VideoCodec = 'h264_nvenc'
                    VideoArgs  = @('-preset', 'p5', '-cq', '21', '-pix_fmt', 'yuv420p')
                    AudioCodec = 'aac'
                    AudioArgs  = @('-b:a', '320k')
                }

                return [PSCustomObject]@{ Primary = $gpu; Fallback = $cpu }
            }

            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        '.avi' {
            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'mpeg4'
                VideoArgs  = @('-q:v', '2')
                AudioCodec = 'libmp3lame'
                AudioArgs  = @('-b:a', '320k')
            }

            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        '.mov' {
            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'libx264'
                VideoArgs  = @('-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                AudioCodec = 'aac'
                AudioArgs  = @('-b:a', '320k')
            }

            if ($NvencAvailable) {
                $gpu = [PSCustomObject]@{
                    ModeLabel  = 'NVIDIA GPU'
                    VideoCodec = 'h264_nvenc'
                    VideoArgs  = @('-preset', 'p5', '-cq', '21', '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                    AudioCodec = 'aac'
                    AudioArgs  = @('-b:a', '320k')
                }

                return [PSCustomObject]@{ Primary = $gpu; Fallback = $cpu }
            }

            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        '.webm' {
            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'libvpx-vp9'
                VideoArgs  = @('-crf', '31', '-b:v', '0', '-deadline', 'good', '-cpu-used', '2', '-row-mt', '1')
                AudioCodec = 'libopus'
                AudioArgs  = @('-b:a', '192k')
            }

            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        '.m4v' {
            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'libx264'
                VideoArgs  = @('-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                AudioCodec = 'aac'
                AudioArgs  = @('-b:a', '320k')
            }

            if ($NvencAvailable) {
                $gpu = [PSCustomObject]@{
                    ModeLabel  = 'NVIDIA GPU'
                    VideoCodec = 'h264_nvenc'
                    VideoArgs  = @('-preset', 'p5', '-cq', '21', '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                    AudioCodec = 'aac'
                    AudioArgs  = @('-b:a', '320k')
                }

                return [PSCustomObject]@{ Primary = $gpu; Fallback = $cpu }
            }

            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        default {
            throw 'Unsupported file format. Supported: .mp4, .mkv, .avi, .mov, .webm, .m4v'
        }
    }
}

function Get-EnvironmentValue {
    param([Parameter(Mandatory = $true)][string]$Name)

    $value = [System.Environment]::GetEnvironmentVariable($Name, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $null
    }

    return $value.Trim()
}

function Get-AutomationResizeSelection {
    param(
        [Parameter(Mandatory = $true)][int]$SourceWidth,
        [Parameter(Mandatory = $true)][int]$SourceHeight
    )

    $flag = Get-EnvironmentValue -Name 'FFACTIONS_VIDEO_RESIZE_AUTOMATION'
    if ([string]::IsNullOrWhiteSpace($flag)) {
        return $null
    }

    switch ($flag.ToLowerInvariant()) {
        '1' {}
        'true' {}
        'yes' {}
        default { return $null }
    }

    $keepRatioRaw = Get-EnvironmentValue -Name 'FFACTIONS_VIDEO_RESIZE_KEEP_RATIO'
    $keepRatio = $true
    if (-not [string]::IsNullOrWhiteSpace($keepRatioRaw)) {
        switch ($keepRatioRaw.ToLowerInvariant()) {
            '0' { $keepRatio = $false }
            'false' { $keepRatio = $false }
            'no' { $keepRatio = $false }
            default { $keepRatio = $true }
        }
    }

    $width = Try-ParsePositiveInt (Get-EnvironmentValue -Name 'FFACTIONS_VIDEO_RESIZE_WIDTH')
    $height = Try-ParsePositiveInt (Get-EnvironmentValue -Name 'FFACTIONS_VIDEO_RESIZE_HEIGHT')
    $ratio = [double]$SourceWidth / [double]$SourceHeight

    if ($keepRatio) {
        if ($null -ne $width) {
            $height = [Math]::Max(1, [int][Math]::Round([double]$width / $ratio))
        }
        elseif ($null -ne $height) {
            $width = [Math]::Max(1, [int][Math]::Round([double]$height * $ratio))
        }
    }

    if ($null -eq $width -or $null -eq $height) {
        throw 'Invalid automation resize values.'
    }

    return Normalize-VideoDimensions -Width $width -Height $height
}

function Show-ResizeWindow {
    param(
        [Parameter(Mandatory = $true)][int]$OriginalWidth,
        [Parameter(Mandatory = $true)][int]$OriginalHeight
    )

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $ratio = [double]$OriginalWidth / [double]$OriginalHeight
    $script:updatingFields = $false
    $script:activeEditField = $null

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Resize Video'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ShowIcon = $false
    $form.ClientSize = New-Object System.Drawing.Size(500, 388)
    $form.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $panelHeader = New-Object System.Windows.Forms.Panel
    $panelHeader.Location = New-Object System.Drawing.Point(0, 0)
    $panelHeader.Size = New-Object System.Drawing.Size(500, 78)
    $panelHeader.BackColor = [System.Drawing.Color]::White
    $form.Controls.Add($panelHeader)

    $labelTitle = New-Object System.Windows.Forms.Label
    $labelTitle.Text = 'Resize video'
    $labelTitle.Location = New-Object System.Drawing.Point(20, 16)
    $labelTitle.Size = New-Object System.Drawing.Size(220, 26)
    $labelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
    $panelHeader.Controls.Add($labelTitle)

    $labelSubtitle = New-Object System.Windows.Forms.Label
    $labelSubtitle.Text = 'Adjust in pixels or percent and keep the original ratio automatically.'
    $labelSubtitle.Location = New-Object System.Drawing.Point(20, 44)
    $labelSubtitle.Size = New-Object System.Drawing.Size(450, 20)
    $labelSubtitle.ForeColor = [System.Drawing.Color]::FromArgb(90, 90, 90)
    $panelHeader.Controls.Add($labelSubtitle)

    $groupOriginal = New-Object System.Windows.Forms.GroupBox
    $groupOriginal.Text = 'Original size'
    $groupOriginal.Location = New-Object System.Drawing.Point(18, 92)
    $groupOriginal.Size = New-Object System.Drawing.Size(464, 60)
    $form.Controls.Add($groupOriginal)

    $labelOriginalValue = New-Object System.Windows.Forms.Label
    $labelOriginalValue.Text = "$OriginalWidth x $OriginalHeight px"
    $labelOriginalValue.Location = New-Object System.Drawing.Point(16, 24)
    $labelOriginalValue.Size = New-Object System.Drawing.Size(220, 24)
    $labelOriginalValue.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $groupOriginal.Controls.Add($labelOriginalValue)

    $groupSize = New-Object System.Windows.Forms.GroupBox
    $groupSize.Text = 'New size'
    $groupSize.Location = New-Object System.Drawing.Point(18, 166)
    $groupSize.Size = New-Object System.Drawing.Size(464, 104)
    $form.Controls.Add($groupSize)

    $labelWidth = New-Object System.Windows.Forms.Label
    $labelWidth.Text = 'Width'
    $labelWidth.Location = New-Object System.Drawing.Point(16, 27)
    $labelWidth.Size = New-Object System.Drawing.Size(50, 23)
    $groupSize.Controls.Add($labelWidth)

    $textWidthPx = New-Object System.Windows.Forms.TextBox
    $textWidthPx.Location = New-Object System.Drawing.Point(72, 24)
    $textWidthPx.Size = New-Object System.Drawing.Size(90, 23)
    $textWidthPx.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Right
    $textWidthPx.Tag = 'widthPx'
    $groupSize.Controls.Add($textWidthPx)

    $labelWidthPx = New-Object System.Windows.Forms.Label
    $labelWidthPx.Text = 'px'
    $labelWidthPx.Location = New-Object System.Drawing.Point(170, 27)
    $labelWidthPx.Size = New-Object System.Drawing.Size(24, 23)
    $groupSize.Controls.Add($labelWidthPx)

    $textWidthPct = New-Object System.Windows.Forms.TextBox
    $textWidthPct.Location = New-Object System.Drawing.Point(240, 24)
    $textWidthPct.Size = New-Object System.Drawing.Size(70, 23)
    $textWidthPct.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Right
    $textWidthPct.Tag = 'widthPct'
    $groupSize.Controls.Add($textWidthPct)

    $labelWidthPct = New-Object System.Windows.Forms.Label
    $labelWidthPct.Text = '%'
    $labelWidthPct.Location = New-Object System.Drawing.Point(318, 27)
    $labelWidthPct.Size = New-Object System.Drawing.Size(20, 23)
    $groupSize.Controls.Add($labelWidthPct)

    $labelHeight = New-Object System.Windows.Forms.Label
    $labelHeight.Text = 'Height'
    $labelHeight.Location = New-Object System.Drawing.Point(16, 59)
    $labelHeight.Size = New-Object System.Drawing.Size(50, 23)
    $groupSize.Controls.Add($labelHeight)

    $textHeightPx = New-Object System.Windows.Forms.TextBox
    $textHeightPx.Location = New-Object System.Drawing.Point(72, 56)
    $textHeightPx.Size = New-Object System.Drawing.Size(90, 23)
    $textHeightPx.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Right
    $textHeightPx.Tag = 'heightPx'
    $groupSize.Controls.Add($textHeightPx)

    $labelHeightPx = New-Object System.Windows.Forms.Label
    $labelHeightPx.Text = 'px'
    $labelHeightPx.Location = New-Object System.Drawing.Point(170, 59)
    $labelHeightPx.Size = New-Object System.Drawing.Size(24, 23)
    $groupSize.Controls.Add($labelHeightPx)

    $textHeightPct = New-Object System.Windows.Forms.TextBox
    $textHeightPct.Location = New-Object System.Drawing.Point(240, 56)
    $textHeightPct.Size = New-Object System.Drawing.Size(70, 23)
    $textHeightPct.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Right
    $textHeightPct.Tag = 'heightPct'
    $groupSize.Controls.Add($textHeightPct)

    $labelHeightPct = New-Object System.Windows.Forms.Label
    $labelHeightPct.Text = '%'
    $labelHeightPct.Location = New-Object System.Drawing.Point(318, 59)
    $labelHeightPct.Size = New-Object System.Drawing.Size(20, 23)
    $groupSize.Controls.Add($labelHeightPct)

    $checkLockRatio = New-Object System.Windows.Forms.CheckBox
    $checkLockRatio.Text = 'Keep ratio'
    $checkLockRatio.Checked = $true
    $checkLockRatio.Location = New-Object System.Drawing.Point(362, 39)
    $checkLockRatio.Size = New-Object System.Drawing.Size(90, 24)
    $groupSize.Controls.Add($checkLockRatio)

    $groupPresets = New-Object System.Windows.Forms.GroupBox
    $groupPresets.Text = 'Quick scale'
    $groupPresets.Location = New-Object System.Drawing.Point(18, 278)
    $groupPresets.Size = New-Object System.Drawing.Size(464, 62)
    $form.Controls.Add($groupPresets)

    $presetScales = @(0.5, 0.75, 1.5, 2.0, 4.0)
    $presetButtons = New-Object System.Collections.Generic.List[System.Windows.Forms.Button]
    $presetButtonWidth = 76
    $presetButtonHeight = 28
    $presetStartX = 16
    $presetGap = 12

    for ($i = 0; $i -lt $presetScales.Count; $i++) {
        $scale = [double]$presetScales[$i]
        $button = New-Object System.Windows.Forms.Button
        $button.Text = Format-ScaleButtonText $scale
        $button.Tag = $scale
        $button.Size = New-Object System.Drawing.Size($presetButtonWidth, $presetButtonHeight)
        $button.Location = New-Object System.Drawing.Point(($presetStartX + ($i * ($presetButtonWidth + $presetGap))), 22)
        $groupPresets.Controls.Add($button)
        [void]$presetButtons.Add($button)
    }

    $buttonReset = New-Object System.Windows.Forms.Button
    $buttonReset.Text = 'Reset'
    $buttonReset.Size = New-Object System.Drawing.Size(86, 30)
    $buttonReset.Location = New-Object System.Drawing.Point(18, 348)
    $form.Controls.Add($buttonReset)

    $buttonOK = New-Object System.Windows.Forms.Button
    $buttonOK.Text = 'OK'
    $buttonOK.Size = New-Object System.Drawing.Size(96, 30)
    $buttonOK.Location = New-Object System.Drawing.Point(286, 348)
    $buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($buttonOK)

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.Size = New-Object System.Drawing.Size(96, 30)
    $buttonCancel.Location = New-Object System.Drawing.Point(388, 348)
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($buttonCancel)

    $form.AcceptButton = $buttonOK
    $form.CancelButton = $buttonCancel

    function Set-AllFields {
        param(
            [int]$WidthPx,
            [int]$HeightPx
        )

        $script:updatingFields = $true

        if ($script:activeEditField -ne 'widthPx') {
            $textWidthPx.Text = $WidthPx.ToString([System.Globalization.CultureInfo]::InvariantCulture)
        }
        if ($script:activeEditField -ne 'heightPx') {
            $textHeightPx.Text = $HeightPx.ToString([System.Globalization.CultureInfo]::InvariantCulture)
        }
        if ($script:activeEditField -ne 'widthPct') {
            $textWidthPct.Text = Format-PercentText (([double]$WidthPx / [double]$OriginalWidth) * 100.0)
        }
        if ($script:activeEditField -ne 'heightPct') {
            $textHeightPct.Text = Format-PercentText (([double]$HeightPx / [double]$OriginalHeight) * 100.0)
        }

        $script:updatingFields = $false
    }

    function Set-FromWidthPx {
        param([int]$WidthPx)
        $heightPx = if ($checkLockRatio.Checked) {
            [Math]::Max(1, [int][Math]::Round([double]$WidthPx / $ratio))
        } else {
            $existingHeight = Try-ParsePositiveInt $textHeightPx.Text
            if ($null -eq $existingHeight) { $OriginalHeight } else { $existingHeight }
        }
        Set-AllFields $WidthPx $heightPx
    }

    function Set-FromHeightPx {
        param([int]$HeightPx)
        $widthPx = if ($checkLockRatio.Checked) {
            [Math]::Max(1, [int][Math]::Round([double]$HeightPx * $ratio))
        } else {
            $existingWidth = Try-ParsePositiveInt $textWidthPx.Text
            if ($null -eq $existingWidth) { $OriginalWidth } else { $existingWidth }
        }
        Set-AllFields $widthPx $HeightPx
    }

    function Set-FromWidthPct {
        param([double]$WidthPct)
        $widthPx = [Math]::Max(1, [int][Math]::Round(([double]$OriginalWidth * $WidthPct) / 100.0))
        Set-FromWidthPx $widthPx
    }

    function Set-FromHeightPct {
        param([double]$HeightPct)
        $heightPx = [Math]::Max(1, [int][Math]::Round(([double]$OriginalHeight * $HeightPct) / 100.0))
        Set-FromHeightPx $heightPx
    }

    function Apply-ScalePreset {
        param([double]$Scale)

        $widthPx = [Math]::Max(1, [int][Math]::Round([double]$OriginalWidth * $Scale))
        $heightPx = [Math]::Max(1, [int][Math]::Round([double]$OriginalHeight * $Scale))
        Set-AllFields $widthPx $heightPx
    }

    function Commit-Field {
        param([string]$FieldName)
        switch ($FieldName) {
            'widthPx' {
                $value = Try-ParsePositiveInt $textWidthPx.Text
                if ($null -ne $value) { Set-FromWidthPx $value }
            }
            'heightPx' {
                $value = Try-ParsePositiveInt $textHeightPx.Text
                if ($null -ne $value) { Set-FromHeightPx $value }
            }
            'widthPct' {
                $value = Try-ParsePositiveDouble $textWidthPct.Text
                if ($null -ne $value) { Set-FromWidthPct $value }
            }
            'heightPct' {
                $value = Try-ParsePositiveDouble $textHeightPct.Text
                if ($null -ne $value) { Set-FromHeightPct $value }
            }
        }
    }

    function Register-EditTracking {
        param([System.Windows.Forms.TextBox]$TextBox)

        $TextBox.Add_Enter({
            param($sender, $eventArgs)
            $script:activeEditField = [string]$sender.Tag
        })

        $TextBox.Add_Leave({
            param($sender, $eventArgs)
            $fieldName = [string]$sender.Tag
            if ($script:activeEditField -ne $fieldName) { return }
            $script:activeEditField = $null
            Commit-Field $fieldName
        })
    }

    function Register-PercentTypingBehavior {
        param([System.Windows.Forms.TextBox]$TextBox)

        $TextBox.Add_KeyPress({
            param($sender, $eventArgs)

            if ([char]::IsControl($eventArgs.KeyChar)) { return }
            if ([char]::IsDigit($eventArgs.KeyChar)) { return }

            $decimalSeparator = [System.Globalization.CultureInfo]::CurrentCulture.NumberFormat.NumberDecimalSeparator
            if ($eventArgs.KeyChar.ToString() -eq '.' -or $eventArgs.KeyChar.ToString() -eq ',') {
                $selectionStart = $sender.SelectionStart
                $selectionLength = $sender.SelectionLength
                $currentText = $sender.Text
                $nextText = $currentText.Remove($selectionStart, $selectionLength).Insert($selectionStart, $decimalSeparator)

                if ($nextText.IndexOf($decimalSeparator, [System.StringComparison]::Ordinal) -eq $selectionStart) {
                    $sender.Text = $nextText
                    $sender.SelectionStart = $selectionStart + $decimalSeparator.Length
                }

                $eventArgs.Handled = $true
                return
            }

            $eventArgs.Handled = $true
        })

        $TextBox.Add_TextChanged({
            param($sender, $eventArgs)

            if ($script:updatingFields) { return }
            if ($script:activeEditField -ne [string]$sender.Tag) { return }

            $sanitized = [regex]::Replace($sender.Text, '[^\d\.,]', '')
            if ($sanitized -ne $sender.Text) {
                $selectionStart = $sender.SelectionStart
                $script:updatingFields = $true
                $sender.Text = $sanitized
                $sender.SelectionStart = [Math]::Min($selectionStart, $sender.Text.Length)
                $script:updatingFields = $false
            }
        })
    }

    $textWidthPx.Add_TextChanged({
        param($sender, $eventArgs)
        if ($script:updatingFields) { return }
        if ($script:activeEditField -ne [string]$sender.Tag) { return }
        $value = Try-ParsePositiveInt $sender.Text
        if ($null -eq $value) { return }
        Set-FromWidthPx $value
    })

    $textHeightPx.Add_TextChanged({
        param($sender, $eventArgs)
        if ($script:updatingFields) { return }
        if ($script:activeEditField -ne [string]$sender.Tag) { return }
        $value = Try-ParsePositiveInt $sender.Text
        if ($null -eq $value) { return }
        Set-FromHeightPx $value
    })

    $textWidthPct.Add_TextChanged({
        param($sender, $eventArgs)
        if ($script:updatingFields) { return }
        if ($script:activeEditField -ne [string]$sender.Tag) { return }
        $value = Try-ParsePositiveDouble $sender.Text
        if ($null -eq $value) { return }
        Set-FromWidthPct $value
    })

    $textHeightPct.Add_TextChanged({
        param($sender, $eventArgs)
        if ($script:updatingFields) { return }
        if ($script:activeEditField -ne [string]$sender.Tag) { return }
        $value = Try-ParsePositiveDouble $sender.Text
        if ($null -eq $value) { return }
        Set-FromHeightPct $value
    })

    $checkLockRatio.Add_CheckedChanged({
        if (-not $checkLockRatio.Checked) { return }

        $widthPx = Try-ParsePositiveInt $textWidthPx.Text
        if ($null -ne $widthPx) {
            Set-FromWidthPx $widthPx
            return
        }

        $heightPx = Try-ParsePositiveInt $textHeightPx.Text
        if ($null -ne $heightPx) {
            Set-FromHeightPx $heightPx
            return
        }

        Set-AllFields $OriginalWidth $OriginalHeight
    })

    Register-EditTracking $textWidthPx
    Register-EditTracking $textHeightPx
    Register-EditTracking $textWidthPct
    Register-EditTracking $textHeightPct
    Register-PercentTypingBehavior $textWidthPct
    Register-PercentTypingBehavior $textHeightPct

    foreach ($presetButton in $presetButtons) {
        $presetButton.Add_Click({
            param($sender, $eventArgs)
            Apply-ScalePreset ([double]$sender.Tag)
        })
    }

    $buttonReset.Add_Click({
        $checkLockRatio.Checked = $true
        Set-AllFields $OriginalWidth $OriginalHeight
        $textWidthPx.Focus()
        $textWidthPx.SelectAll()
    })

    Set-AllFields $OriginalWidth $OriginalHeight

    $form.Add_Shown({
        $textWidthPx.Focus()
        $textWidthPx.SelectAll()
    })

    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        $form.Dispose()
        return $null
    }

    $newWidth = Try-ParsePositiveInt $textWidthPx.Text
    $newHeight = Try-ParsePositiveInt $textHeightPx.Text
    $form.Dispose()

    if ($null -eq $newWidth -or $null -eq $newHeight) {
        throw 'Width and height must be positive values.'
    }

    return Normalize-VideoDimensions -Width $newWidth -Height $newHeight
}

function New-FFmpegArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)]$EncodingProfile,
        [Parameter(Mandatory = $true)][int]$Width,
        [Parameter(Mandatory = $true)][int]$Height
    )

    $scaleFilter = 'scale={0}:{1}' -f $Width, $Height
    $ffmpegArgs = @(
        '-hide_banner',
        '-loglevel', 'error',
        '-progress', 'pipe:1',
        '-nostats',
        '-y',
        '-i', $InputFile,
        '-map', '0:v:0?',
        '-map', '0:a?',
        '-sn',
        '-dn',
        '-vf', $scaleFilter,
        '-c:v', $EncodingProfile.VideoCodec
    )

    $ffmpegArgs += $EncodingProfile.VideoArgs
    $ffmpegArgs += @('-c:a', $EncodingProfile.AudioCodec)
    $ffmpegArgs += $EncodingProfile.AudioArgs
    $ffmpegArgs += @($OutputFile)

    return ,$ffmpegArgs
}

#__FFCOMMON_INJECT_HERE__

try {
    if ([string]::IsNullOrWhiteSpace($InputFile)) {
        Show-Error 'Input file is missing.'
        exit 1
    }

    if (-not (Test-Path -LiteralPath $InputFile)) {
        Show-Error "Input file not found.`n$InputFile"
        exit 1
    }

    $sourceExtension = [System.IO.Path]::GetExtension($InputFile).ToLowerInvariant()
    if ($sourceExtension -notin @('.mp4', '.mkv', '.avi', '.mov', '.webm', '.m4v')) {
        Show-Error 'Unsupported source format. Supported video formats: .mp4, .mkv, .avi, .mov, .webm, .m4v'
        exit 1
    }

    $ffmpegPath = Get-ToolPath 'ffmpeg.exe'
    $ffprobePath = Get-ToolPath 'ffprobe.exe'
    if (-not (Test-Path -LiteralPath $ffmpegPath)) {
        Show-Error "ffmpeg.exe not found.`n$ffmpegPath"
        exit 1
    }
    if (-not (Test-Path -LiteralPath $ffprobePath)) {
        Show-Error "ffprobe.exe not found.`n$ffprobePath"
        exit 1
    }

    $videoInfo = Get-VideoInfo -FfprobePath $ffprobePath -FilePath $InputFile
    $targetSize = Get-AutomationResizeSelection -SourceWidth $videoInfo.Width -SourceHeight $videoInfo.Height
    if ($null -eq $targetSize) {
        $targetSize = Show-ResizeWindow -OriginalWidth $videoInfo.Width -OriginalHeight $videoInfo.Height
        if ($null -eq $targetSize) {
            exit 0
        }
    }

    $nvencAvailable = Test-NvencAvailable -FfmpegPath $ffmpegPath
    $encodingPlan = Get-EncodingPlan -TargetExtension $sourceExtension -NvencAvailable $nvencAvailable

    $inputDir = Split-Path -Parent $InputFile
    $inputBase = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $desiredOutput = Join-Path $inputDir ($inputBase + '_resize_' + $targetSize.Width + 'x' + $targetSize.Height + $sourceExtension)
    $script:OutputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

    $result = Invoke-WithEncodingPlan `
        -FfmpegPath $ffmpegPath `
        -EncodingPlan $encodingPlan `
        -DurationSeconds ([double]$videoInfo.DurationSeconds) `
        -Title 'Resize video' `
        -PreparingText 'Preparing video resize...' `
        -FallbackPreparingText 'GPU unavailable. Retrying in CPU mode...' `
        -OutputFile $script:OutputFile `
        -ArgumentFactory {
            param($profile)
            New-FFmpegArguments -InputFile $InputFile -OutputFile $script:OutputFile -EncodingProfile $profile -Width $targetSize.Width -Height $targetSize.Height
        }

    if ($result.Cancelled) {
        Remove-PartialOutput -Path $script:OutputFile
        exit 0
    }

    if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $script:OutputFile)) {
        Remove-PartialOutput -Path $script:OutputFile
        Show-Error (Get-ShortErrorText -StdErr $result.StdErr)
        exit 1
    }

    exit 0
}
catch {
    if ($script:OutputFile) {
        Remove-PartialOutput -Path $script:OutputFile
    }

    $message = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = 'Unknown video resize error.'
    }
    Show-Error $message
    exit 1
}
