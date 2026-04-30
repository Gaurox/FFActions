param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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

function Get-AppRoot {
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $exeDir = Split-Path -Parent $exePath
    return Split-Path -Parent $exeDir
}

function Get-ToolPath {
    param([Parameter(Mandatory = $true)][string]$ToolName)

    $appRoot = Get-AppRoot
    return Join-Path $appRoot "tools\ffmpeg\$ToolName"
}

function Quote-ProcessArgument {
    param([string]$Value)

    if ($null -eq $Value -or $Value -eq '') {
        return '""'
    }

    if ($Value -notmatch '[\s"]') {
        return $Value
    }

    $escaped = $Value -replace '(\\*)"', '$1$1\\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function Join-ProcessArguments {
    param([string[]]$Arguments)

    $quoted = foreach ($arg in $Arguments) {
        Quote-ProcessArgument $arg
    }

    return ($quoted -join ' ')
}

function Invoke-HiddenProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = Join-ProcessArguments $Arguments
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

function Get-MediaDurationSeconds {
    param(
        [Parameter(Mandatory = $true)][string]$FfprobePath,
        [Parameter(Mandatory = $true)][string]$InputPath
    )

    $probeResult = Invoke-HiddenProcess -FilePath $FfprobePath -Arguments @(
        '-v', 'error',
        '-show_entries', 'format=duration',
        '-of', 'default=nokey=1:noprint_wrappers=1',
        $InputPath
    )

    if ($probeResult.ExitCode -ne 0) {
        $probeErr = $probeResult.StdErr.Trim()
        if ([string]::IsNullOrWhiteSpace($probeErr)) {
            $probeErr = 'ffprobe failed.'
        }
        throw $probeErr
    }

    $durationText = $probeResult.StdOut.Trim()
    if ([string]::IsNullOrWhiteSpace($durationText)) {
        throw 'Unable to detect media duration.'
    }

    $duration = [double]::Parse($durationText.Replace(',', '.'), [System.Globalization.CultureInfo]::InvariantCulture)
    if ($duration -le 0) {
        throw 'Invalid media duration.'
    }

    return $duration
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

    return 'FFmpeg failed during video transform.'
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
    $tmpPath = Join-Path ([System.IO.Path]::GetTempPath()) ("ffactions_video_rotate_preview_{0}.png" -f ([guid]::NewGuid().ToString('N')))

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

function Get-RotateFlipType {
    param(
        [Parameter(Mandatory = $true)][int]$QuarterTurns,
        [Parameter(Mandatory = $true)][bool]$FlipHorizontal,
        [Parameter(Mandatory = $true)][bool]$FlipVertical
    )

    $turn = (($QuarterTurns % 4) + 4) % 4
    $suffix = if ($FlipHorizontal -and $FlipVertical) {
        'XY'
    }
    elseif ($FlipHorizontal) {
        'X'
    }
    elseif ($FlipVertical) {
        'Y'
    }
    else {
        'None'
    }

    $name = switch ($turn) {
        1 { "Rotate90Flip${suffix}" }
        2 { "Rotate180Flip${suffix}" }
        3 { "Rotate270Flip${suffix}" }
        default { "RotateNoneFlip${suffix}" }
    }

    return [System.Drawing.RotateFlipType]::$name
}

function Get-TransformSummary {
    param(
        [Parameter(Mandatory = $true)][int]$QuarterTurns,
        [Parameter(Mandatory = $true)][bool]$FlipHorizontal,
        [Parameter(Mandatory = $true)][bool]$FlipVertical
    )

    $rotation = ((($QuarterTurns % 4) + 4) % 4) * 90
    $parts = @("Rotation: ${rotation}°")
    $parts += if ($FlipHorizontal) { 'Mirror H: on' } else { 'Mirror H: off' }
    $parts += if ($FlipVertical) { 'Mirror V: on' } else { 'Mirror V: off' }
    return ($parts -join '   ')
}

function Get-TransformConfig {
    param([string[]]$Keys)

    if ($null -eq $Keys -or $Keys.Count -eq 0) {
        throw 'No video transform selected.'
    }

    $filters = New-Object System.Collections.Generic.List[string]
    foreach ($key in $Keys) {
        switch ($key) {
            'rotate90'  { $filters.Add('transpose=1') | Out-Null }
            'rotate270' { $filters.Add('transpose=2') | Out-Null }
            'flip_h'    { $filters.Add('hflip') | Out-Null }
            'flip_v'    { $filters.Add('vflip') | Out-Null }
            default     { throw 'Unknown video transform.' }
        }
    }

    return [PSCustomObject]@{
        Filter = ($filters -join ',')
        Label  = ($Keys -join '_')
        Text   = 'video transform'
    }
}

function New-TransformedPreviewBitmap {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$SourceBitmap,
        [Parameter(Mandatory = $true)][int]$QuarterTurns,
        [Parameter(Mandatory = $true)][bool]$FlipHorizontal,
        [Parameter(Mandatory = $true)][bool]$FlipVertical
    )

    $preview = New-Object System.Drawing.Bitmap($SourceBitmap)
    $preview.RotateFlip((Get-RotateFlipType -QuarterTurns $QuarterTurns -FlipHorizontal $FlipHorizontal -FlipVertical $FlipVertical))
    return $preview
}

