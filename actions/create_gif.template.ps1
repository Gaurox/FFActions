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

    if ($value -match '^(\d{1,2}):(\d{1,2}(?:\.\d+)?)$') {
        $minutes = 0.0
        $secs = 0.0
        if (-not [double]::TryParse($matches[1], [System.Globalization.NumberStyles]::Float, $culture, [ref]$minutes)) {
            throw 'Invalid time value.'
        }
        if (-not [double]::TryParse($matches[2], [System.Globalization.NumberStyles]::Float, $culture, [ref]$secs)) {
            throw 'Invalid time value.'
        }
        if ($secs -ge 60) {
            throw 'Seconds must be lower than 60.'
        }
        return ($minutes * 60.0) + $secs
    }

    if ($value -match '^(\d{1,2}):(\d{1,2}):(\d{1,2}(?:\.\d+)?)$') {
        $hours = 0.0
        $minutes = 0.0
        $secs = 0.0
        if (-not [double]::TryParse($matches[1], [System.Globalization.NumberStyles]::Float, $culture, [ref]$hours)) {
            throw 'Invalid time value.'
        }
        if (-not [double]::TryParse($matches[2], [System.Globalization.NumberStyles]::Float, $culture, [ref]$minutes)) {
            throw 'Invalid time value.'
        }
        if (-not [double]::TryParse($matches[3], [System.Globalization.NumberStyles]::Float, $culture, [ref]$secs)) {
            throw 'Invalid time value.'
        }
        if ($minutes -ge 60) {
            throw 'Minutes must be lower than 60.'
        }
        if ($secs -ge 60) {
            throw 'Seconds must be lower than 60.'
        }
        return ($hours * 3600.0) + ($minutes * 60.0) + $secs
    }

    throw 'Invalid time format. Use 85.5, 01:23.500 or 00:01:23.500.'
}

function Format-TimeForDisplay {
    param([Parameter(Mandatory = $true)][double]$Seconds)

    if ($Seconds -lt 0) {
        $Seconds = 0
    }

    $hours = [int][Math]::Floor($Seconds / 3600)
    $remaining = $Seconds - ($hours * 3600)
    $minutes = [int][Math]::Floor($remaining / 60)
    $secs = $remaining - ($minutes * 60)
    $culture = [System.Globalization.CultureInfo]::InvariantCulture

    return [string]::Format($culture, '{0:D2}:{1:D2}:{2:00.000}', $hours, $minutes, $secs)
}

function Format-TimeForFilename {
    param([Parameter(Mandatory = $true)][double]$Seconds)

    if ($Seconds -lt 0) {
        $Seconds = 0
    }

    $hours = [int][Math]::Floor($Seconds / 3600)
    $remaining = $Seconds - ($hours * 3600)
    $minutes = [int][Math]::Floor($remaining / 60)
    $secs = [int][Math]::Floor($remaining - ($minutes * 60))

    return '{0:D2}-{1:D2}-{2:D2}' -f $hours, $minutes, $secs
}

function Get-ResolutionItems {
    return @(
        [PSCustomObject]@{ Key = 'original'; Label = 'Original width' }
        [PSCustomObject]@{ Key = '1280'; Label = '1280 px' }
        [PSCustomObject]@{ Key = '960'; Label = '960 px' }
        [PSCustomObject]@{ Key = '720'; Label = '720 px' }
        [PSCustomObject]@{ Key = '540'; Label = '540 px' }
        [PSCustomObject]@{ Key = '360'; Label = '360 px' }
    )
}

function Get-FpsItems {
    return @(
        [PSCustomObject]@{ Key = '8'; Label = '8 fps' }
        [PSCustomObject]@{ Key = '10'; Label = '10 fps' }
        [PSCustomObject]@{ Key = '12'; Label = '12 fps' }
        [PSCustomObject]@{ Key = '15'; Label = '15 fps' }
        [PSCustomObject]@{ Key = '18'; Label = '18 fps' }
        [PSCustomObject]@{ Key = '20'; Label = '20 fps' }
    )
}

function Get-QualityItems {
    return @(
        [PSCustomObject]@{ Key = 'high'; Label = 'High' }
        [PSCustomObject]@{ Key = 'balanced'; Label = 'Balanced' }
        [PSCustomObject]@{ Key = 'small'; Label = 'Small file' }
    )
}

function Get-QualityProfile {
    param([Parameter(Mandatory = $true)][string]$QualityKey)

    switch ($QualityKey.ToLowerInvariant()) {
        'high' {
            return [PSCustomObject]@{
                ModeLabel  = 'GIF High'
                ScaleFlags = 'lanczos'
                PaletteGen = 'max_colors=256:stats_mode=full'
                PaletteUse = 'dither=sierra2_4a'
            }
        }
        'balanced' {
            return [PSCustomObject]@{
                ModeLabel  = 'GIF Balanced'
                ScaleFlags = 'bicubic'
                PaletteGen = 'max_colors=192:stats_mode=diff'
                PaletteUse = 'dither=sierra2_4a'
            }
        }
        'small' {
            return [PSCustomObject]@{
                ModeLabel  = 'GIF Small'
                ScaleFlags = 'bicubic'
                PaletteGen = 'max_colors=128:stats_mode=diff'
                PaletteUse = 'dither=bayer:bayer_scale=3'
            }
        }
        default {
            throw 'Unsupported GIF quality preset.'
        }
    }
}

