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

    return 'FFmpeg failed during video crop.'
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

    return [PSCustomObject]@{
        DurationSeconds = $durationSeconds
        Width           = $width
        Height          = $height
    }
}

function New-PreviewBitmap {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$MaxWidth,
        [Parameter(Mandatory = $true)][int]$MaxHeight
    )

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $source = [System.Drawing.Image]::FromStream($stream, $false, $false)
        try {
            $scale = [Math]::Min(($MaxWidth / [double]$source.Width), ($MaxHeight / [double]$source.Height))
            if ($scale -gt 1.0) { $scale = 1.0 }
            $previewWidth = [Math]::Max(1, [int][Math]::Round($source.Width * $scale))
            $previewHeight = [Math]::Max(1, [int][Math]::Round($source.Height * $scale))

            $bitmap = New-Object System.Drawing.Bitmap($previewWidth, $previewHeight)
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.DrawImage($source, 0, 0, $previewWidth, $previewHeight)
            }
            finally {
                $graphics.Dispose()
            }

            return $bitmap
        }
        finally {
            $source.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function New-VideoPreviewBitmap {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [Parameter(Mandatory = $true)][double]$TimeSeconds,
        [Parameter(Mandatory = $true)][int]$MaxWidth,
        [Parameter(Mandatory = $true)][int]$MaxHeight
    )

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $safeSeconds = [Math]::Max(0.0, $TimeSeconds)
    $timeText = $safeSeconds.ToString('0.###', $culture)
    $tmpPath = Join-Path ([System.IO.Path]::GetTempPath()) ("ffactions_video_crop_preview_{0}.png" -f ([guid]::NewGuid().ToString('N')))

    try {
        $args = @(
            '-hide_banner',
            '-loglevel', 'error',
            '-y',
            '-ss', $timeText,
            '-i', $InputFile,
            '-frames:v', '1',
            $tmpPath
        )

        $result = Invoke-HiddenProcess -FilePath $FfmpegPath -Arguments $args
        if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $tmpPath)) {
            throw (Get-ShortErrorText -StdErr $result.StdErr)
        }

        return New-PreviewBitmap -Path $tmpPath -MaxWidth $MaxWidth -MaxHeight $MaxHeight
    }
    finally {
        Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue
    }
}

function Get-RatioValue {
    param([string]$Mode)

    switch ($Mode) {
        'Square' { return 1.0 }
        '16:9'   { return (16.0 / 9.0) }
        '9:16'   { return (9.0 / 16.0) }
        '4:3'    { return (4.0 / 3.0) }
        default  { return $null }
    }
}

function Set-ControlDoubleBuffered {
    param([Parameter(Mandatory = $true)]$Control)

    $doubleBufferedProperty = $Control.GetType().GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'Instance, NonPublic')
    if ($doubleBufferedProperty) {
        $doubleBufferedProperty.SetValue($Control, $true, $null)
    }
}

function Get-NormalizedRect {
    param([System.Drawing.RectangleF]$Rect)

    $x = [Math]::Min($Rect.Left, $Rect.Right)
    $y = [Math]::Min($Rect.Top, $Rect.Bottom)
    $w = [Math]::Abs($Rect.Width)
    $h = [Math]::Abs($Rect.Height)
    return New-Object System.Drawing.RectangleF($x, $y, $w, $h)
}

