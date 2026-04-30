param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Get-AppRoot {
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $exeDir = Split-Path -Parent $exePath
    return Split-Path -Parent $exeDir
}

function Show-ErrorAndExit {
    param([string]$Message)

    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        'FFActions - Error',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null

    exit 1
}

function Get-ToolPath {
    param([Parameter(Mandatory = $true)][string]$ToolName)

    $appRoot = Get-AppRoot
    return Join-Path $appRoot "tools\ffmpeg\$ToolName"
}

function Invoke-HiddenProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][object[]]$Arguments
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.Arguments = Join-ProcessArguments -Arguments $Arguments

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    [void]$process.Start()
    $stdOut = $process.StandardOutput.ReadToEnd()
    $stdErr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    $result = [PSCustomObject]@{
        ExitCode = $process.ExitCode
        StdOut   = $stdOut
        StdErr   = $stdErr
    }

    $process.Dispose()
    return $result
}

function Get-UniqueOutputPath {
    param([Parameter(Mandatory = $true)][string]$DesiredPath)

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

function Test-NvencAvailable {
    param([Parameter(Mandatory = $true)][string]$FfmpegPath)

    $result = Invoke-HiddenProcess -FilePath $FfmpegPath -Arguments @('-hide_banner', '-encoders')
    if ($result.ExitCode -ne 0) {
        return $false
    }

    $allText = ($result.StdOut + "`r`n" + $result.StdErr)
    return ($allText -match '(^|\s)h264_nvenc(\s|$)')
}

function Get-VideoInfo {
    param(
        [Parameter(Mandatory = $true)][string]$FfprobePath,
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    $probeResult = Invoke-HiddenProcess -FilePath $FfprobePath -Arguments @(
        '-v', 'error',
        '-select_streams', 'v:0',
        '-show_entries', 'stream=nb_frames,r_frame_rate,avg_frame_rate,duration:format=duration',
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

    $fpsText = $null
    if ($map.ContainsKey('avg_frame_rate') -and $map['avg_frame_rate'] -ne '0/0') {
        $fpsText = $map['avg_frame_rate']
    }
    elseif ($map.ContainsKey('r_frame_rate') -and $map['r_frame_rate'] -ne '0/0') {
        $fpsText = $map['r_frame_rate']
    }

    if ([string]::IsNullOrWhiteSpace($fpsText)) {
        throw 'Unable to determine FPS.'
    }

    if ($fpsText -match '^(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)$') {
        $num = [double]::Parse($matches[1], [System.Globalization.CultureInfo]::InvariantCulture)
        $den = [double]::Parse($matches[2], [System.Globalization.CultureInfo]::InvariantCulture)
        if ($den -eq 0) {
            throw 'Invalid FPS denominator.'
        }
        $fps = $num / $den
    }
    else {
        $fps = [double]::Parse($fpsText.Replace(',', '.'), [System.Globalization.CultureInfo]::InvariantCulture)
    }

    if ($fps -le 0) {
        throw 'Invalid FPS value.'
    }

    $frameCount = $null
    if ($map.ContainsKey('nb_frames') -and $map['nb_frames'] -match '^\d+$') {
        $frameCount = [int]$map['nb_frames']
    }

    if (-not $frameCount -or $frameCount -le 0) {
        $durationText = $null
        if ($map.ContainsKey('duration') -and $map['duration'] -match '^\d+([\.,]\d+)?$') {
            $durationText = $map['duration']
        }
        elseif ($map.ContainsKey('TAG:DURATION')) {
            $durationText = $map['TAG:DURATION']
        }

        if (-not [string]::IsNullOrWhiteSpace($durationText)) {
            $duration = Convert-FFmpegTimeToSeconds -Value $durationText
            if ($null -eq $duration) {
                $duration = [double]::Parse($durationText.Replace(',', '.'), [System.Globalization.CultureInfo]::InvariantCulture)
            }

            if ($duration -gt 0) {
                $frameCount = [int][Math]::Round($duration * $fps)
            }
        }
    }

    if (-not $frameCount -or $frameCount -le 0) {
        throw 'Unable to determine total frame count.'
    }

    return [PSCustomObject]@{
        Fps        = $fps
        FrameCount = $frameCount
    }
}

function Get-EncodingPlan {
    param(
        [Parameter(Mandatory = $true)][string]$Extension,
        [Parameter(Mandatory = $true)][bool]$NvencAvailable
    )

    switch ($Extension.ToLowerInvariant()) {
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
            throw 'Unsupported input format. Only .mp4, .mkv, .avi, .mov, .webm and .m4v are supported.'
        }
    }
}

function Get-ShortErrorText {
    param([string]$StdErr)

    $msg = 'FFmpeg failed during processing.'
    if (-not [string]::IsNullOrWhiteSpace($StdErr)) {
        $firstLines = ($StdErr -split "`r?`n" | Where-Object { $_.Trim() -ne '' } | Select-Object -First 12) -join "`r`n"
        if (-not [string]::IsNullOrWhiteSpace($firstLines)) {
            $msg = $firstLines
        }
    }

    return $msg
}

function Remove-PartialOutput {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        try { Remove-Item -LiteralPath $Path -Force -ErrorAction Stop } catch {}
    }
}

function Set-ControlDoubleBuffered {
    param([Parameter(Mandatory = $true)][System.Windows.Forms.Control]$Control)

    try {
        $flags = [System.Reflection.BindingFlags]'Instance, NonPublic'
        $property = $Control.GetType().GetProperty('DoubleBuffered', $flags)
        if ($property) {
            $property.SetValue($Control, $true, $null)
        }
    }
    catch {}
}

function New-CutByFrameArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)][string]$VideoFilter,
        [Parameter(Mandatory = $true)][string]$AudioFilter,
        [Parameter(Mandatory = $true)]$Profile
    )

    $ffmpegArgs = @(
        '-hide_banner',
        '-loglevel', 'error',
        '-progress', 'pipe:1',
        '-nostats',
        '-y',
        '-i', $InputFile,
        '-vf', $VideoFilter,
        '-af', $AudioFilter,
        '-c:v', $Profile.VideoCodec
    )

    $ffmpegArgs += $Profile.VideoArgs
    $ffmpegArgs += @('-c:a', $Profile.AudioCodec)
    $ffmpegArgs += $Profile.AudioArgs
    $ffmpegArgs += @($OutputFile)

    return ,$ffmpegArgs
}