function Get-ScaleFilter {
    param(
        [Parameter(Mandatory = $true)][string]$ResolutionKey,
        [Parameter(Mandatory = $true)][string]$ScaleFlags
    )

    switch ($ResolutionKey) {
        'original' { return "scale=iw:-1:flags=$ScaleFlags" }
        '1280'     { return "scale='if(gt(iw\,1280)\,1280\,iw)':-1:flags=$ScaleFlags" }
        '960'      { return "scale='if(gt(iw\,960)\,960\,iw)':-1:flags=$ScaleFlags" }
        '720'      { return "scale='if(gt(iw\,720)\,720\,iw)':-1:flags=$ScaleFlags" }
        '540'      { return "scale='if(gt(iw\,540)\,540\,iw)':-1:flags=$ScaleFlags" }
        '360'      { return "scale='if(gt(iw\,360)\,360\,iw)':-1:flags=$ScaleFlags" }
        default    { throw 'Unsupported GIF resolution preset.' }
    }
}

function New-CreateGifArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter()][string]$StartArg,
        [Parameter()][string]$DurationArg,
        [Parameter(Mandatory = $true)][string]$ResolutionKey,
        [Parameter(Mandatory = $true)][int]$Fps,
        [Parameter(Mandatory = $true)]$QualityProfile
    )

    $scaleFilter = Get-ScaleFilter -ResolutionKey $ResolutionKey -ScaleFlags $QualityProfile.ScaleFlags
    $filterComplex = "[0:v]fps=$Fps,$scaleFilter,split[s0][s1];[s0]palettegen=$($QualityProfile.PaletteGen)[p];[s1][p]paletteuse=$($QualityProfile.PaletteUse)[gif]"

    $ffmpegArgs = @(
        '-hide_banner',
        '-loglevel', 'error',
        '-progress', 'pipe:1',
        '-nostats',
        '-y'
    )

    if (-not [string]::IsNullOrWhiteSpace($StartArg)) {
        $ffmpegArgs += @('-ss', $StartArg)
    }
    if (-not [string]::IsNullOrWhiteSpace($DurationArg)) {
        $ffmpegArgs += @('-t', $DurationArg)
    }

    $ffmpegArgs += @(
        '-i', $InputFile,
        '-an',
        '-sn',
        '-dn',
        '-filter_complex', $filterComplex,
        '-map', '[gif]',
        '-loop', '0',
        $OutputFile
    )

    return ,$ffmpegArgs
}

function Get-EnvironmentValue {
    param([Parameter(Mandatory = $true)][string]$Name)

    $value = [System.Environment]::GetEnvironmentVariable($Name, 'Process')
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $null
    }

    return $value.Trim()
}

function Get-AutomationConfig {
    $flag = Get-EnvironmentValue -Name 'FFACTIONS_GIF_AUTOMATION'
    if ([string]::IsNullOrWhiteSpace($flag)) {
        return $null
    }

    switch ($flag.ToLowerInvariant()) {
        '1' {}
        'true' {}
        'yes' {}
        default { return $null }
    }

    $resolutionKey = Get-EnvironmentValue -Name 'FFACTIONS_GIF_RESOLUTION'
    if ([string]::IsNullOrWhiteSpace($resolutionKey)) { $resolutionKey = '720' }

    $fpsText = Get-EnvironmentValue -Name 'FFACTIONS_GIF_FPS'
    if ([string]::IsNullOrWhiteSpace($fpsText)) { $fpsText = '12' }

    $qualityKey = Get-EnvironmentValue -Name 'FFACTIONS_GIF_QUALITY'
    if ([string]::IsNullOrWhiteSpace($qualityKey)) { $qualityKey = 'balanced' }

    if ($resolutionKey -notin @('original', '1280', '960', '720', '540', '360')) {
        throw 'Invalid automation value for FFACTIONS_GIF_RESOLUTION.'
    }
    if ($fpsText -notin @('8', '10', '12', '15', '18', '20')) {
        throw 'Invalid automation value for FFACTIONS_GIF_FPS.'
    }
    if ($qualityKey -notin @('high', 'balanced', 'small')) {
        throw 'Invalid automation value for FFACTIONS_GIF_QUALITY.'
    }

    return [PSCustomObject]@{
        StartText     = Get-EnvironmentValue -Name 'FFACTIONS_GIF_START'
        DurationText  = Get-EnvironmentValue -Name 'FFACTIONS_GIF_DURATION'
        ResolutionKey = $resolutionKey
        Fps           = [int]$fpsText
        QualityKey    = $qualityKey
    }
}