function Clamp-CropRect {
    param(
        [System.Drawing.RectangleF]$Rect,
        [System.Drawing.RectangleF]$Bounds,
        [Nullable[double]]$Ratio
    )

    $r = Get-NormalizedRect -Rect $Rect
    $minSize = 12.0

    if ($null -ne $Ratio) {
        if ($r.Width / [double]$r.Height -gt $Ratio) {
            $r.Width = [float]($r.Height * $Ratio)
        }
        else {
            $r.Height = [float]($r.Width / $Ratio)
        }
    }

    if ($r.Width -lt $minSize) { $r.Width = [float]$minSize }
    if ($r.Height -lt $minSize) { $r.Height = [float]$minSize }

    if ($null -ne $Ratio) {
        if ($r.Width -gt $Bounds.Width) {
            $r.Width = [float]$Bounds.Width
            $r.Height = [float]($r.Width / $Ratio)
        }
        if ($r.Height -gt $Bounds.Height) {
            $r.Height = [float]$Bounds.Height
            $r.Width = [float]($r.Height * $Ratio)
        }
    }
    else {
        if ($r.Width -gt $Bounds.Width) { $r.Width = [float]$Bounds.Width }
        if ($r.Height -gt $Bounds.Height) { $r.Height = [float]$Bounds.Height }
    }

    if ($r.X -lt $Bounds.X) { $r.X = [float]$Bounds.X }
    if ($r.Y -lt $Bounds.Y) { $r.Y = [float]$Bounds.Y }
    if ($r.Right -gt $Bounds.Right) { $r.X = [float]($Bounds.Right - $r.Width) }
    if ($r.Bottom -gt $Bounds.Bottom) { $r.Y = [float]($Bounds.Bottom - $r.Height) }

    return $r
}