#__FFCOMMON_INJECT_HERE__
function Format-PreciseTime {
    param([double]$Seconds)

    if ($Seconds -lt 0) { $Seconds = 0 }
    $hours = [int][Math]::Floor($Seconds / 3600)
    $remaining = $Seconds - ($hours * 3600)
    $minutes = [int][Math]::Floor($remaining / 60)
    $secs = $remaining - ($minutes * 60)
    $culture = [System.Globalization.CultureInfo]::InvariantCulture

    return [string]::Format($culture, '{0:D2}:{1:D2}:{2:00.000}', $hours, $minutes, $secs)
}

function Parse-TimeInput {
    param([Parameter(Mandatory = $true)][string]$Text)

    $value = $Text.Trim()
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw 'Time value is required.'
    }

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $seconds = 0.0

    if ($value -match '^\d+(?:\.\d+)?$') {
        if (-not [double]::TryParse($value, [System.Globalization.NumberStyles]::Float, $culture, [ref]$seconds)) {
            throw 'Invalid time value.'
        }
        return $seconds
    }

    $m = [regex]::Match($value, '^(?<h>\d{1,2}):(?<m>\d{1,2}):(?<s>\d{1,2}(?:\.\d+)?)$')
    if ($m.Success) {
        $hours = [double]::Parse($m.Groups['h'].Value, $culture)
        $mins  = [double]::Parse($m.Groups['m'].Value, $culture)
        $secs  = [double]::Parse($m.Groups['s'].Value, $culture)
        return ($hours * 3600.0) + ($mins * 60.0) + $secs
    }

    $m2 = [regex]::Match($value, '^(?<m>\d{1,2}):(?<s>\d{1,2}(?:\.\d+)?)$')
    if ($m2.Success) {
        $mins  = [double]::Parse($m2.Groups['m'].Value, $culture)
        $secs  = [double]::Parse($m2.Groups['s'].Value, $culture)
        return ($mins * 60.0) + $secs
    }

    throw 'Invalid time format. Use seconds or hh:mm:ss.mmm'
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
        [Parameter(Mandatory = $true)][int]$FrameNumber,
        [Parameter(Mandatory = $true)][double]$Fps,
        [Parameter(Mandatory = $true)][int]$MaxWidth,
        [Parameter(Mandatory = $true)][int]$MaxHeight
    )

    $safeFrame = [Math]::Max(1, $FrameNumber)
    $safeSeconds = [Math]::Max(0.0, (($safeFrame - 1) / $Fps))
    $secondsText = $safeSeconds.ToString('0.###', [System.Globalization.CultureInfo]::InvariantCulture)
    $tmpPath = Join-Path ([System.IO.Path]::GetTempPath()) ("ffactions_cut_frame_preview_{0}.png" -f ([guid]::NewGuid().ToString('N')))

    try {
        $result = Invoke-HiddenProcess -FilePath $FfmpegPath -Arguments @(
            '-hide_banner',
            '-loglevel', 'error',
            '-y',
            '-ss', $secondsText,
            '-i', $InputFile,
            '-frames:v', '1',
            $tmpPath
        )

        if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $tmpPath)) {
            throw (Get-ShortErrorText -StdErr $result.StdErr)
        }

        return New-PreviewBitmap -Path $tmpPath -MaxWidth $MaxWidth -MaxHeight $MaxHeight
    }
    finally {
        Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue
    }
}