function Resolve-CreateGifConfig {
    param(
        [Parameter(Mandatory = $true)]$GifConfig,
        [Parameter(Mandatory = $true)]$VideoInfo
    )

    $startTimeSeconds = 0.0
    if (-not [string]::IsNullOrWhiteSpace($GifConfig.StartText)) {
        $startTimeSeconds = Parse-TimeInput -Text $GifConfig.StartText
    }
    if ($startTimeSeconds -lt 0) {
        throw 'Start time cannot be negative.'
    }
    if ($startTimeSeconds -ge $VideoInfo.DurationSeconds) {
        throw 'Start time must be lower than the video duration.'
    }

    $durationSeconds = $VideoInfo.DurationSeconds - $startTimeSeconds
    $customRange = $false

    if (-not [string]::IsNullOrWhiteSpace($GifConfig.DurationText)) {
        $durationSeconds = Parse-TimeInput -Text $GifConfig.DurationText
        $customRange = $true
    }
    elseif ($startTimeSeconds -gt 0) {
        $customRange = $true
    }

    if ($durationSeconds -le 0) {
        throw 'Duration must be greater than zero.'
    }

    if (($startTimeSeconds + $durationSeconds) -gt ($VideoInfo.DurationSeconds + 0.001)) {
        throw 'The selected time range exceeds the source video duration.'
    }

    $fps = [int]$GifConfig.Fps
    if ($fps -notin @(8, 10, 12, 15, 18, 20)) {
        throw 'Invalid FPS preset.'
    }

    $qualityProfile = Get-QualityProfile -QualityKey $GifConfig.QualityKey
    $culture = [System.Globalization.CultureInfo]::InvariantCulture

    $startArg = $null
    $durationArg = $null
    if ($startTimeSeconds -gt 0) {
        $startArg = $startTimeSeconds.ToString('0.###', $culture)
    }
    if ($durationSeconds -lt ($VideoInfo.DurationSeconds - $startTimeSeconds - 0.001)) {
        $durationArg = $durationSeconds.ToString('0.###', $culture)
    }

    return [PSCustomObject]@{
        StartText        = $GifConfig.StartText
        DurationText     = $GifConfig.DurationText
        ResolutionKey    = $GifConfig.ResolutionKey
        Fps              = $fps
        QualityKey       = $GifConfig.QualityKey
        QualityProfile   = $qualityProfile
        StartTimeSeconds = $startTimeSeconds
        DurationSeconds  = $durationSeconds
        CustomRange      = $customRange
        StartArg         = $startArg
        DurationArg      = $durationArg
    }
}