function Format-TimeForDisplay {
    param([Parameter(Mandatory = $true)][double]$Seconds)

    if ($Seconds -lt 0) { $Seconds = 0 }
    $hours = [int][Math]::Floor($Seconds / 3600)
    $remaining = $Seconds - ($hours * 3600)
    $minutes = [int][Math]::Floor($remaining / 60)
    $secs = $remaining - ($minutes * 60)
    $culture = [System.Globalization.CultureInfo]::InvariantCulture

    return [string]::Format($culture, '{0:D2}:{1:D2}:{2:00.000}', $hours, $minutes, $secs)
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

function Normalize-VideoCropRect {
    param(
        [Parameter(Mandatory = $true)][int]$X,
        [Parameter(Mandatory = $true)][int]$Y,
        [Parameter(Mandatory = $true)][int]$Width,
        [Parameter(Mandatory = $true)][int]$Height,
        [Parameter(Mandatory = $true)][int]$SourceWidth,
        [Parameter(Mandatory = $true)][int]$SourceHeight
    )

    if ($X -lt 0) { $X = 0 }
    if ($Y -lt 0) { $Y = 0 }
    if ($Width -lt 1) { $Width = 1 }
    if ($Height -lt 1) { $Height = 1 }
    if ($X + $Width -gt $SourceWidth) { $Width = $SourceWidth - $X }
    if ($Y + $Height -gt $SourceHeight) { $Height = $SourceHeight - $Y }

    if ($Width -gt 1 -and ($Width % 2) -ne 0) {
        if ($X + $Width -lt $SourceWidth) { $Width++ } else { $Width-- }
    }
    if ($Height -gt 1 -and ($Height % 2) -ne 0) {
        if ($Y + $Height -lt $SourceHeight) { $Height++ } else { $Height-- }
    }
    if ($X -gt 0 -and ($X % 2) -ne 0) { $X-- }
    if ($Y -gt 0 -and ($Y % 2) -ne 0) { $Y-- }

    if ($X + $Width -gt $SourceWidth) { $Width = $SourceWidth - $X }
    if ($Y + $Height -gt $SourceHeight) { $Height = $SourceHeight - $Y }
    if ($Width -lt 1) { $Width = 1 }
    if ($Height -lt 1) { $Height = 1 }

    return [PSCustomObject]@{
        X      = $X
        Y      = $Y
        Width  = $Width
        Height = $Height
    }
}

function Show-CropWindow {
    param(
        [Parameter(Mandatory = $true)][string]$VideoPath,
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [Parameter(Mandatory = $true)][int]$SourceWidth,
        [Parameter(Mandatory = $true)][int]$SourceHeight,
        [Parameter(Mandatory = $true)][double]$DurationSeconds
    )

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $script:previewBitmap = $null
    $script:backgroundBitmap = $null
    $script:cropRect = New-Object System.Drawing.RectangleF(0, 0, 1, 1)
    $script:imageBounds = New-Object System.Drawing.RectangleF(0, 0, 1, 1)
    $script:dragMode = ''
    $script:dragStart = New-Object System.Drawing.PointF(0, 0)
    $script:dragRect = New-Object System.Drawing.RectangleF(0, 0, 1, 1)
    $script:pendingPreviewSeconds = 0.0
    $script:currentPreviewSeconds = 0.0

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFActions - Crop video'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(940, 690)
    $form.TopMost = $true

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(12, 12)
    $panel.Size = New-Object System.Drawing.Size(780, 500)
    $panel.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 32)
    Set-ControlDoubleBuffered -Control $panel
    $form.Controls.Add($panel)

    $trackPreview = New-Object System.Windows.Forms.TrackBar
    $trackPreview.Location = New-Object System.Drawing.Point(12, 524)
    $trackPreview.Size = New-Object System.Drawing.Size(780, 45)
    $trackPreview.Minimum = 0
    $trackPreview.Maximum = 1000
    $trackPreview.TickFrequency = 100
    $trackPreview.SmallChange = 5
    $trackPreview.LargeChange = 50
    $form.Controls.Add($trackPreview)

    $labelTimelineHint = New-Object System.Windows.Forms.Label
    $labelTimelineHint.Location = New-Object System.Drawing.Point(12, 564)
    $labelTimelineHint.Size = New-Object System.Drawing.Size(780, 20)
    $labelTimelineHint.Text = 'Drag the slider to preview another moment of the video.'
    $form.Controls.Add($labelTimelineHint)

    $group = New-Object System.Windows.Forms.GroupBox
    $group.Text = 'Ratio'
    $group.Location = New-Object System.Drawing.Point(806, 12)
    $group.Size = New-Object System.Drawing.Size(120, 176)
    $form.Controls.Add($group)

    $ratioOptions = @('Free', 'Square', '16:9', '9:16', '4:3')
    $radioButtons = @()
    for ($i = 0; $i -lt $ratioOptions.Count; $i++) {
        $radio = New-Object System.Windows.Forms.RadioButton
        $radio.Text = $ratioOptions[$i]
        $radio.Tag = $ratioOptions[$i]
        $radio.Location = New-Object System.Drawing.Point(14, (24 + ($i * 28)))
        $radio.Size = New-Object System.Drawing.Size(90, 24)
        if ($i -eq 0) { $radio.Checked = $true }
        $group.Controls.Add($radio)
        $radioButtons += $radio
    }

    $labelInfo = New-Object System.Windows.Forms.Label
    $labelInfo.Location = New-Object System.Drawing.Point(806, 206)
    $labelInfo.Size = New-Object System.Drawing.Size(120, 60)
    $labelInfo.Text = "Video:`r`n$SourceWidth x $SourceHeight`r`n$(Format-TimeForDisplay -Seconds $DurationSeconds)"
    $form.Controls.Add($labelInfo)

    $labelFrame = New-Object System.Windows.Forms.Label
    $labelFrame.Location = New-Object System.Drawing.Point(806, 278)
    $labelFrame.Size = New-Object System.Drawing.Size(120, 42)
    $form.Controls.Add($labelFrame)

    $labelSize = New-Object System.Windows.Forms.Label
    $labelSize.Location = New-Object System.Drawing.Point(806, 332)
    $labelSize.Size = New-Object System.Drawing.Size(120, 42)
    $form.Controls.Add($labelSize)

    $buttonCenter = New-Object System.Windows.Forms.Button
    $buttonCenter.Text = 'Center'
    $buttonCenter.Location = New-Object System.Drawing.Point(806, 388)
    $buttonCenter.Size = New-Object System.Drawing.Size(120, 28)
    $form.Controls.Add($buttonCenter)

    $buttonReset = New-Object System.Windows.Forms.Button
    $buttonReset.Text = 'Reset'
    $buttonReset.Location = New-Object System.Drawing.Point(806, 426)
    $buttonReset.Size = New-Object System.Drawing.Size(120, 28)
    $form.Controls.Add($buttonReset)

    $buttonOK = New-Object System.Windows.Forms.Button
    $buttonOK.Text = 'OK'
    $buttonOK.Location = New-Object System.Drawing.Point(734, 650)
    $buttonOK.Size = New-Object System.Drawing.Size(90, 28)
    $buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($buttonOK)

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.Location = New-Object System.Drawing.Point(836, 650)
    $buttonCancel.Size = New-Object System.Drawing.Size(90, 28)
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($buttonCancel)

    $form.AcceptButton = $buttonOK
    $form.CancelButton = $buttonCancel

    $previewTimer = New-Object System.Windows.Forms.Timer
    $previewTimer.Interval = 140

    function Dispose-PreviewBitmaps {
        if ($script:backgroundBitmap) {
            $script:backgroundBitmap.Dispose()
            $script:backgroundBitmap = $null
        }
        if ($script:previewBitmap) {
            $script:previewBitmap.Dispose()
            $script:previewBitmap = $null
        }
    }

    function Get-SelectedRatioMode {
        $selected = $radioButtons | Where-Object { $_.Checked } | Select-Object -First 1
        if ($selected) { return [string]$selected.Tag }
        return 'Free'
    }

    function Update-ImageBounds {
        $x = [Math]::Floor(($panel.ClientSize.Width - $script:previewBitmap.Width) / 2.0)
        $y = [Math]::Floor(($panel.ClientSize.Height - $script:previewBitmap.Height) / 2.0)
        $script:imageBounds = New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$script:previewBitmap.Width, [float]$script:previewBitmap.Height)

        if ($script:backgroundBitmap) {
            $script:backgroundBitmap.Dispose()
            $script:backgroundBitmap = $null
        }

        $script:backgroundBitmap = New-Object System.Drawing.Bitmap($panel.ClientSize.Width, $panel.ClientSize.Height)
        $g = [System.Drawing.Graphics]::FromImage($script:backgroundBitmap)
        try {
            $g.Clear($panel.BackColor)
            $g.DrawImageUnscaled($script:previewBitmap, [int]$script:imageBounds.X, [int]$script:imageBounds.Y)
        }
        finally {
            $g.Dispose()
        }
    }

    function Reset-CropRect {
        $mode = Get-SelectedRatioMode
        $ratio = Get-RatioValue -Mode $mode
        $margin = 0.08
        $w = $script:imageBounds.Width * (1.0 - ($margin * 2.0))
        $h = $script:imageBounds.Height * (1.0 - ($margin * 2.0))

        if ($null -ne $ratio) {
            if ($w / [double]$h -gt $ratio) {
                $w = $h * $ratio
            }
            else {
                $h = $w / $ratio
            }
        }

        $x = $script:imageBounds.X + (($script:imageBounds.Width - $w) / 2.0)
        $y = $script:imageBounds.Y + (($script:imageBounds.Height - $h) / 2.0)
        $script:cropRect = New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$w, [float]$h)
    }

    function Center-CropRect {
        $script:cropRect.X = [float]($script:imageBounds.X + (($script:imageBounds.Width - $script:cropRect.Width) / 2.0))
        $script:cropRect.Y = [float]($script:imageBounds.Y + (($script:imageBounds.Height - $script:cropRect.Height) / 2.0))
        $mode = Get-SelectedRatioMode
        $script:cropRect = Clamp-CropRect -Rect $script:cropRect -Bounds $script:imageBounds -Ratio (Get-RatioValue -Mode $mode)
    }

    function Get-SourceCropRect {
        $scaleX = $SourceWidth / [double]$script:imageBounds.Width
        $scaleY = $SourceHeight / [double]$script:imageBounds.Height
        $x = [int][Math]::Round(($script:cropRect.X - $script:imageBounds.X) * $scaleX)
        $y = [int][Math]::Round(($script:cropRect.Y - $script:imageBounds.Y) * $scaleY)
        $w = [int][Math]::Round($script:cropRect.Width * $scaleX)
        $h = [int][Math]::Round($script:cropRect.Height * $scaleY)

        return Normalize-VideoCropRect -X $x -Y $y -Width $w -Height $h -SourceWidth $SourceWidth -SourceHeight $SourceHeight
    }

    function Set-CropRectFromSource {
        param([Parameter(Mandatory = $true)]$SourceCrop)

        $scaleX = $script:imageBounds.Width / [double]$SourceWidth
        $scaleY = $script:imageBounds.Height / [double]$SourceHeight
        $x = [float]($script:imageBounds.X + ($SourceCrop.X * $scaleX))
        $y = [float]($script:imageBounds.Y + ($SourceCrop.Y * $scaleY))
        $w = [float]($SourceCrop.Width * $scaleX)
        $h = [float]($SourceCrop.Height * $scaleY)
        $script:cropRect = New-Object System.Drawing.RectangleF($x, $y, $w, $h)
        $script:cropRect = Clamp-CropRect -Rect $script:cropRect -Bounds $script:imageBounds -Ratio (Get-RatioValue -Mode (Get-SelectedRatioMode))
    }

    function Update-SizeLabel {
        $r = Get-SourceCropRect
        $labelSize.Text = "Crop:`r`n$($r.Width) x $($r.Height) px"
    }

    function Update-FrameLabel {
        param([Parameter(Mandatory = $true)][double]$Seconds)

        $labelFrame.Text = "Frame:`r`n$(Format-TimeForDisplay -Seconds $Seconds)"
    }

    function Request-CropRedraw {
        param(
            [Parameter(Mandatory = $true)][System.Drawing.RectangleF]$OldRect,
            [Parameter(Mandatory = $true)][System.Drawing.RectangleF]$NewRect
        )

        $oldNorm = Get-NormalizedRect -Rect $OldRect
        $newNorm = Get-NormalizedRect -Rect $NewRect
        $union = [System.Drawing.RectangleF]::Union($oldNorm, $newNorm)
        $inflate = 18.0
        $union.Inflate($inflate, $inflate)

        $left = [Math]::Max(0, [int][Math]::Floor($union.X))
        $top = [Math]::Max(0, [int][Math]::Floor($union.Y))
        $right = [Math]::Min($panel.ClientSize.Width, [int][Math]::Ceiling($union.Right))
        $bottom = [Math]::Min($panel.ClientSize.Height, [int][Math]::Ceiling($union.Bottom))

        if ($right -le $left -or $bottom -le $top) {
            $panel.Invalidate()
            return
        }

        $rect = New-Object System.Drawing.Rectangle($left, $top, ($right - $left), ($bottom - $top))
        $panel.Invalidate($rect)
    }

    function Get-HitMode {
        param([System.Drawing.PointF]$Point)

        $r = $script:cropRect
        $handle = 9.0
        $nearLeft = [Math]::Abs($Point.X - $r.Left) -le $handle
        $nearRight = [Math]::Abs($Point.X - $r.Right) -le $handle
        $nearTop = [Math]::Abs($Point.Y - $r.Top) -le $handle
        $nearBottom = [Math]::Abs($Point.Y - $r.Bottom) -le $handle

        if ($nearLeft -and $nearTop) { return 'tl' }
        if ($nearRight -and $nearTop) { return 'tr' }
        if ($nearLeft -and $nearBottom) { return 'bl' }
        if ($nearRight -and $nearBottom) { return 'br' }
        if ($r.Contains($Point)) { return 'move' }
        return ''
    }

    function Apply-RatioToCurrentCrop {
        $oldRect = $script:cropRect
        $mode = Get-SelectedRatioMode
        $ratio = Get-RatioValue -Mode $mode
        $script:cropRect = Clamp-CropRect -Rect $script:cropRect -Bounds $script:imageBounds -Ratio $ratio
        Center-CropRect
        Update-SizeLabel
        Request-CropRedraw -OldRect $oldRect -NewRect $script:cropRect
    }

    function Load-PreviewFrame {
        param(
            [Parameter(Mandatory = $true)][double]$Seconds,
            [bool]$PreserveCrop = $true
        )

        $oldSourceCrop = $null
        if ($PreserveCrop -and $script:imageBounds.Width -gt 1 -and $script:imageBounds.Height -gt 1 -and $script:cropRect.Width -gt 1 -and $script:cropRect.Height -gt 1) {
            $oldSourceCrop = Get-SourceCropRect
        }

        $newBitmap = New-VideoPreviewBitmap -InputFile $VideoPath -FfmpegPath $FfmpegPath -TimeSeconds $Seconds -MaxWidth 760 -MaxHeight 500
        Dispose-PreviewBitmaps
        $script:previewBitmap = $newBitmap
        Update-ImageBounds

        if ($oldSourceCrop) {
            Set-CropRectFromSource -SourceCrop $oldSourceCrop
        }
        else {
            Reset-CropRect
        }

        $script:currentPreviewSeconds = $Seconds
        Update-FrameLabel -Seconds $Seconds
        Update-SizeLabel
        $panel.Invalidate()
    }

    $previewTimer.Add_Tick({
        $previewTimer.Stop()
        try {
            Load-PreviewFrame -Seconds $script:pendingPreviewSeconds -PreserveCrop $true
        }
        catch {
            Show-Error $_.Exception.Message
        }
    })

    $panel.Add_Paint({
        param($sender, $e)

        $g = $e.Graphics
        if ($script:backgroundBitmap) {
            $g.DrawImageUnscaled($script:backgroundBitmap, 0, 0)
        }
        else {
            $g.Clear($panel.BackColor)
        }

        $overlayBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120, 0, 0, 0))
        try {
            $outer = New-Object System.Drawing.Region($script:imageBounds)
            $outer.Exclude($script:cropRect)
            $g.FillRegion($overlayBrush, $outer)
            $outer.Dispose()
        }
        finally {
            $overlayBrush.Dispose()
        }

        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)
        $accentPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(32, 145, 255), 1)
        $handleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        try {
            $g.DrawRectangle($pen, [int]$script:cropRect.X, [int]$script:cropRect.Y, [int]$script:cropRect.Width, [int]$script:cropRect.Height)
            $thirdW = $script:cropRect.Width / 3.0
            $thirdH = $script:cropRect.Height / 3.0
            $g.DrawLine($accentPen, [float]($script:cropRect.X + $thirdW), $script:cropRect.Top, [float]($script:cropRect.X + $thirdW), $script:cropRect.Bottom)
            $g.DrawLine($accentPen, [float]($script:cropRect.X + ($thirdW * 2.0)), $script:cropRect.Top, [float]($script:cropRect.X + ($thirdW * 2.0)), $script:cropRect.Bottom)
            $g.DrawLine($accentPen, $script:cropRect.Left, [float]($script:cropRect.Y + $thirdH), $script:cropRect.Right, [float]($script:cropRect.Y + $thirdH))
            $g.DrawLine($accentPen, $script:cropRect.Left, [float]($script:cropRect.Y + ($thirdH * 2.0)), $script:cropRect.Right, [float]($script:cropRect.Y + ($thirdH * 2.0)))

            foreach ($pt in @(
                @{ X = $script:cropRect.Left; Y = $script:cropRect.Top },
                @{ X = $script:cropRect.Right; Y = $script:cropRect.Top },
                @{ X = $script:cropRect.Left; Y = $script:cropRect.Bottom },
                @{ X = $script:cropRect.Right; Y = $script:cropRect.Bottom }
            )) {
                $g.FillRectangle($handleBrush, [float]($pt.X - 4), [float]($pt.Y - 4), 8, 8)
            }
        }
        finally {
            $pen.Dispose()
            $accentPen.Dispose()
            $handleBrush.Dispose()
        }
    })

    $panel.Add_MouseDown({
        param($sender, $e)
        if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
        $p = New-Object System.Drawing.PointF([float]$e.X, [float]$e.Y)
        $script:dragMode = Get-HitMode -Point $p
        if ($script:dragMode -eq '') { return }
        $script:dragStart = $p
        $script:dragRect = $script:cropRect
    })

    $panel.Add_MouseMove({
        param($sender, $e)
        $p = New-Object System.Drawing.PointF([float]$e.X, [float]$e.Y)
        if ($script:dragMode -eq '') {
            $hit = Get-HitMode -Point $p
            if ($hit -eq 'move') {
                $panel.Cursor = [System.Windows.Forms.Cursors]::SizeAll
            }
            elseif ($hit -in @('tl', 'br')) {
                $panel.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
            }
            elseif ($hit -in @('tr', 'bl')) {
                $panel.Cursor = [System.Windows.Forms.Cursors]::SizeNESW
            }
            else {
                $panel.Cursor = [System.Windows.Forms.Cursors]::Default
            }
            return
        }

        $dx = $p.X - $script:dragStart.X
        $dy = $p.Y - $script:dragStart.Y
        $r = New-Object System.Drawing.RectangleF($script:dragRect.X, $script:dragRect.Y, $script:dragRect.Width, $script:dragRect.Height)

        if ($script:dragMode -eq 'move') {
            $r.X = [float]($script:dragRect.X + $dx)
            $r.Y = [float]($script:dragRect.Y + $dy)
        }
        else {
            if ($script:dragMode.Contains('l')) {
                $r.X = [float]($script:dragRect.X + $dx)
                $r.Width = [float]($script:dragRect.Width - $dx)
            }
            if ($script:dragMode.Contains('r')) {
                $r.Width = [float]($script:dragRect.Width + $dx)
            }
            if ($script:dragMode.Contains('t')) {
                $r.Y = [float]($script:dragRect.Y + $dy)
                $r.Height = [float]($script:dragRect.Height - $dy)
            }
            if ($script:dragMode.Contains('b')) {
                $r.Height = [float]($script:dragRect.Height + $dy)
            }
        }

        $ratio = Get-RatioValue -Mode (Get-SelectedRatioMode)
        $oldRect = $script:cropRect
        $script:cropRect = Clamp-CropRect -Rect $r -Bounds $script:imageBounds -Ratio $ratio
        Update-SizeLabel
        Request-CropRedraw -OldRect $oldRect -NewRect $script:cropRect
    })

    $panel.Add_MouseUp({
        $script:dragMode = ''
    })

    foreach ($radio in $radioButtons) {
        $radio.Add_CheckedChanged({
            param($sender, $e)
            if ($sender.Checked) { Apply-RatioToCurrentCrop }
        })
    }

    $buttonCenter.Add_Click({
        $oldRect = $script:cropRect
        Center-CropRect
        Update-SizeLabel
        Request-CropRedraw -OldRect $oldRect -NewRect $script:cropRect
    })

    $buttonReset.Add_Click({
        $oldRect = $script:cropRect
        Reset-CropRect
        Update-SizeLabel
        Request-CropRedraw -OldRect $oldRect -NewRect $script:cropRect
    })

    $trackPreview.Add_ValueChanged({
        $ratio = if ($trackPreview.Maximum -gt 0) { $trackPreview.Value / [double]$trackPreview.Maximum } else { 0.0 }
        $safeDuration = [Math]::Max(0.0, $DurationSeconds - 0.05)
        $script:pendingPreviewSeconds = [Math]::Min($safeDuration, ($DurationSeconds * $ratio))
        Update-FrameLabel -Seconds $script:pendingPreviewSeconds
        $previewTimer.Stop()
        $previewTimer.Start()
    })

    $trackPreview.Add_MouseUp({
        $previewTimer.Stop()
        try {
            Load-PreviewFrame -Seconds $script:pendingPreviewSeconds -PreserveCrop $true
        }
        catch {
            Show-Error $_.Exception.Message
        }
    })

    $trackPreview.Add_KeyUp({
        $previewTimer.Stop()
        try {
            Load-PreviewFrame -Seconds $script:pendingPreviewSeconds -PreserveCrop $true
        }
        catch {
            Show-Error $_.Exception.Message
        }
    })

    try {
        Load-PreviewFrame -Seconds 0.0 -PreserveCrop $false
    }
    catch {
        Dispose-PreviewBitmaps
        $form.Dispose()
        throw
    }

    $result = $form.ShowDialog()
    $previewTimer.Stop()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Dispose-PreviewBitmaps
        $previewTimer.Dispose()
        $form.Dispose()
        return $null
    }

    $sourceCrop = Get-SourceCropRect
    Dispose-PreviewBitmaps
    $previewTimer.Dispose()
    $form.Dispose()
    return $sourceCrop
}