function Show-CutByFrameWindow {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [Parameter(Mandatory = $true)][int]$TotalFrames,
        [Parameter(Mandatory = $true)][double]$Fps
    )

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $selection = [PSCustomObject]@{
        StartFrame = 1
        EndFrame   = $TotalFrames
    }
    $dragState = [PSCustomObject]@{
        Active = $false
        Target = ''
    }
    $uiState = [PSCustomObject]@{
        ActiveBoundary      = 'start'
        PendingPreviewFrame = 1
        UpdatingText        = $false
        CurrentPreviewBitmap = $null
    }

    $form = New-Object System.Windows.Forms.Form
$form.Text = 'FFActions - Cut video'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(900, 646)
    $form.TopMost = $true

    $labelTitle = New-Object System.Windows.Forms.Label
    $labelTitle.Location = New-Object System.Drawing.Point(20, 14)
    $labelTitle.Size = New-Object System.Drawing.Size(860, 22)
    $labelTitle.Text = 'Choose the start and end frames, then validate.'
    $form.Controls.Add($labelTitle)

    $previewPanel = New-Object System.Windows.Forms.Panel
    $previewPanel.Location = New-Object System.Drawing.Point(20, 42)
    $previewPanel.Size = New-Object System.Drawing.Size(860, 360)
    $previewPanel.BackColor = [System.Drawing.Color]::FromArgb(36, 36, 36)
    $form.Controls.Add($previewPanel)

    $previewBox = New-Object System.Windows.Forms.PictureBox
    $previewBox.Location = New-Object System.Drawing.Point(0, 0)
    $previewBox.Size = $previewPanel.Size
    $previewBox.BackColor = [System.Drawing.Color]::Transparent
    $previewBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::CenterImage
    $previewPanel.Controls.Add($previewBox)

    $columnLabelWidth = 78
    $frameTextWidth = 96
    $frameButtonWidth = 24
    $frameButtonGap = 4
    $frameFieldWidth = $frameTextWidth + $frameButtonGap + $frameButtonWidth + $frameButtonGap + $frameButtonWidth
    $firstLabelX = 20
    $firstInputX = 104
    $secondLabelX = 278
    $secondInputX = 362

    $labelStart = New-Object System.Windows.Forms.Label
    $labelStart.Location = New-Object System.Drawing.Point($firstLabelX, 416)
    $labelStart.Size = New-Object System.Drawing.Size($columnLabelWidth, 20)
    $labelStart.Text = 'Start frame'
    $form.Controls.Add($labelStart)

    $textStart = New-Object System.Windows.Forms.TextBox
    $textStart.Location = New-Object System.Drawing.Point($firstInputX, 413)
    $textStart.Size = New-Object System.Drawing.Size($frameTextWidth, 24)
    $form.Controls.Add($textStart)

    $buttonStartPrev = New-Object System.Windows.Forms.Button
    $buttonStartPrev.Text = '<'
    $buttonStartPrev.Location = New-Object System.Drawing.Point(($firstInputX + $frameTextWidth + $frameButtonGap), 412)
    $buttonStartPrev.Size = New-Object System.Drawing.Size($frameButtonWidth, 26)
    $form.Controls.Add($buttonStartPrev)

    $buttonStartNext = New-Object System.Windows.Forms.Button
    $buttonStartNext.Text = '>'
    $buttonStartNext.Location = New-Object System.Drawing.Point(($firstInputX + $frameTextWidth + $frameButtonGap + $frameButtonWidth + $frameButtonGap), 412)
    $buttonStartNext.Size = New-Object System.Drawing.Size($frameButtonWidth, 26)
    $form.Controls.Add($buttonStartNext)

    $labelEnd = New-Object System.Windows.Forms.Label
    $labelEnd.Location = New-Object System.Drawing.Point($secondLabelX, 416)
    $labelEnd.Size = New-Object System.Drawing.Size($columnLabelWidth, 20)
    $labelEnd.Text = 'End frame'
    $form.Controls.Add($labelEnd)

    $textEnd = New-Object System.Windows.Forms.TextBox
    $textEnd.Location = New-Object System.Drawing.Point($secondInputX, 413)
    $textEnd.Size = New-Object System.Drawing.Size($frameTextWidth, 24)
    $form.Controls.Add($textEnd)

    $buttonEndPrev = New-Object System.Windows.Forms.Button
    $buttonEndPrev.Text = '<'
    $buttonEndPrev.Location = New-Object System.Drawing.Point(($secondInputX + $frameTextWidth + $frameButtonGap), 412)
    $buttonEndPrev.Size = New-Object System.Drawing.Size($frameButtonWidth, 26)
    $form.Controls.Add($buttonEndPrev)

    $buttonEndNext = New-Object System.Windows.Forms.Button
    $buttonEndNext.Text = '>'
    $buttonEndNext.Location = New-Object System.Drawing.Point(($secondInputX + $frameTextWidth + $frameButtonGap + $frameButtonWidth + $frameButtonGap), 412)
    $buttonEndNext.Size = New-Object System.Drawing.Size($frameButtonWidth, 26)
    $form.Controls.Add($buttonEndNext)

    $labelPreviewState = New-Object System.Windows.Forms.Label
    $labelPreviewState.Location = New-Object System.Drawing.Point(532, 416)
    $labelPreviewState.Size = New-Object System.Drawing.Size(348, 20)
    $labelPreviewState.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $form.Controls.Add($labelPreviewState)

    $labelStartTime = New-Object System.Windows.Forms.Label
    $labelStartTime.Location = New-Object System.Drawing.Point($firstLabelX, 448)
    $labelStartTime.Size = New-Object System.Drawing.Size($columnLabelWidth, 20)
    $labelStartTime.Text = 'Start time'
    $form.Controls.Add($labelStartTime)

    $textStartTime = New-Object System.Windows.Forms.TextBox
    $textStartTime.Location = New-Object System.Drawing.Point($firstInputX, 445)
    $textStartTime.Size = New-Object System.Drawing.Size($frameFieldWidth, 24)
    $form.Controls.Add($textStartTime)

    $labelEndTime = New-Object System.Windows.Forms.Label
    $labelEndTime.Location = New-Object System.Drawing.Point($secondLabelX, 448)
    $labelEndTime.Size = New-Object System.Drawing.Size($columnLabelWidth, 20)
    $labelEndTime.Text = 'End time'
    $form.Controls.Add($labelEndTime)

    $textEndTime = New-Object System.Windows.Forms.TextBox
    $textEndTime.Location = New-Object System.Drawing.Point($secondInputX, 445)
    $textEndTime.Size = New-Object System.Drawing.Size($frameFieldWidth, 24)
    $form.Controls.Add($textEndTime)

    $selectionPanel = New-Object System.Windows.Forms.Panel
    $selectionPanel.Location = New-Object System.Drawing.Point(20, 480)
    $selectionPanel.Size = New-Object System.Drawing.Size(860, 70)
    $selectionPanel.BackColor = [System.Drawing.Color]::White
    $selectionPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    Set-ControlDoubleBuffered -Control $selectionPanel
    $form.Controls.Add($selectionPanel)

    $labelSelection = New-Object System.Windows.Forms.Label
    $labelSelection.Location = New-Object System.Drawing.Point(20, 558)
    $labelSelection.Size = New-Object System.Drawing.Size(860, 20)
    $form.Controls.Add($labelSelection)

    $labelHint = New-Object System.Windows.Forms.Label
    $labelHint.Location = New-Object System.Drawing.Point(20, 582)
    $labelHint.Size = New-Object System.Drawing.Size(860, 18)
    $labelHint.Text = 'Drag the left or right handle, or edit the frame and time fields directly.'
    $form.Controls.Add($labelHint)

    $buttonOk = New-Object System.Windows.Forms.Button
    $buttonOk.Text = 'OK'
    $buttonOk.Location = New-Object System.Drawing.Point(724, 606)
    $buttonOk.Size = New-Object System.Drawing.Size(75, 28)
    $buttonOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($buttonOk)

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.Location = New-Object System.Drawing.Point(805, 606)
    $buttonCancel.Size = New-Object System.Drawing.Size(75, 28)
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($buttonCancel)

    $form.AcceptButton = $buttonOk
    $form.CancelButton = $buttonCancel

    $previewTimer = New-Object System.Windows.Forms.Timer
    $previewTimer.Interval = 140

    function Convert-FrameToTrackX {
        param([int]$Frame)

        $trackLeft = 18
        $trackWidth = $selectionPanel.ClientSize.Width - 36
        if ($TotalFrames -le 1) { return $trackLeft }

        $ratio = ($Frame - 1) / [double]($TotalFrames - 1)
        return [int][Math]::Round($trackLeft + ($ratio * $trackWidth))
    }

    function Convert-TrackXToFrame {
        param([int]$X)

        $trackLeft = 18
        $trackWidth = $selectionPanel.ClientSize.Width - 36
        if ($trackWidth -le 0 -or $TotalFrames -le 1) { return 1 }

        $clamped = [Math]::Min(($trackLeft + $trackWidth), [Math]::Max($trackLeft, $X))
        $ratio = ($clamped - $trackLeft) / [double]$trackWidth
        $frame = 1 + [int][Math]::Round($ratio * ($TotalFrames - 1))
        return [Math]::Min($TotalFrames, [Math]::Max(1, $frame))
    }

    function Dispose-PreviewBitmap {
        if ($previewBox.Image) {
            $previewBox.Image = $null
        }
        if ($uiState.CurrentPreviewBitmap) {
            $uiState.CurrentPreviewBitmap.Dispose()
            $uiState.CurrentPreviewBitmap = $null
        }
    }

    function Load-PreviewFrame {
        param([Parameter(Mandatory = $true)][int]$FrameNumber)

        $newBitmap = New-VideoPreviewBitmap -InputFile $InputFile -FfmpegPath $FfmpegPath -FrameNumber $FrameNumber -Fps $Fps -MaxWidth 820 -MaxHeight 340
        Dispose-PreviewBitmap
        $uiState.CurrentPreviewBitmap = $newBitmap
        $previewBox.Image = $uiState.CurrentPreviewBitmap

        $timeSeconds = ($FrameNumber - 1) / $Fps
        $labelPreviewState.Text = ("Previewing {0}: frame {1} ({2})" -f $uiState.ActiveBoundary, $FrameNumber, (Format-PreciseTime -Seconds $timeSeconds))
    }

    function Schedule-PreviewUpdate {
        param([Parameter(Mandatory = $true)][int]$FrameNumber)

        $uiState.PendingPreviewFrame = $FrameNumber
        $previewTimer.Stop()
        $previewTimer.Start()
    }

    function Refresh-SelectionUi {
        param([bool]$RefreshPreview = $true)

        $uiState.UpdatingText = $true
        $textStart.Text = [string]$selection.StartFrame
        $textEnd.Text = [string]$selection.EndFrame
        $textStartTime.Text = Format-PreciseTime -Seconds (($selection.StartFrame - 1) / $Fps)
        $textEndTime.Text = Format-PreciseTime -Seconds ($selection.EndFrame / $Fps)
        $uiState.UpdatingText = $false

        $startTimeSeconds = ($selection.StartFrame - 1) / $Fps
        $endTimeSeconds = $selection.EndFrame / $Fps
        $selectedFrames = $selection.EndFrame - $selection.StartFrame + 1
        $labelSelection.Text = ("Selection: frame {0} to {1}  |  {2} -> {3}  |  {4} frames" -f $selection.StartFrame, $selection.EndFrame, (Format-PreciseTime -Seconds $startTimeSeconds), (Format-PreciseTime -Seconds $endTimeSeconds), $selectedFrames)
        $selectionPanel.Invalidate()

        if ($RefreshPreview) {
            $frameToPreview = if ($uiState.ActiveBoundary -eq 'end') { $selection.EndFrame } else { $selection.StartFrame }
            Schedule-PreviewUpdate -FrameNumber $frameToPreview
        }
    }

    function Apply-BoundaryFromText {
        param([Parameter(Mandatory = $true)][string]$Target)

        $rawValue = if ($Target -eq 'start') { $textStart.Text } else { $textEnd.Text }
        $frameValue = 0
        if (-not [int]::TryParse($rawValue.Trim(), [ref]$frameValue)) {
            throw ('{0} frame must be an integer.' -f (($Target.Substring(0,1).ToUpper()) + $Target.Substring(1)))
        }

        if ($frameValue -lt 1) { $frameValue = 1 }
        if ($frameValue -gt $TotalFrames) { $frameValue = $TotalFrames }

        if ($Target -eq 'start') {
            if ($frameValue -gt $selection.EndFrame) { $frameValue = $selection.EndFrame }
            $selection.StartFrame = $frameValue
        }
        else {
            if ($frameValue -lt $selection.StartFrame) { $frameValue = $selection.StartFrame }
            $selection.EndFrame = $frameValue
        }

        $uiState.ActiveBoundary = $Target
        Refresh-SelectionUi -RefreshPreview $true
    }

    function Convert-TimeToFrameBoundary {
        param(
            [Parameter(Mandatory = $true)][string]$Target,
            [Parameter(Mandatory = $true)][double]$Seconds
        )

        if ($Seconds -lt 0) { $Seconds = 0 }

        if ($Target -eq 'start') {
            $frame = 1 + [int][Math]::Floor($Seconds * $Fps)
        }
        else {
            $frame = [int][Math]::Ceiling($Seconds * $Fps)
        }

        if ($frame -lt 1) { $frame = 1 }
        if ($frame -gt $TotalFrames) { $frame = $TotalFrames }
        return $frame
    }

    function Apply-BoundaryFromTimeText {
        param([Parameter(Mandatory = $true)][string]$Target)

        $rawValue = if ($Target -eq 'start') { $textStartTime.Text } else { $textEndTime.Text }
        $seconds = Parse-TimeInput -Text $rawValue
        $frameValue = Convert-TimeToFrameBoundary -Target $Target -Seconds $seconds

        if ($Target -eq 'start') {
            if ($frameValue -gt $selection.EndFrame) { $frameValue = $selection.EndFrame }
            $selection.StartFrame = $frameValue
        }
        else {
            if ($frameValue -lt $selection.StartFrame) { $frameValue = $selection.StartFrame }
            $selection.EndFrame = $frameValue
        }

        $uiState.ActiveBoundary = $Target
        Refresh-SelectionUi -RefreshPreview $true
    }

    function Step-FrameBoundary {
        param(
            [Parameter(Mandatory = $true)][string]$Target,
            [Parameter(Mandatory = $true)][int]$Delta
        )

        if ($Target -eq 'start') {
            $frameValue = $selection.StartFrame + $Delta
            if ($frameValue -lt 1) { $frameValue = 1 }
            if ($frameValue -gt $selection.EndFrame) { $frameValue = $selection.EndFrame }
            $selection.StartFrame = $frameValue
        }
        else {
            $frameValue = $selection.EndFrame + $Delta
            if ($frameValue -lt $selection.StartFrame) { $frameValue = $selection.StartFrame }
            if ($frameValue -gt $TotalFrames) { $frameValue = $TotalFrames }
            $selection.EndFrame = $frameValue
        }

        $uiState.ActiveBoundary = $Target
        Refresh-SelectionUi -RefreshPreview $true
    }

    $previewTimer.Add_Tick({
        $previewTimer.Stop()
        try {
            Load-PreviewFrame -FrameNumber $uiState.PendingPreviewFrame
        }
        catch {
            Show-ErrorAndExit $_.Exception.Message
        }
    })

    $selectionPanel.Add_Paint({
        param($sender, $e)

        $graphics = $e.Graphics
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

        $trackLeft = 18
        $trackTop = 34
        $trackWidth = $selectionPanel.ClientSize.Width - 36
        $trackHeight = 6
        $handleWidth = 10
        $handleHeight = 28

        $startX = [int](Convert-FrameToTrackX -Frame $selection.StartFrame)
        $endX = [int](Convert-FrameToTrackX -Frame $selection.EndFrame)
        if ($endX -lt $startX) {
            $tmp = $startX
            $startX = $endX
            $endX = $tmp
        }

        $selectionWidth = [int][Math]::Max(2, ($endX - $startX))
        $startHandleX = [int]($startX - [int]($handleWidth / 2))
        $startHandleY = [int]($trackTop - 11)
        $endHandleX = [int]($endX - [int]($handleWidth / 2))
        $endHandleY = [int]($trackTop - 11)

        $trackBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(222, 226, 232))
        $selectionBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(48, 120, 212))
        $startBrush = if ($uiState.ActiveBoundary -eq 'start') { New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(24, 92, 188)) } else { New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(48, 120, 212)) }
        $endBrush = if ($uiState.ActiveBoundary -eq 'end') { New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(24, 92, 188)) } else { New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(48, 120, 212)) }
        $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(170, 176, 184))
        $tickPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(140, 146, 154))

        try {
            $graphics.FillRectangle($trackBrush, $trackLeft, $trackTop, $trackWidth, $trackHeight)
            $graphics.DrawRectangle($borderPen, $trackLeft, $trackTop, $trackWidth, $trackHeight)
            $graphics.FillRectangle($selectionBrush, $startX, ($trackTop - 4), $selectionWidth, 14)

            for ($i = 0; $i -le 10; $i++) {
                $tickX = $trackLeft + [int][Math]::Round(($trackWidth * $i) / 10.0)
                $graphics.DrawLine($tickPen, $tickX, 18, $tickX, 26)
            }

            $graphics.FillRectangle($startBrush, $startHandleX, $startHandleY, $handleWidth, $handleHeight)
            $graphics.FillRectangle($endBrush, $endHandleX, $endHandleY, $handleWidth, $handleHeight)
            $graphics.DrawRectangle($borderPen, $startHandleX, $startHandleY, $handleWidth, $handleHeight)
            $graphics.DrawRectangle($borderPen, $endHandleX, $endHandleY, $handleWidth, $handleHeight)

            $graphics.DrawString('1', $form.Font, [System.Drawing.Brushes]::DimGray, 14, 2)
            $lastFrameText = [string]$TotalFrames
            $lastFrameSize = $graphics.MeasureString($lastFrameText, $form.Font)
            $graphics.DrawString($lastFrameText, $form.Font, [System.Drawing.Brushes]::DimGray, ($selectionPanel.ClientSize.Width - $lastFrameSize.Width - 14), 2)
        }
        finally {
            $trackBrush.Dispose()
            $selectionBrush.Dispose()
            $startBrush.Dispose()
            $endBrush.Dispose()
            $borderPen.Dispose()
            $tickPen.Dispose()
        }
    })

    $selectionPanel.Add_MouseDown({
        param($sender, $e)

        $startX = [int](Convert-FrameToTrackX -Frame $selection.StartFrame)
        $endX = [int](Convert-FrameToTrackX -Frame $selection.EndFrame)
        $distanceToStart = [Math]::Abs(([int]$e.X) - $startX)
        $distanceToEnd = [Math]::Abs(([int]$e.X) - $endX)

        $dragState.Active = $true
        $dragState.Target = if ($distanceToStart -le $distanceToEnd) { 'start' } else { 'end' }
        $uiState.ActiveBoundary = $dragState.Target
        $selectionPanel.Capture = $true

        $frame = [int](Convert-TrackXToFrame -X ([int]$e.X))
        if ($dragState.Target -eq 'start') {
            if ($frame -gt $selection.EndFrame) { $frame = $selection.EndFrame }
            $selection.StartFrame = $frame
        }
        else {
            if ($frame -lt $selection.StartFrame) { $frame = $selection.StartFrame }
            $selection.EndFrame = $frame
        }

        Refresh-SelectionUi -RefreshPreview $true
    })

    $selectionPanel.Add_MouseMove({
        param($sender, $e)

        if (-not $dragState.Active) { return }

        $frame = [int](Convert-TrackXToFrame -X ([int]$e.X))
        if ($dragState.Target -eq 'start') {
            if ($frame -gt $selection.EndFrame) { $frame = $selection.EndFrame }
            $selection.StartFrame = $frame
        }
        else {
            if ($frame -lt $selection.StartFrame) { $frame = $selection.StartFrame }
            $selection.EndFrame = $frame
        }

        Refresh-SelectionUi -RefreshPreview $true
    })

    $selectionPanel.Add_MouseUp({
        param($sender, $e)
        $dragState.Active = $false
        $dragState.Target = ''
        $selectionPanel.Capture = $false
    })

    $buttonStartPrev.Add_Click({
        Step-FrameBoundary -Target 'start' -Delta -1
    })

    $buttonStartNext.Add_Click({
        Step-FrameBoundary -Target 'start' -Delta 1
    })

    $buttonEndPrev.Add_Click({
        Step-FrameBoundary -Target 'end' -Delta -1
    })

    $buttonEndNext.Add_Click({
        Step-FrameBoundary -Target 'end' -Delta 1
    })

    $textStart.Add_Leave({
        if ($uiState.UpdatingText) { return }
        try {
            Apply-BoundaryFromText -Target 'start'
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'FFActions - Error', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            Refresh-SelectionUi -RefreshPreview $false
        }
    })

    $textEnd.Add_Leave({
        if ($uiState.UpdatingText) { return }
        try {
            Apply-BoundaryFromText -Target 'end'
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'FFActions - Error', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            Refresh-SelectionUi -RefreshPreview $false
        }
    })

    $textStart.Add_KeyDown({
        param($sender, $e)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            try {
                Apply-BoundaryFromText -Target 'start'
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'FFActions - Error', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
                Refresh-SelectionUi -RefreshPreview $false
            }
            $e.SuppressKeyPress = $true
        }
    })

    $textEnd.Add_KeyDown({
        param($sender, $e)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            try {
                Apply-BoundaryFromText -Target 'end'
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'FFActions - Error', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
                Refresh-SelectionUi -RefreshPreview $false
            }
            $e.SuppressKeyPress = $true
        }
    })

    $textStartTime.Add_Leave({
        if ($uiState.UpdatingText) { return }
        try {
            Apply-BoundaryFromTimeText -Target 'start'
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'FFActions - Error', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            Refresh-SelectionUi -RefreshPreview $false
        }
    })

    $textEndTime.Add_Leave({
        if ($uiState.UpdatingText) { return }
        try {
            Apply-BoundaryFromTimeText -Target 'end'
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'FFActions - Error', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            Refresh-SelectionUi -RefreshPreview $false
        }
    })

    $textStartTime.Add_KeyDown({
        param($sender, $e)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            try {
                Apply-BoundaryFromTimeText -Target 'start'
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'FFActions - Error', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
                Refresh-SelectionUi -RefreshPreview $false
            }
            $e.SuppressKeyPress = $true
        }
    })

    $textEndTime.Add_KeyDown({
        param($sender, $e)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            try {
                Apply-BoundaryFromTimeText -Target 'end'
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'FFActions - Error', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
                Refresh-SelectionUi -RefreshPreview $false
            }
            $e.SuppressKeyPress = $true
        }
    })

    $form.Add_FormClosing({
        $previewTimer.Stop()
        Dispose-PreviewBitmap
    })

    try {
        Refresh-SelectionUi -RefreshPreview $false
        Load-PreviewFrame -FrameNumber 1
    }
    catch {
        $previewTimer.Dispose()
        $form.Dispose()
        Show-ErrorAndExit $_.Exception.Message
    }

    $dialogResult = $form.ShowDialog()
    $previewTimer.Stop()
    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK) {
        Dispose-PreviewBitmap
        $previewTimer.Dispose()
        $form.Dispose()
        return $null
    }

    $result = [PSCustomObject]@{
        StartFrame = $selection.StartFrame
        EndFrame   = $selection.EndFrame
    }

    Dispose-PreviewBitmap
    $previewTimer.Dispose()
    $form.Dispose()
    return $result
}