function Get-GifPreviewDurationSeconds {
    param([Parameter(Mandatory = $true)][double]$DurationSeconds)

    return [Math]::Min(6.0, [Math]::Max(0.5, $DurationSeconds))
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

function New-VideoPreviewBitmapAtTime {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [Parameter(Mandatory = $true)][double]$TimeSeconds,
        [Parameter(Mandatory = $true)][int]$MaxWidth,
        [Parameter(Mandatory = $true)][int]$MaxHeight
    )

    $safeSeconds = [Math]::Max(0.0, $TimeSeconds)
    $secondsText = $safeSeconds.ToString('0.###', [System.Globalization.CultureInfo]::InvariantCulture)
    $tmpPath = Join-Path ([System.IO.Path]::GetTempPath()) ("ffactions_gif_frame_preview_{0}.png" -f ([guid]::NewGuid().ToString('N')))

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

function Show-CreateGifDialog {
    param(
        [Parameter(Mandatory = $true)]$VideoInfo,
        [Parameter(Mandatory = $true)][string]$SourceExtension,
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$FfmpegPath
    )

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $resolutionItems = Get-ResolutionItems
    $fpsItems = Get-FpsItems
    $qualityItems = Get-QualityItems
    $previewState = [PSCustomObject]@{
        IsRunning = $false
        GifPath   = $null
        GifStream = $null
        GifImage  = $null
    }

    $selection = [PSCustomObject]@{
        StartSeconds = 0.0
        EndSeconds   = $VideoInfo.DurationSeconds
    }
    $dragState = [PSCustomObject]@{
        Active = $false
        Target = ''
    }
    $uiState = [PSCustomObject]@{
        ActiveBoundary       = 'start'
        PendingPreviewTime   = 0.0
        CurrentPreviewBitmap = $null
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFActions - Create GIF'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(900, 640)
    $form.TopMost = $true

    $labelInfo = New-Object System.Windows.Forms.Label
    $labelInfo.Location = New-Object System.Drawing.Point(20, 14)
    $labelInfo.Size = New-Object System.Drawing.Size(860, 22)
    $resolutionText = if ($VideoInfo.Width -gt 0 -and $VideoInfo.Height -gt 0) { "$($VideoInfo.Width)x$($VideoInfo.Height)" } else { 'unknown resolution' }
    $labelInfo.Text = "Source: $($SourceExtension.TrimStart('.').ToUpperInvariant())    Duration: $(Format-TimeForDisplay -Seconds $VideoInfo.DurationSeconds)    Video: $resolutionText"
    $form.Controls.Add($labelInfo)

    $previewPanel = New-Object System.Windows.Forms.Panel
    $previewPanel.Location = New-Object System.Drawing.Point(20, 42)
    $previewPanel.Size = New-Object System.Drawing.Size(860, 320)
    $previewPanel.BackColor = [System.Drawing.Color]::FromArgb(36, 36, 36)
    Enable-ControlDoubleBuffering -Control $previewPanel
    $form.Controls.Add($previewPanel)

    $previewBox = New-Object System.Windows.Forms.PictureBox
    $previewBox.Location = New-Object System.Drawing.Point(0, 0)
    $previewBox.Size = $previewPanel.Size
    $previewBox.BackColor = [System.Drawing.Color]::Transparent
    $previewBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $previewPanel.Controls.Add($previewBox)

    $selectionPanel = New-Object System.Windows.Forms.Panel
    $selectionPanel.Location = New-Object System.Drawing.Point(20, 374)
    $selectionPanel.Size = New-Object System.Drawing.Size(860, 74)
    $selectionPanel.BackColor = [System.Drawing.Color]::White
    $selectionPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    Enable-ControlDoubleBuffering -Control $selectionPanel
    $form.Controls.Add($selectionPanel)

    $labelSelection = New-Object System.Windows.Forms.Label
    $labelSelection.Location = New-Object System.Drawing.Point(20, 456)
    $labelSelection.Size = New-Object System.Drawing.Size(860, 20)
    $form.Controls.Add($labelSelection)

    $labelHint = New-Object System.Windows.Forms.Label
    $labelHint.Location = New-Object System.Drawing.Point(20, 480)
    $labelHint.Size = New-Object System.Drawing.Size(860, 20)
    $labelHint.Text = 'Drag the left or right handle to choose the GIF range. The preview shows the active boundary frame.'
    $form.Controls.Add($labelHint)

    $column1X = 20
    $column2X = 315
    $column3X = 610
    $labelWidth = 92
    $fieldWidth = 188

    $labelStartFrame = New-Object System.Windows.Forms.Label
    $labelStartFrame.Location = New-Object System.Drawing.Point($column1X, 514)
    $labelStartFrame.Size = New-Object System.Drawing.Size($labelWidth, 20)
    $labelStartFrame.Text = 'Frame start'
    $form.Controls.Add($labelStartFrame)

    $textStartFrame = New-Object System.Windows.Forms.TextBox
    $textStartFrame.Location = New-Object System.Drawing.Point(($column1X + $labelWidth + 8), 511)
    $textStartFrame.Size = New-Object System.Drawing.Size($fieldWidth, 24)
    $textStartFrame.ReadOnly = $true
    $textStartFrame.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Left
    $form.Controls.Add($textStartFrame)

    $labelEndFrame = New-Object System.Windows.Forms.Label
    $labelEndFrame.Location = New-Object System.Drawing.Point($column2X, 514)
    $labelEndFrame.Size = New-Object System.Drawing.Size($labelWidth, 20)
    $labelEndFrame.Text = 'Frame end'
    $form.Controls.Add($labelEndFrame)

    $textEndFrame = New-Object System.Windows.Forms.TextBox
    $textEndFrame.Location = New-Object System.Drawing.Point(($column2X + $labelWidth + 8), 511)
    $textEndFrame.Size = New-Object System.Drawing.Size($fieldWidth, 24)
    $textEndFrame.ReadOnly = $true
    $textEndFrame.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Left
    $form.Controls.Add($textEndFrame)

    $labelFrameInfo = New-Object System.Windows.Forms.Label
    $labelFrameInfo.Location = New-Object System.Drawing.Point($column3X, 514)
    $labelFrameInfo.Size = New-Object System.Drawing.Size(250, 20)
    $labelFrameInfo.Text = 'Frames use the selected GIF FPS.'
    $form.Controls.Add($labelFrameInfo)

    $labelStart = New-Object System.Windows.Forms.Label
    $labelStart.Location = New-Object System.Drawing.Point($column1X, 548)
    $labelStart.Size = New-Object System.Drawing.Size($labelWidth, 20)
    $labelStart.Text = 'Start'
    $form.Controls.Add($labelStart)

    $textStart = New-Object System.Windows.Forms.TextBox
    $textStart.Location = New-Object System.Drawing.Point(($column1X + $labelWidth + 8), 545)
    $textStart.Size = New-Object System.Drawing.Size($fieldWidth, 24)
    $textStart.ReadOnly = $true
    $textStart.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Left
    $form.Controls.Add($textStart)

    $labelEnd = New-Object System.Windows.Forms.Label
    $labelEnd.Location = New-Object System.Drawing.Point($column2X, 548)
    $labelEnd.Size = New-Object System.Drawing.Size($labelWidth, 20)
    $labelEnd.Text = 'End'
    $form.Controls.Add($labelEnd)

    $textEnd = New-Object System.Windows.Forms.TextBox
    $textEnd.Location = New-Object System.Drawing.Point(($column2X + $labelWidth + 8), 545)
    $textEnd.Size = New-Object System.Drawing.Size($fieldWidth, 24)
    $textEnd.ReadOnly = $true
    $textEnd.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Left
    $form.Controls.Add($textEnd)

    $labelDuration = New-Object System.Windows.Forms.Label
    $labelDuration.Location = New-Object System.Drawing.Point($column3X, 548)
    $labelDuration.Size = New-Object System.Drawing.Size(76, 20)
    $labelDuration.Text = 'Duration'
    $form.Controls.Add($labelDuration)

    $textDuration = New-Object System.Windows.Forms.TextBox
    $textDuration.Location = New-Object System.Drawing.Point(($column3X + 76), 545)
    $textDuration.Size = New-Object System.Drawing.Size(172, 24)
    $textDuration.ReadOnly = $true
    $textDuration.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Left
    $form.Controls.Add($textDuration)

    $labelResolution = New-Object System.Windows.Forms.Label
    $labelResolution.Text = 'Resolution'
    $labelResolution.Location = New-Object System.Drawing.Point(20, 584)
    $labelResolution.Size = New-Object System.Drawing.Size(100, 20)
    $form.Controls.Add($labelResolution)

    $comboResolution = New-Object System.Windows.Forms.ComboBox
    $comboResolution.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboResolution.Location = New-Object System.Drawing.Point(124, 582)
    $comboResolution.Size = New-Object System.Drawing.Size(160, 24)
    foreach ($item in $resolutionItems) { [void]$comboResolution.Items.Add($item.Label) }
    $comboResolution.SelectedIndex = 3
    $form.Controls.Add($comboResolution)

    $labelFps = New-Object System.Windows.Forms.Label
    $labelFps.Text = 'FPS'
    $labelFps.Location = New-Object System.Drawing.Point(314, 584)
    $labelFps.Size = New-Object System.Drawing.Size(60, 20)
    $form.Controls.Add($labelFps)

    $comboFps = New-Object System.Windows.Forms.ComboBox
    $comboFps.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboFps.Location = New-Object System.Drawing.Point(402, 582)
    $comboFps.Size = New-Object System.Drawing.Size(160, 24)
    foreach ($item in $fpsItems) { [void]$comboFps.Items.Add($item.Label) }
    $comboFps.SelectedIndex = 2
    $form.Controls.Add($comboFps)

    $labelQuality = New-Object System.Windows.Forms.Label
    $labelQuality.Text = 'Quality'
    $labelQuality.Location = New-Object System.Drawing.Point(592, 584)
    $labelQuality.Size = New-Object System.Drawing.Size(80, 20)
    $form.Controls.Add($labelQuality)

    $comboQuality = New-Object System.Windows.Forms.ComboBox
    $comboQuality.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboQuality.Location = New-Object System.Drawing.Point(680, 582)
    $comboQuality.Size = New-Object System.Drawing.Size(160, 24)
    foreach ($item in $qualityItems) { [void]$comboQuality.Items.Add($item.Label) }
    $comboQuality.SelectedIndex = 1
    $form.Controls.Add($comboQuality)

    $buttonPreview = New-Object System.Windows.Forms.Button
    $buttonPreview.Text = 'Preview GIF'
    $buttonPreview.Location = New-Object System.Drawing.Point(20, 602)
    $buttonPreview.Size = New-Object System.Drawing.Size(104, 28)
    $form.Controls.Add($buttonPreview)

    $labelPreviewStatus = New-Object System.Windows.Forms.Label
    $labelPreviewStatus.Location = New-Object System.Drawing.Point(136, 606)
    $labelPreviewStatus.Size = New-Object System.Drawing.Size(450, 20)
    $form.Controls.Add($labelPreviewStatus)

    $buttonOk = New-Object System.Windows.Forms.Button
    $buttonOk.Text = 'OK'
    $buttonOk.Location = New-Object System.Drawing.Point(724, 602)
    $buttonOk.Size = New-Object System.Drawing.Size(75, 28)
    $buttonOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($buttonOk)

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.Location = New-Object System.Drawing.Point(805, 602)
    $buttonCancel.Size = New-Object System.Drawing.Size(75, 28)
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($buttonCancel)

    $form.AcceptButton = $buttonOk
    $form.CancelButton = $buttonCancel

    $previewTimer = New-Object System.Windows.Forms.Timer
    $previewTimer.Interval = 140

    function Convert-SecondsToTrackX {
        param([double]$Seconds)

        $trackLeft = 18
        $trackWidth = $selectionPanel.ClientSize.Width - 36
        if ($VideoInfo.DurationSeconds -le 0 -or $trackWidth -le 0) { return $trackLeft }

        $ratio = $Seconds / [double]$VideoInfo.DurationSeconds
        if ($ratio -lt 0.0) { $ratio = 0.0 }
        if ($ratio -gt 1.0) { $ratio = 1.0 }
        return [int][Math]::Round($trackLeft + ($ratio * $trackWidth))
    }

    function Convert-TrackXToSeconds {
        param([int]$X)

        $trackLeft = 18
        $trackWidth = $selectionPanel.ClientSize.Width - 36
        if ($trackWidth -le 0 -or $VideoInfo.DurationSeconds -le 0) { return 0.0 }

        $clamped = [Math]::Min(($trackLeft + $trackWidth), [Math]::Max($trackLeft, $X))
        $ratio = ($clamped - $trackLeft) / [double]$trackWidth
        return ($ratio * $VideoInfo.DurationSeconds)
    }

    function Dispose-PreviewBitmap {
        if ($previewBox.Image) {
            $previewBox.Image = $null
        }
        if ($uiState.CurrentPreviewBitmap) {
            try { $uiState.CurrentPreviewBitmap.Dispose() } catch {}
            $uiState.CurrentPreviewBitmap = $null
        }
    }

    function Dispose-GifPreview {
        if ($previewBox.Image -eq $previewState.GifImage) {
            $previewBox.Image = $null
        }
        if ($previewState.GifImage) {
            try { $previewState.GifImage.Dispose() } catch {}
            $previewState.GifImage = $null
        }
        if ($previewState.GifStream) {
            try { $previewState.GifStream.Dispose() } catch {}
            $previewState.GifStream = $null
        }
        Remove-PartialOutput -Path $previewState.GifPath
        $previewState.GifPath = $null
    }

    function Set-GifPreviewImage {
        param([Parameter(Mandatory = $true)][string]$Path)

        Dispose-GifPreview
        Dispose-PreviewBitmap

        $bytes = [System.IO.File]::ReadAllBytes($Path)
        $stream = New-Object System.IO.MemoryStream
        [void]$stream.Write($bytes, 0, $bytes.Length)
        $stream.Position = 0
        $image = [System.Drawing.Image]::FromStream($stream)

        $previewState.GifPath = $Path
        $previewState.GifStream = $stream
        $previewState.GifImage = $image
        $previewBox.Image = $image
    }

    function Stop-Preview {
        param([bool]$RestoreFrame = $true)

        if (-not $previewState.IsRunning -and -not $previewState.GifPath) {
            return
        }

        $previewState.IsRunning = $false
        $buttonPreview.Text = 'Preview GIF'
        Dispose-GifPreview
        $labelPreviewStatus.Text = ''

        if ($RestoreFrame) {
            $previewTime = if ($uiState.ActiveBoundary -eq 'end') { $selection.EndSeconds } else { $selection.StartSeconds }
            Schedule-PreviewUpdate -TimeSeconds $previewTime
        }
    }

    function Load-PreviewFrame {
        param([Parameter(Mandatory = $true)][double]$TimeSeconds)

        $safeTime = [Math]::Max(0.0, [Math]::Min(($VideoInfo.DurationSeconds - 0.001), $TimeSeconds))
        if ($previewState.IsRunning) {
            Stop-Preview -RestoreFrame $false
        }
        $newBitmap = New-VideoPreviewBitmapAtTime -InputFile $InputFile -FfmpegPath $FfmpegPath -TimeSeconds $safeTime -MaxWidth 820 -MaxHeight 300
        Dispose-PreviewBitmap
        $uiState.CurrentPreviewBitmap = $newBitmap
        $previewBox.Image = $uiState.CurrentPreviewBitmap
    }

    function Schedule-PreviewUpdate {
        param([Parameter(Mandatory = $true)][double]$TimeSeconds)

        $uiState.PendingPreviewTime = $TimeSeconds
        $previewTimer.Stop()
        $previewTimer.Start()
    }

    function Refresh-SelectionUi {
        $startSeconds = [Math]::Max(0.0, $selection.StartSeconds)
        $endSeconds = [Math]::Min($VideoInfo.DurationSeconds, $selection.EndSeconds)
        if ($endSeconds -lt $startSeconds) {
            $tmp = $startSeconds
            $startSeconds = $endSeconds
            $endSeconds = $tmp
        }

        $durationSeconds = [Math]::Max(0.001, ($endSeconds - $startSeconds))
        $gifFps = [int]$fpsItems[$comboFps.SelectedIndex].Key
        $startFrame = 1 + [int][Math]::Floor($startSeconds * $gifFps)
        $endFrame = [int][Math]::Ceiling($endSeconds * $gifFps)
        if ($endFrame -lt $startFrame) { $endFrame = $startFrame }

        $textStartFrame.Text = [string]$startFrame
        $textEndFrame.Text = [string]$endFrame
        $textStart.Text = Format-TimeForDisplay -Seconds $startSeconds
        $textEnd.Text = Format-TimeForDisplay -Seconds $endSeconds
        $textDuration.Text = Format-TimeForDisplay -Seconds $durationSeconds
        $labelSelection.Text = ("Selection: frame {0} -> {1}  |  {2} -> {3}  |  Duration: {4}" -f $startFrame, $endFrame, (Format-TimeForDisplay -Seconds $startSeconds), (Format-TimeForDisplay -Seconds $endSeconds), (Format-TimeForDisplay -Seconds $durationSeconds))
        $selectionPanel.Invalidate()

        $previewTime = if ($uiState.ActiveBoundary -eq 'end') { $endSeconds } else { $startSeconds }
        Schedule-PreviewUpdate -TimeSeconds $previewTime
    }

    function Get-DialogConfig {
        $startSeconds = [Math]::Max(0.0, $selection.StartSeconds)
        $endSeconds = [Math]::Min($VideoInfo.DurationSeconds, $selection.EndSeconds)
        $durationSeconds = [Math]::Max(0.001, ($endSeconds - $startSeconds))
        $fullRange = ($startSeconds -le 0.001) -and (($VideoInfo.DurationSeconds - $endSeconds) -le 0.001)

        $startText = if ($startSeconds -gt 0.001) { $startSeconds.ToString('0.###', [System.Globalization.CultureInfo]::InvariantCulture) } else { '' }
        $durationText = if ($fullRange -or (($VideoInfo.DurationSeconds - $endSeconds) -le 0.001)) { '' } else { $durationSeconds.ToString('0.###', [System.Globalization.CultureInfo]::InvariantCulture) }

        return [PSCustomObject]@{
            StartText     = $startText
            DurationText  = $durationText
            ResolutionKey = $resolutionItems[$comboResolution.SelectedIndex].Key
            Fps           = [int]$fpsItems[$comboFps.SelectedIndex].Key
            QualityKey    = $qualityItems[$comboQuality.SelectedIndex].Key
        }
    }

    function Start-Preview {
        Stop-Preview -RestoreFrame $false

        try {
            $resolved = Resolve-CreateGifConfig -GifConfig (Get-DialogConfig) -VideoInfo $VideoInfo
            $previewSeconds = Get-GifPreviewDurationSeconds -DurationSeconds $resolved.DurationSeconds
            $gifPreviewPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ffactions_create_gif_render_preview_{0}.gif' -f ([System.Guid]::NewGuid().ToString('N')))

            $buttonPreview.Enabled = $false
            $labelPreviewStatus.Text = 'Rendering GIF preview...'
            [System.Windows.Forms.Application]::DoEvents()

            $gifArgs = New-CreateGifArguments `
                -InputFile $InputFile `
                -OutputFile $gifPreviewPath `
                -StartArg $resolved.StartArg `
                -DurationArg ($previewSeconds.ToString('0.###', [System.Globalization.CultureInfo]::InvariantCulture)) `
                -ResolutionKey $resolved.ResolutionKey `
                -Fps $resolved.Fps `
                -QualityProfile $resolved.QualityProfile
            $gifResult = Invoke-HiddenProcess -FilePath $FfmpegPath -Arguments $gifArgs
            if ($gifResult.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $gifPreviewPath)) {
                Remove-PartialOutput -Path $gifPreviewPath
                throw (Get-ShortErrorText -StdErr $gifResult.StdErr)
            }

            Set-GifPreviewImage -Path $gifPreviewPath
            $previewState.IsRunning = $true
            $buttonPreview.Text = 'Stop preview'
            $labelPreviewStatus.Text = ('Looping GIF preview, {0}s at {1} fps' -f $previewSeconds.ToString('0.#', [System.Globalization.CultureInfo]::InvariantCulture), $resolved.Fps)
        }
        catch {
            Stop-Preview -RestoreFrame $true
            [System.Windows.Forms.MessageBox]::Show(
                $_.Exception.Message,
                'FFActions - Preview error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
        finally {
            $buttonPreview.Enabled = $true
        }
    }

    $previewTimer.Add_Tick({
        $previewTimer.Stop()
        try {
            Load-PreviewFrame -TimeSeconds $uiState.PendingPreviewTime
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                $_.Exception.Message,
                'FFActions - Preview error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    })

    $selectionPanel.Add_Paint({
        param($sender, $e)

        $graphics = $e.Graphics
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

        $trackLeft = 18
        $trackTop = 36
        $trackWidth = $selectionPanel.ClientSize.Width - 36
        $trackHeight = 6
        $handleWidth = 10
        $handleHeight = 28

        $startX = [int](Convert-SecondsToTrackX -Seconds $selection.StartSeconds)
        $endX = [int](Convert-SecondsToTrackX -Seconds $selection.EndSeconds)
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

            $graphics.DrawString('0', $form.Font, [System.Drawing.Brushes]::DimGray, 14, 2)
            $lastText = Format-TimeForDisplay -Seconds $VideoInfo.DurationSeconds
            $lastSize = $graphics.MeasureString($lastText, $form.Font)
            $graphics.DrawString($lastText, $form.Font, [System.Drawing.Brushes]::DimGray, ($selectionPanel.ClientSize.Width - $lastSize.Width - 14), 2)
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

        Stop-Preview -RestoreFrame $false

        $startX = [int](Convert-SecondsToTrackX -Seconds $selection.StartSeconds)
        $endX = [int](Convert-SecondsToTrackX -Seconds $selection.EndSeconds)
        $distanceToStart = [Math]::Abs(([int]$e.X) - $startX)
        $distanceToEnd = [Math]::Abs(([int]$e.X) - $endX)

        $dragState.Active = $true
        $dragState.Target = if ($distanceToStart -le $distanceToEnd) { 'start' } else { 'end' }
        $uiState.ActiveBoundary = $dragState.Target
        $selectionPanel.Capture = $true

        $seconds = Convert-TrackXToSeconds -X ([int]$e.X)
        if ($dragState.Target -eq 'start') {
            if ($seconds -gt ($selection.EndSeconds - 0.001)) { $seconds = [Math]::Max(0.0, ($selection.EndSeconds - 0.001)) }
            $selection.StartSeconds = $seconds
        }
        else {
            if ($seconds -lt ($selection.StartSeconds + 0.001)) { $seconds = [Math]::Min($VideoInfo.DurationSeconds, ($selection.StartSeconds + 0.001)) }
            $selection.EndSeconds = $seconds
        }

        Refresh-SelectionUi
    })

    $selectionPanel.Add_MouseMove({
        param($sender, $e)

        if (-not $dragState.Active) { return }

        if ($previewState.IsRunning) {
            Stop-Preview -RestoreFrame $false
        }

        $seconds = Convert-TrackXToSeconds -X ([int]$e.X)
        if ($dragState.Target -eq 'start') {
            if ($seconds -gt ($selection.EndSeconds - 0.001)) { $seconds = [Math]::Max(0.0, ($selection.EndSeconds - 0.001)) }
            $selection.StartSeconds = $seconds
        }
        else {
            if ($seconds -lt ($selection.StartSeconds + 0.001)) { $seconds = [Math]::Min($VideoInfo.DurationSeconds, ($selection.StartSeconds + 0.001)) }
            $selection.EndSeconds = $seconds
        }

        Refresh-SelectionUi
    })

    $selectionPanel.Add_MouseUp({
        param($sender, $e)
        $dragState.Active = $false
        $dragState.Target = ''
        $selectionPanel.Capture = $false
    })

    $comboResolution.Add_SelectedIndexChanged({
        Stop-Preview -RestoreFrame $true
    })
    $comboFps.Add_SelectedIndexChanged({
        Stop-Preview -RestoreFrame $true
        Refresh-SelectionUi
    })
    $comboQuality.Add_SelectedIndexChanged({
        Stop-Preview -RestoreFrame $true
    })

    $buttonPreview.Add_Click({
        if ($previewState.IsRunning) {
            Stop-Preview -RestoreFrame $true
        }
        else {
            Start-Preview
        }
    })

    $form.Add_FormClosing({
        $previewTimer.Stop()
        Dispose-GifPreview
        Dispose-PreviewBitmap
    })

    Refresh-SelectionUi

    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        $previewTimer.Stop()
        Dispose-GifPreview
        Dispose-PreviewBitmap
        $form.Dispose()
        return $null
    }

    $payload = Get-DialogConfig

    $previewTimer.Stop()
    Dispose-GifPreview
    Dispose-PreviewBitmap
    $form.Dispose()
    return $payload
}

#__FFCOMMON_INJECT_HERE__

if ([string]::IsNullOrWhiteSpace($InputFile)) {
    Show-ErrorAndExit 'Input file is missing.'
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
    $videoInfo = Get-VideoInfo -FfprobePath $ffprobePath -FilePath $InputFile
}
catch {
    Show-ErrorAndExit "Unable to read video information.`n$($_.Exception.Message)"
}

try {
    $gifConfig = Get-AutomationConfig
    if ($null -eq $gifConfig) {
        $gifConfig = Show-CreateGifDialog -VideoInfo $videoInfo -SourceExtension $extension -InputFile $InputFile -FfmpegPath $ffmpegPath
        if ($null -eq $gifConfig) {
            exit 0
        }
    }

    $resolvedGifConfig = Resolve-CreateGifConfig -GifConfig $gifConfig -VideoInfo $videoInfo
    $startTimeSeconds = $resolvedGifConfig.StartTimeSeconds
    $durationSeconds = $resolvedGifConfig.DurationSeconds
    $customRange = $resolvedGifConfig.CustomRange
    $fps = $resolvedGifConfig.Fps
    $qualityProfile = $resolvedGifConfig.QualityProfile

    $inputDir = Split-Path -Parent $InputFile
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    if ($customRange) {
        $startLabel = Format-TimeForFilename -Seconds $startTimeSeconds
        $durationLabel = Format-TimeForFilename -Seconds $durationSeconds
        $desiredOutput = Join-Path $inputDir ("{0}_gif_{1}_for_{2}.gif" -f $baseName, $startLabel, $durationLabel)
    }
    else {
        $desiredOutput = Join-Path $inputDir ($baseName + '_gif.gif')
    }
    $script:OutputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

    $startArg = $resolvedGifConfig.StartArg
    $durationArg = $resolvedGifConfig.DurationArg

    $encodingPlan = [PSCustomObject]@{
        Primary  = [PSCustomObject]@{ ModeLabel = $qualityProfile.ModeLabel }
        Fallback = $null
    }

    $result = Invoke-WithEncodingPlan `
        -FfmpegPath $ffmpegPath `
        -EncodingPlan $encodingPlan `
        -DurationSeconds $durationSeconds `
        -Title 'Create GIF' `
        -PreparingText 'Preparing GIF creation...' `
        -OutputFile $script:OutputFile `
        -ArgumentFactory {
            param($profile)
            New-CreateGifArguments `
                -InputFile $InputFile `
                -OutputFile $script:OutputFile `
                -StartArg $startArg `
                -DurationArg $durationArg `
                -ResolutionKey $gifConfig.ResolutionKey `
                -Fps $fps `
                -QualityProfile $qualityProfile
        }

    if ($result.Cancelled) {
        Remove-PartialOutput -Path $script:OutputFile
        exit 0
    }

    if ($result.ExitCode -ne 0) {
        Remove-PartialOutput -Path $script:OutputFile
        Show-ErrorAndExit (Get-ShortErrorText -StdErr $result.StdErr)
    }
}
catch {
    if ($script:OutputFile) {
        Remove-PartialOutput -Path $script:OutputFile
    }

    Show-ErrorAndExit $_.Exception.Message
}

exit 0