function Get-EnvironmentValue {
    param([Parameter(Mandatory = $true)][string]$Name)

    $value = [System.Environment]::GetEnvironmentVariable($Name, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $null
    }

    return $value.Trim()
}

function Get-AutomationCropRect {
    param(
        [Parameter(Mandatory = $true)][int]$SourceWidth,
        [Parameter(Mandatory = $true)][int]$SourceHeight
    )

    $flag = Get-EnvironmentValue -Name 'FFACTIONS_VIDEO_CROP_AUTOMATION'
    if ([string]::IsNullOrWhiteSpace($flag)) {
        return $null
    }

    switch ($flag.ToLowerInvariant()) {
        '1' {}
        'true' {}
        'yes' {}
        default { return $null }
    }

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $x = 0
    $y = 0
    $w = 0
    $h = 0

    if (-not [int]::TryParse((Get-EnvironmentValue -Name 'FFACTIONS_VIDEO_CROP_X'), [ref]$x)) {
        throw 'Invalid or missing FFACTIONS_VIDEO_CROP_X.'
    }
    if (-not [int]::TryParse((Get-EnvironmentValue -Name 'FFACTIONS_VIDEO_CROP_Y'), [ref]$y)) {
        throw 'Invalid or missing FFACTIONS_VIDEO_CROP_Y.'
    }
    if (-not [int]::TryParse((Get-EnvironmentValue -Name 'FFACTIONS_VIDEO_CROP_WIDTH'), [ref]$w)) {
        throw 'Invalid or missing FFACTIONS_VIDEO_CROP_WIDTH.'
    }
    if (-not [int]::TryParse((Get-EnvironmentValue -Name 'FFACTIONS_VIDEO_CROP_HEIGHT'), [ref]$h)) {
        throw 'Invalid or missing FFACTIONS_VIDEO_CROP_HEIGHT.'
    }

    return Normalize-VideoCropRect -X $x -Y $y -Width $w -Height $h -SourceWidth $SourceWidth -SourceHeight $SourceHeight
}