if ([string]::IsNullOrWhiteSpace($InputFile)) {
    Show-ErrorAndExit 'Input file is missing.'
}

if (-not (Test-Path -LiteralPath $InputFile)) {
    Show-ErrorAndExit "Input file not found.`n$InputFile"
}

$inputExt = [System.IO.Path]::GetExtension($InputFile).ToLowerInvariant()
if ($inputExt -notin @('.mp4', '.mkv', '.avi', '.mov', '.webm', '.m4v')) {
    Show-ErrorAndExit 'Unsupported input format. Only .mp4, .mkv, .avi, .mov, .webm and .m4v are supported.'
}

$ffmpeg = Get-ToolPath -ToolName 'ffmpeg.exe'
$ffprobe = Get-ToolPath -ToolName 'ffprobe.exe'

if (-not (Test-Path -LiteralPath $ffmpeg)) {
    Show-ErrorAndExit "ffmpeg.exe not found.`n$ffmpeg"
}

if (-not (Test-Path -LiteralPath $ffprobe)) {
    Show-ErrorAndExit "ffprobe.exe not found.`n$ffprobe"
}

try {
    $videoInfo = Get-VideoInfo -FfprobePath $ffprobe -FilePath $InputFile
}
catch {
    Show-ErrorAndExit "Unable to read video information.`n$($_.Exception.Message)"
}

