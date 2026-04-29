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

function Get-VideoInfo {
    param(
        [Parameter(Mandatory = $true)][string]$FfprobePath,
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    $probeResult = Invoke-HiddenProcess -FilePath $FfprobePath -Arguments @(
        '-v', 'error',
        '-show_entries', 'format=duration',
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

    $durationText = $null
    if ($map.ContainsKey('duration') -and $map['duration'] -match '^\d+([\.,]\d+)?$') {
        $durationText = $map['duration']
    }

    if ([string]::IsNullOrWhiteSpace($durationText)) {
        throw 'Unable to determine video duration.'
    }

    $durationSeconds = [double]::Parse($durationText.Replace(',', '.'), [System.Globalization.CultureInfo]::InvariantCulture)
    if ($durationSeconds -le 0) {
        throw 'Invalid video duration.'
    }

    return [PSCustomObject]@{
        DurationSeconds = $durationSeconds
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

function New-CutByTimeArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)][string]$StartArg,
        [Parameter(Mandatory = $true)][string]$DurationArg,
        [Parameter(Mandatory = $true)]$Profile
    )

    $ffmpegArgs = @(
        '-hide_banner',
        '-loglevel', 'error',
        '-progress', 'pipe:1',
        '-nostats',
        '-y',
        '-ss', $StartArg,
        '-i', $InputFile,
        '-t', $DurationArg,
        '-c:v', $Profile.VideoCodec
    )

    $ffmpegArgs += $Profile.VideoArgs
    $ffmpegArgs += @('-c:a', $Profile.AudioCodec)
    $ffmpegArgs += $Profile.AudioArgs
    $ffmpegArgs += @($OutputFile)

    return ,$ffmpegArgs
}

#__FFCOMMON_INJECT_HERE__

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

$totalDuration = [double]$videoInfo.DurationSeconds
$totalDurationText = Format-TimeForDisplay -Seconds $totalDuration

$form = New-Object System.Windows.Forms.Form
$form.Text = 'FFActions - Cut by Time'
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ClientSize = New-Object System.Drawing.Size(360, 190)
$form.TopMost = $true

$labelDuration = New-Object System.Windows.Forms.Label
$labelDuration.Text = "Duration: $totalDurationText"
$labelDuration.Location = New-Object System.Drawing.Point(20, 20)
$labelDuration.Size = New-Object System.Drawing.Size(320, 20)
$form.Controls.Add($labelDuration)

$labelStart = New-Object System.Windows.Forms.Label
$labelStart.Text = 'Start Time'
$labelStart.Location = New-Object System.Drawing.Point(20, 58)
$labelStart.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($labelStart)

$textStart = New-Object System.Windows.Forms.TextBox
$textStart.Location = New-Object System.Drawing.Point(140, 56)
$textStart.Size = New-Object System.Drawing.Size(170, 23)
$textStart.Text = '00:00:00.000'
$form.Controls.Add($textStart)

$labelEnd = New-Object System.Windows.Forms.Label
$labelEnd.Text = 'End Time'
$labelEnd.Location = New-Object System.Drawing.Point(20, 93)
$labelEnd.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($labelEnd)

$textEnd = New-Object System.Windows.Forms.TextBox
$textEnd.Location = New-Object System.Drawing.Point(140, 91)
$textEnd.Size = New-Object System.Drawing.Size(170, 23)
$textEnd.Text = $totalDurationText
$form.Controls.Add($textEnd)

$buttonOk = New-Object System.Windows.Forms.Button
$buttonOk.Text = 'OK'
$buttonOk.Location = New-Object System.Drawing.Point(154, 140)
$buttonOk.Size = New-Object System.Drawing.Size(75, 28)
$buttonOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($buttonOk)

$buttonCancel = New-Object System.Windows.Forms.Button
$buttonCancel.Text = 'Cancel'
$buttonCancel.Location = New-Object System.Drawing.Point(235, 140)
$buttonCancel.Size = New-Object System.Drawing.Size(75, 28)
$buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($buttonCancel)

$form.AcceptButton = $buttonOk
$form.CancelButton = $buttonCancel

$dialogResult = $form.ShowDialog()
if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK) {
    exit 0
}

try {
    $startTimeSeconds = Parse-TimeInput -Text $textStart.Text
    $endTimeSeconds = Parse-TimeInput -Text $textEnd.Text
}
catch {
    Show-ErrorAndExit $_.Exception.Message
}

if ($startTimeSeconds -lt 0) {
    Show-ErrorAndExit 'Start Time must be greater than or equal to 0.'
}
if ($endTimeSeconds -le 0) {
    Show-ErrorAndExit 'End Time must be greater than 0.'
}
if ($endTimeSeconds -le $startTimeSeconds) {
    Show-ErrorAndExit 'End Time must be greater than Start Time.'
}
if ($startTimeSeconds -gt $totalDuration) {
    Show-ErrorAndExit 'Start Time exceeds the video duration.'
}
if ($endTimeSeconds -gt $totalDuration) {
    Show-ErrorAndExit 'End Time exceeds the video duration.'
}

$durationSeconds = $endTimeSeconds - $startTimeSeconds
if ($durationSeconds -le 0) {
    Show-ErrorAndExit 'Invalid time range.'
}

$inputDir = Split-Path -Parent $InputFile
$inputBase = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
$startLabel = Format-TimeForFilename -Seconds $startTimeSeconds
$endLabel = Format-TimeForFilename -Seconds $endTimeSeconds
$desiredOutput = Join-Path $inputDir ("{0}__time_{1}_to_{2}{3}" -f $inputBase, $startLabel, $endLabel, $inputExt)
$outputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

$culture = [System.Globalization.CultureInfo]::InvariantCulture
$startArg = $startTimeSeconds.ToString('0.###', $culture)
$durationArg = $durationSeconds.ToString('0.###', $culture)

$nvencAvailable = Test-NvencAvailable -FfmpegPath $ffmpeg
$encodingPlan = Get-EncodingPlan -Extension $inputExt -NvencAvailable $nvencAvailable

try {
    $result = Invoke-WithEncodingPlan -FfmpegPath $ffmpeg -EncodingPlan $encodingPlan -DurationSeconds $durationSeconds -OutputFile $outputFile -Title 'Cut in progress' -PreparingText 'Preparing cut...' -FallbackPreparingText 'Retrying cut...' -ArgumentFactory {
        param($profile)
        New-CutByTimeArguments -InputFile $InputFile -OutputFile $outputFile -StartArg $startArg -DurationArg $durationArg -Profile $profile
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
