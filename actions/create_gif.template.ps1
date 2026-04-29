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

    return 'FFmpeg failed while creating the GIF.'
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
        [PSCustomObject]@{ Key = '10'; Label = '10 fps' }
        [PSCustomObject]@{ Key = '12'; Label = '12 fps' }
        [PSCustomObject]@{ Key = '15'; Label = '15 fps' }
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
    if ($fpsText -notin @('10', '12', '15')) {
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

function Show-CreateGifDialog {
    param(
        [Parameter(Mandatory = $true)]$VideoInfo,
        [Parameter(Mandatory = $true)][string]$SourceExtension
    )

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $resolutionItems = Get-ResolutionItems
    $fpsItems = Get-FpsItems
    $qualityItems = Get-QualityItems

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFActions - Create GIF'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(520, 335)
    $form.TopMost = $true

    $labelInfo = New-Object System.Windows.Forms.Label
    $labelInfo.Location = New-Object System.Drawing.Point(18, 14)
    $labelInfo.Size = New-Object System.Drawing.Size(480, 40)
    $resolutionText = if ($VideoInfo.Width -gt 0 -and $VideoInfo.Height -gt 0) { "$($VideoInfo.Width)x$($VideoInfo.Height)" } else { 'unknown resolution' }
    $labelInfo.Text = "Source: $($SourceExtension.TrimStart('.').ToUpperInvariant())    Duration: $(Format-TimeForDisplay -Seconds $VideoInfo.DurationSeconds)    Video: $resolutionText"
    $form.Controls.Add($labelInfo)

    $labelStart = New-Object System.Windows.Forms.Label
    $labelStart.Text = 'Start time'
    $labelStart.Location = New-Object System.Drawing.Point(18, 68)
    $labelStart.Size = New-Object System.Drawing.Size(100, 20)
    $form.Controls.Add($labelStart)

    $textStart = New-Object System.Windows.Forms.TextBox
    $textStart.Location = New-Object System.Drawing.Point(140, 66)
    $textStart.Size = New-Object System.Drawing.Size(170, 23)
    $textStart.Text = ''
    $form.Controls.Add($textStart)

    $labelDuration = New-Object System.Windows.Forms.Label
    $labelDuration.Text = 'Duration'
    $labelDuration.Location = New-Object System.Drawing.Point(18, 102)
    $labelDuration.Size = New-Object System.Drawing.Size(100, 20)
    $form.Controls.Add($labelDuration)

    $textDuration = New-Object System.Windows.Forms.TextBox
    $textDuration.Location = New-Object System.Drawing.Point(140, 100)
    $textDuration.Size = New-Object System.Drawing.Size(170, 23)
    $textDuration.Text = ''
    $form.Controls.Add($textDuration)

    $labelTimeHelp = New-Object System.Windows.Forms.Label
    $labelTimeHelp.Location = New-Object System.Drawing.Point(140, 126)
    $labelTimeHelp.Size = New-Object System.Drawing.Size(320, 18)
    $labelTimeHelp.Text = 'Leave blank to use the whole video.'
    $form.Controls.Add($labelTimeHelp)

    $labelResolution = New-Object System.Windows.Forms.Label
    $labelResolution.Text = 'Resolution'
    $labelResolution.Location = New-Object System.Drawing.Point(18, 160)
    $labelResolution.Size = New-Object System.Drawing.Size(100, 20)
    $form.Controls.Add($labelResolution)

    $comboResolution = New-Object System.Windows.Forms.ComboBox
    $comboResolution.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboResolution.Location = New-Object System.Drawing.Point(140, 158)
    $comboResolution.Size = New-Object System.Drawing.Size(170, 24)
    foreach ($item in $resolutionItems) { [void]$comboResolution.Items.Add($item.Label) }
    $comboResolution.SelectedIndex = 3
    $form.Controls.Add($comboResolution)

    $labelResolutionHelp = New-Object System.Windows.Forms.Label
    $labelResolutionHelp.Location = New-Object System.Drawing.Point(140, 184)
    $labelResolutionHelp.Size = New-Object System.Drawing.Size(340, 18)
    $labelResolutionHelp.Text = 'Keeps aspect ratio and never upscales.'
    $form.Controls.Add($labelResolutionHelp)

    $labelFps = New-Object System.Windows.Forms.Label
    $labelFps.Text = 'FPS'
    $labelFps.Location = New-Object System.Drawing.Point(18, 216)
    $labelFps.Size = New-Object System.Drawing.Size(100, 20)
    $form.Controls.Add($labelFps)

    $comboFps = New-Object System.Windows.Forms.ComboBox
    $comboFps.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboFps.Location = New-Object System.Drawing.Point(140, 214)
    $comboFps.Size = New-Object System.Drawing.Size(170, 24)
    foreach ($item in $fpsItems) { [void]$comboFps.Items.Add($item.Label) }
    $comboFps.SelectedIndex = 1
    $form.Controls.Add($comboFps)

    $labelQuality = New-Object System.Windows.Forms.Label
    $labelQuality.Text = 'Quality'
    $labelQuality.Location = New-Object System.Drawing.Point(18, 250)
    $labelQuality.Size = New-Object System.Drawing.Size(100, 20)
    $form.Controls.Add($labelQuality)

    $comboQuality = New-Object System.Windows.Forms.ComboBox
    $comboQuality.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboQuality.Location = New-Object System.Drawing.Point(140, 248)
    $comboQuality.Size = New-Object System.Drawing.Size(170, 24)
    foreach ($item in $qualityItems) { [void]$comboQuality.Items.Add($item.Label) }
    $comboQuality.SelectedIndex = 1
    $form.Controls.Add($comboQuality)

    $labelQualityHelp = New-Object System.Windows.Forms.Label
    $labelQualityHelp.Location = New-Object System.Drawing.Point(140, 274)
    $labelQualityHelp.Size = New-Object System.Drawing.Size(340, 18)
    $labelQualityHelp.Text = 'Higher quality keeps more colors. Small file reduces size more.'
    $form.Controls.Add($labelQualityHelp)

    $buttonOk = New-Object System.Windows.Forms.Button
    $buttonOk.Text = 'OK'
    $buttonOk.Location = New-Object System.Drawing.Point(325, 296)
    $buttonOk.Size = New-Object System.Drawing.Size(80, 28)
    $buttonOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($buttonOk)

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.Location = New-Object System.Drawing.Point(420, 296)
    $buttonCancel.Size = New-Object System.Drawing.Size(80, 28)
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($buttonCancel)

    $form.AcceptButton = $buttonOk
    $form.CancelButton = $buttonCancel

    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        $form.Dispose()
        return $null
    }

    $payload = [PSCustomObject]@{
        StartText     = $textStart.Text
        DurationText  = $textDuration.Text
        ResolutionKey = $resolutionItems[$comboResolution.SelectedIndex].Key
        Fps           = [int]$fpsItems[$comboFps.SelectedIndex].Key
        QualityKey    = $qualityItems[$comboQuality.SelectedIndex].Key
    }

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
        $gifConfig = Show-CreateGifDialog -VideoInfo $videoInfo -SourceExtension $extension
        if ($null -eq $gifConfig) {
            exit 0
        }
    }

    $startTimeSeconds = 0.0
    if (-not [string]::IsNullOrWhiteSpace($gifConfig.StartText)) {
        $startTimeSeconds = Parse-TimeInput -Text $gifConfig.StartText
    }
    if ($startTimeSeconds -lt 0) {
        throw 'Start time cannot be negative.'
    }
    if ($startTimeSeconds -ge $videoInfo.DurationSeconds) {
        throw 'Start time must be lower than the video duration.'
    }

    $durationSeconds = $videoInfo.DurationSeconds - $startTimeSeconds
    $customRange = $false

    if (-not [string]::IsNullOrWhiteSpace($gifConfig.DurationText)) {
        $durationSeconds = Parse-TimeInput -Text $gifConfig.DurationText
        $customRange = $true
    }
    elseif ($startTimeSeconds -gt 0) {
        $customRange = $true
    }

    if ($durationSeconds -le 0) {
        throw 'Duration must be greater than zero.'
    }

    if (($startTimeSeconds + $durationSeconds) -gt ($videoInfo.DurationSeconds + 0.001)) {
        throw 'The selected time range exceeds the source video duration.'
    }

    $fps = [int]$gifConfig.Fps
    if ($fps -notin @(10, 12, 15)) {
        throw 'Invalid FPS preset.'
    }

    $qualityProfile = Get-QualityProfile -QualityKey $gifConfig.QualityKey

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

    $startArg = $null
    $durationArg = $null
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    if ($startTimeSeconds -gt 0) {
        $startArg = $startTimeSeconds.ToString('0.###', $culture)
    }
    if ($durationSeconds -lt ($videoInfo.DurationSeconds - $startTimeSeconds - 0.001)) {
        $durationArg = $durationSeconds.ToString('0.###', $culture)
    }

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