$fps = [double]$videoInfo.Fps
$totalFrames = [int]$videoInfo.FrameCount

$selection = Show-CutByFrameWindow -InputFile $InputFile -FfmpegPath $ffmpeg -TotalFrames $totalFrames -Fps $fps
if ($null -eq $selection) {
    exit 0
}

$startFrame = [int]$selection.StartFrame
$endFrame = [int]$selection.EndFrame

$startFrameZeroBased = $startFrame - 1
$endFrameZeroBased = $endFrame - 1

$startTimeSeconds = $startFrameZeroBased / $fps
$endTimeSeconds = $endFrame / $fps

$inputDir = Split-Path -Parent $InputFile
$inputBase = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
$desiredOutput = Join-Path $inputDir ("{0}__frame_{1}_to_{2}{3}" -f $inputBase, $startFrame, $endFrame, $inputExt)
$outputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

$videoFilter = "select='between(n,$startFrameZeroBased,$endFrameZeroBased)',setpts=PTS-STARTPTS"
$audioFilter = "atrim=start={0}:end={1},asetpts=PTS-STARTPTS" -f `
    $startTimeSeconds.ToString([System.Globalization.CultureInfo]::InvariantCulture), `
    $endTimeSeconds.ToString([System.Globalization.CultureInfo]::InvariantCulture)