function New-FFmpegArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)]$EncodingProfile,
        [Parameter(Mandatory = $true)][int]$X,
        [Parameter(Mandatory = $true)][int]$Y,
        [Parameter(Mandatory = $true)][int]$Width,
        [Parameter(Mandatory = $true)][int]$Height
    )

    $cropFilter = 'crop={0}:{1}:{2}:{3}' -f $Width, $Height, $X, $Y
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
        '-vf', $cropFilter,
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
    $crop = Get-AutomationCropRect -SourceWidth $videoInfo.Width -SourceHeight $videoInfo.Height
    if ($null -eq $crop) {
        $crop = Show-CropWindow -VideoPath $InputFile -FfmpegPath $ffmpegPath -SourceWidth $videoInfo.Width -SourceHeight $videoInfo.Height -DurationSeconds $videoInfo.DurationSeconds
        if ($null -eq $crop) {
            exit 0
        }
    }

    $nvencAvailable = Test-NvencAvailable -FfmpegPath $ffmpegPath
    $encodingPlan = Get-EncodingPlan -TargetExtension $sourceExtension -NvencAvailable $nvencAvailable

    $inputDir = Split-Path -Parent $InputFile
    $inputBase = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $desiredOutput = Join-Path $inputDir ($inputBase + '_crop' + $sourceExtension)
    $script:OutputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

    $result = Invoke-WithEncodingPlan `
        -FfmpegPath $ffmpegPath `
        -EncodingPlan $encodingPlan `
        -DurationSeconds ([double]$videoInfo.DurationSeconds) `
        -Title 'Crop video' `
        -PreparingText 'Preparing video crop...' `
        -FallbackPreparingText 'GPU unavailable. Retrying in CPU mode...' `
        -OutputFile $script:OutputFile `
        -ArgumentFactory {
            param($profile)
            New-FFmpegArguments -InputFile $InputFile -OutputFile $script:OutputFile -EncodingProfile $profile -X $crop.X -Y $crop.Y -Width $crop.Width -Height $crop.Height
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
        $message = 'Unknown video crop error.'
    }
    Show-Error $message
    exit 1
}