function Show-RotateVideoWindow {
    param(
        [Parameter(Mandatory = $true)][string]$VideoPath,
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [Parameter(Mandatory = $true)][double]$DurationSeconds
    )

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $script:quarterTurns = 0
    $script:flipHorizontal = $false
    $script:flipVertical = $false
    $script:transformKeys = New-Object System.Collections.Generic.List[string]
    $script:basePreviewBitmap = $null
    $script:currentPreviewBitmap = $null
    $script:pendingPreviewSeconds = 0.0
    $script:currentPreviewSeconds = 0.0

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFActions - Rotate / flip video'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(700, 638)
    $form.TopMost = $true

    $labelTitle = New-Object System.Windows.Forms.Label
    $labelTitle.Location = New-Object System.Drawing.Point(18, 14)
    $labelTitle.Size = New-Object System.Drawing.Size(664, 22)
    $labelTitle.Text = 'Preview the result, choose a frame if needed, then validate.'
    $form.Controls.Add($labelTitle)

    $previewPanel = New-Object System.Windows.Forms.Panel
    $previewPanel.Location = New-Object System.Drawing.Point(18, 44)
    $previewPanel.Size = New-Object System.Drawing.Size(664, 380)
    $previewPanel.BackColor = [System.Drawing.Color]::FromArgb(36, 36, 36)
    $form.Controls.Add($previewPanel)

    $previewBox = New-Object System.Windows.Forms.PictureBox
    $previewBox.Location = New-Object System.Drawing.Point(0, 0)
    $previewBox.Size = $previewPanel.Size
    $previewBox.BackColor = [System.Drawing.Color]::Transparent
    $previewBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::CenterImage
    $previewPanel.Controls.Add($previewBox)

    $trackPreview = New-Object System.Windows.Forms.TrackBar
    $trackPreview.Location = New-Object System.Drawing.Point(18, 434)
    $trackPreview.Size = New-Object System.Drawing.Size(664, 45)
    $trackPreview.Minimum = 0
    $trackPreview.Maximum = 1000
    $trackPreview.TickFrequency = 100
    $trackPreview.SmallChange = 5
    $trackPreview.LargeChange = 50
    $form.Controls.Add($trackPreview)

    $labelFrame = New-Object System.Windows.Forms.Label
    $labelFrame.Location = New-Object System.Drawing.Point(18, 478)
    $labelFrame.Size = New-Object System.Drawing.Size(220, 18)
    $form.Controls.Add($labelFrame)

    $buttonSpecs = @(
        @{ Key = 'rotate90';  Glyph = '⟳'; X = 18;  Tooltip = 'Rotate 90 degrees clockwise' },
        @{ Key = 'rotate270'; Glyph = '⟲'; X = 90;  Tooltip = 'Rotate 90 degrees counterclockwise' },
        @{ Key = 'flip_h';    Glyph = '⇋'; X = 162; Tooltip = 'Mirror horizontally' },
        @{ Key = 'flip_v';    Glyph = '⇅'; X = 234; Tooltip = 'Mirror vertically' }
    )

    $buttonFont = New-Object System.Drawing.Font('Segoe UI Symbol', 20, [System.Drawing.FontStyle]::Regular)
    $buttonTooltip = New-Object System.Windows.Forms.ToolTip

    $labelState = New-Object System.Windows.Forms.Label
    $labelState.Location = New-Object System.Drawing.Point(18, 508)
    $labelState.Size = New-Object System.Drawing.Size(430, 22)
    $form.Controls.Add($labelState)

    $labelNote = New-Object System.Windows.Forms.Label
    $labelNote.Location = New-Object System.Drawing.Point(18, 534)
    $labelNote.Size = New-Object System.Drawing.Size(500, 18)
    $labelNote.Text = 'The output video is created next to the original file. Audio is kept when possible.'
    $form.Controls.Add($labelNote)

    function Dispose-PreviewBitmaps {
        if ($previewBox.Image) {
            $previewBox.Image = $null
        }
        if ($script:currentPreviewBitmap) {
            $script:currentPreviewBitmap.Dispose()
            $script:currentPreviewBitmap = $null
        }
        if ($script:basePreviewBitmap) {
            $script:basePreviewBitmap.Dispose()
            $script:basePreviewBitmap = $null
        }
    }

    function Update-FrameLabel {
        param([Parameter(Mandatory = $true)][double]$Seconds)
        $labelFrame.Text = "Frame: $(Format-TimeForDisplay -Seconds $Seconds)"
    }

    function Update-PreviewBitmap {
        if ($script:currentPreviewBitmap) {
            $previewBox.Image = $null
            $script:currentPreviewBitmap.Dispose()
            $script:currentPreviewBitmap = $null
        }

        if ($script:basePreviewBitmap) {
            $script:currentPreviewBitmap = New-TransformedPreviewBitmap -SourceBitmap $script:basePreviewBitmap -QuarterTurns $script:quarterTurns -FlipHorizontal $script:flipHorizontal -FlipVertical $script:flipVertical
            $previewBox.Image = $script:currentPreviewBitmap
        }

        $labelState.Text = Get-TransformSummary -QuarterTurns $script:quarterTurns -FlipHorizontal $script:flipHorizontal -FlipVertical $script:flipVertical
    }

    function Load-PreviewFrame {
        param([Parameter(Mandatory = $true)][double]$Seconds)

        $newBitmap = New-VideoPreviewBitmap -InputFile $VideoPath -FfmpegPath $FfmpegPath -TimeSeconds $Seconds -MaxWidth 640 -MaxHeight 380
        if ($script:basePreviewBitmap) {
            $script:basePreviewBitmap.Dispose()
        }
        $script:basePreviewBitmap = $newBitmap
        $script:currentPreviewSeconds = $Seconds
        Update-FrameLabel -Seconds $Seconds
        Update-PreviewBitmap
    }

    $previewTimer = New-Object System.Windows.Forms.Timer
    $previewTimer.Interval = 140
    $previewTimer.Add_Tick({
        $previewTimer.Stop()
        try {
            Load-PreviewFrame -Seconds $script:pendingPreviewSeconds
        }
        catch {
            Show-ErrorAndExit $_.Exception.Message
        }
    })

    foreach ($spec in $buttonSpecs) {
        $button = New-Object System.Windows.Forms.Button
        $button.Tag = $spec.Key
        $button.Text = $spec.Glyph
        $button.Font = $buttonFont
        $button.Location = New-Object System.Drawing.Point($spec.X, 570)
        $button.Size = New-Object System.Drawing.Size(60, 36)
        $buttonTooltip.SetToolTip($button, $spec.Tooltip)
        $button.Add_Click({
            param($sender, $eventArgs)
            $key = [string]$sender.Tag
            switch ($key) {
                'rotate90' {
                    $script:quarterTurns = ($script:quarterTurns + 1) % 4
                }
                'rotate270' {
                    $script:quarterTurns = ($script:quarterTurns + 3) % 4
                }
                'flip_h' {
                    $script:flipHorizontal = -not $script:flipHorizontal
                }
                'flip_v' {
                    $script:flipVertical = -not $script:flipVertical
                }
            }

            $script:transformKeys.Add($key) | Out-Null
            Update-PreviewBitmap
        })
        $form.Controls.Add($button)
    }

    $buttonReset = New-Object System.Windows.Forms.Button
    $buttonReset.Text = 'Reset'
    $buttonReset.Location = New-Object System.Drawing.Point(376, 576)
    $buttonReset.Size = New-Object System.Drawing.Size(90, 28)
    $buttonReset.Add_Click({
        $script:quarterTurns = 0
        $script:flipHorizontal = $false
        $script:flipVertical = $false
        $script:transformKeys.Clear()
        Update-PreviewBitmap
    })
    $form.Controls.Add($buttonReset)

    $buttonOK = New-Object System.Windows.Forms.Button
    $buttonOK.Text = 'OK'
    $buttonOK.Location = New-Object System.Drawing.Point(490, 576)
    $buttonOK.Size = New-Object System.Drawing.Size(90, 28)
    $buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($buttonOK)

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.Location = New-Object System.Drawing.Point(592, 576)
    $buttonCancel.Size = New-Object System.Drawing.Size(90, 28)
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($buttonCancel)

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
            Load-PreviewFrame -Seconds $script:pendingPreviewSeconds
        }
        catch {
            Show-ErrorAndExit $_.Exception.Message
        }
    })

    $trackPreview.Add_KeyUp({
        $previewTimer.Stop()
        try {
            Load-PreviewFrame -Seconds $script:pendingPreviewSeconds
        }
        catch {
            Show-ErrorAndExit $_.Exception.Message
        }
    })

    $form.AcceptButton = $buttonOK
    $form.CancelButton = $buttonCancel

    try {
        Load-PreviewFrame -Seconds 0.0
    }
    catch {
        Dispose-PreviewBitmaps
        $previewTimer.Dispose()
        $buttonFont.Dispose()
        $form.Dispose()
        Show-ErrorAndExit $_.Exception.Message
    }

    $result = $form.ShowDialog()
    $previewTimer.Stop()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Dispose-PreviewBitmaps
        $previewTimer.Dispose()
        $buttonFont.Dispose()
        $form.Dispose()
        return $null
    }

    if ($script:transformKeys.Count -eq 0) {
        Dispose-PreviewBitmaps
        $previewTimer.Dispose()
        $buttonFont.Dispose()
        $form.Dispose()
        Show-ErrorAndExit 'Apply at least one transform before validating.'
    }

    $payload = Get-TransformConfig -Keys $script:transformKeys.ToArray()
    Dispose-PreviewBitmaps
    $previewTimer.Dispose()
    $buttonFont.Dispose()
    $form.Dispose()
    return $payload
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
                VideoArgs  = @('-preset', 'slow', '-crf', '16', '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                AudioCodec = 'copy'
                AudioArgs  = @()
            }

            if ($NvencAvailable) {
                $gpu = [PSCustomObject]@{
                    ModeLabel  = 'NVIDIA GPU'
                    VideoCodec = 'h264_nvenc'
                    VideoArgs  = @('-preset', 'p5', '-cq', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                    AudioCodec = 'copy'
                    AudioArgs  = @()
                }

                return [PSCustomObject]@{ Primary = $gpu; Fallback = $cpu }
            }

            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        '.mkv' {
            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'libx264'
                VideoArgs  = @('-preset', 'slow', '-crf', '16', '-pix_fmt', 'yuv420p')
                AudioCodec = 'copy'
                AudioArgs  = @()
            }

            if ($NvencAvailable) {
                $gpu = [PSCustomObject]@{
                    ModeLabel  = 'NVIDIA GPU'
                    VideoCodec = 'h264_nvenc'
                    VideoArgs  = @('-preset', 'p5', '-cq', '19', '-pix_fmt', 'yuv420p')
                    AudioCodec = 'copy'
                    AudioArgs  = @()
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
                AudioCodec = 'copy'
                AudioArgs  = @()
            }

            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        '.mov' {
            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'libx264'
                VideoArgs  = @('-preset', 'slow', '-crf', '16', '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                AudioCodec = 'copy'
                AudioArgs  = @()
            }

            if ($NvencAvailable) {
                $gpu = [PSCustomObject]@{
                    ModeLabel  = 'NVIDIA GPU'
                    VideoCodec = 'h264_nvenc'
                    VideoArgs  = @('-preset', 'p5', '-cq', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                    AudioCodec = 'copy'
                    AudioArgs  = @()
                }

                return [PSCustomObject]@{ Primary = $gpu; Fallback = $cpu }
            }

            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        '.webm' {
            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'libvpx-vp9'
                VideoArgs  = @('-crf', '28', '-b:v', '0', '-deadline', 'good', '-cpu-used', '2', '-row-mt', '1')
                AudioCodec = 'copy'
                AudioArgs  = @()
            }

            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        '.m4v' {
            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'libx264'
                VideoArgs  = @('-preset', 'slow', '-crf', '16', '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                AudioCodec = 'copy'
                AudioArgs  = @()
            }

            if ($NvencAvailable) {
                $gpu = [PSCustomObject]@{
                    ModeLabel  = 'NVIDIA GPU'
                    VideoCodec = 'h264_nvenc'
                    VideoArgs  = @('-preset', 'p5', '-cq', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                    AudioCodec = 'copy'
                    AudioArgs  = @()
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

function New-RotateVideoArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)][string]$Filter,
        [Parameter(Mandatory = $true)]$EncodingProfile
    )

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
        '-vf', $Filter,
        '-c:v', $EncodingProfile.VideoCodec
    )

    $ffmpegArgs += $EncodingProfile.VideoArgs
    $ffmpegArgs += @('-c:a', $EncodingProfile.AudioCodec)
    $ffmpegArgs += $EncodingProfile.AudioArgs
    $ffmpegArgs += @($OutputFile)

    return ,$ffmpegArgs
}

#__FFCOMMON_INJECT_HERE__

if ([string]::IsNullOrWhiteSpace($InputFile)) {
    Show-ErrorAndExit 'No input file received.'
}

if (-not (Test-Path -LiteralPath $InputFile)) {
    Show-ErrorAndExit "Input file not found.`n$InputFile"
}

$extension = [System.IO.Path]::GetExtension($InputFile).ToLowerInvariant()
if ($extension -notin @('.mp4', '.mkv', '.avi', '.mov', '.webm', '.m4v')) {
    Show-ErrorAndExit 'Unsupported file format. Supported: .mp4, .mkv, .avi, .mov, .webm, .m4v'
}

$ffmpegPath = Get-ToolPath -ToolName 'ffmpeg.exe'
$ffprobePath = Get-ToolPath -ToolName 'ffprobe.exe'

if (-not (Test-Path -LiteralPath $ffmpegPath)) {
    Show-ErrorAndExit "ffmpeg.exe not found.`n$ffmpegPath"
}

if (-not (Test-Path -LiteralPath $ffprobePath)) {
    Show-ErrorAndExit "ffprobe.exe not found.`n$ffprobePath"
}

try {
    $durationSeconds = Get-MediaDurationSeconds -FfprobePath $ffprobePath -InputPath $InputFile
}
catch {
    Show-ErrorAndExit $_.Exception.Message
}

$transform = Show-RotateVideoWindow -VideoPath $InputFile -FfmpegPath $ffmpegPath -DurationSeconds $durationSeconds
if ($null -eq $transform) {
    exit 0
}

$nvencAvailable = Test-NvencAvailable -FfmpegPath $ffmpegPath
$encodingPlan = Get-EncodingPlan -Extension $extension -NvencAvailable $nvencAvailable

$inputDir = Split-Path -Parent $InputFile
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
$desiredOutput = Join-Path $inputDir ("{0}_{1}{2}" -f $baseName, $transform.Label, $extension)
$script:OutputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

$result = Invoke-WithEncodingPlan -FfmpegPath $ffmpegPath -EncodingPlan $encodingPlan -DurationSeconds $durationSeconds -Title 'Rotate / flip video' -PreparingText "Preparing $($transform.Text.ToLowerInvariant())..." -FallbackPreparingText 'GPU unavailable. Retrying in CPU mode...' -OutputFile $script:OutputFile -ArgumentFactory {
    param($profile)
    New-RotateVideoArguments -InputFile $InputFile -OutputFile $script:OutputFile -Filter $transform.Filter -EncodingProfile $profile
}

if ($result.Cancelled) {
    Remove-PartialOutput -Path $script:OutputFile
    exit 0
}

if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $script:OutputFile)) {
    Remove-PartialOutput -Path $script:OutputFile
    $errorText = Get-ShortErrorText -StdErr $result.StdErr
    Show-ErrorAndExit $errorText
}

exit 0