$selectedDurationSeconds = ($endFrame - $startFrame + 1) / $fps
if ($selectedDurationSeconds -le 0) {
    Show-ErrorAndExit 'Invalid output duration.'
}

$nvencAvailable = Test-NvencAvailable -FfmpegPath $ffmpeg
$encodingPlan = Get-EncodingPlan -Extension $inputExt -NvencAvailable $nvencAvailable

try {
    $result = Invoke-WithEncodingPlan -FfmpegPath $ffmpeg -EncodingPlan $encodingPlan -DurationSeconds $selectedDurationSeconds -OutputFile $outputFile -Title 'Cut in progress' -PreparingText 'Preparing cut...' -FallbackPreparingText 'Retrying cut...' -ArgumentFactory {
        param($profile)
        New-CutByFrameArguments -InputFile $InputFile -OutputFile $outputFile -VideoFilter $videoFilter -AudioFilter $audioFilter -Profile $profile
    }
}
catch {
    Remove-PartialOutput -Path $outputFile

    $message = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = 'Unknown cut error.'
    }

    Show-ErrorAndExit $message
}

if ($result.Cancelled) {
    Remove-PartialOutput -Path $outputFile
    exit 0
}

if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $outputFile)) {
    Remove-PartialOutput -Path $outputFile
    Show-ErrorAndExit (Get-ShortErrorText -StdErr $result.StdErr)
}

exit 0
