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
        default {
            throw 'Unsupported input format. Only .mp4, .mkv and .avi are supported.'
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

if ([string]::IsNullOrWhiteSpace($InputFile)) {
    Show-ErrorAndExit 'Input file is missing.'
}

if (-not (Test-Path -LiteralPath $InputFile)) {
    Show-ErrorAndExit "Input file not found.`n$InputFile"
}

$inputExt = [System.IO.Path]::GetExtension($InputFile).ToLowerInvariant()
if ($inputExt -notin @('.mp4', '.mkv', '.avi')) {
    Show-ErrorAndExit 'Unsupported input format. Only .mp4, .mkv and .avi are supported.'
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

$form = New-Object System.Windows.Forms.Form
$form.Text = 'FFActions - Cut by Frame'
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ClientSize = New-Object System.Drawing.Size(320, 155)
$form.TopMost = $true

$labelStart = New-Object System.Windows.Forms.Label
$labelStart.Text = 'Start Frame'
$labelStart.Location = New-Object System.Drawing.Point(20, 20)
$labelStart.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($labelStart)

$textStart = New-Object System.Windows.Forms.TextBox
$textStart.Location = New-Object System.Drawing.Point(140, 18)
$textStart.Size = New-Object System.Drawing.Size(140, 23)
$textStart.Text = '1'
$form.Controls.Add($textStart)

$labelEnd = New-Object System.Windows.Forms.Label
$labelEnd.Text = 'End Frame'
$labelEnd.Location = New-Object System.Drawing.Point(20, 55)
$labelEnd.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($labelEnd)

$textEnd = New-Object System.Windows.Forms.TextBox
$textEnd.Location = New-Object System.Drawing.Point(140, 53)
$textEnd.Size = New-Object System.Drawing.Size(140, 23)
$textEnd.Text = [string]$totalFrames
$form.Controls.Add($textEnd)

$buttonOk = New-Object System.Windows.Forms.Button
$buttonOk.Text = 'OK'
$buttonOk.Location = New-Object System.Drawing.Point(124, 105)
$buttonOk.Size = New-Object System.Drawing.Size(75, 28)
$buttonOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($buttonOk)

$buttonCancel = New-Object System.Windows.Forms.Button
$buttonCancel.Text = 'Cancel'
$buttonCancel.Location = New-Object System.Drawing.Point(205, 105)
$buttonCancel.Size = New-Object System.Drawing.Size(75, 28)
$buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($buttonCancel)

$form.AcceptButton = $buttonOk
$form.CancelButton = $buttonCancel

$dialogResult = $form.ShowDialog()
if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK) {
    exit 0
}

$startFrame = 0
$endFrame = 0

if (-not [int]::TryParse($textStart.Text.Trim(), [ref]$startFrame)) {
    Show-ErrorAndExit 'Start Frame must be an integer.'
}
if (-not [int]::TryParse($textEnd.Text.Trim(), [ref]$endFrame)) {
    Show-ErrorAndExit 'End Frame must be an integer.'
}
if ($startFrame -lt 1) {
    Show-ErrorAndExit 'Start Frame must be greater than or equal to 1.'
}
if ($endFrame -lt 1) {
    Show-ErrorAndExit 'End Frame must be greater than or equal to 1.'
}
if ($endFrame -lt $startFrame) {
    Show-ErrorAndExit 'End Frame must be greater than or equal to Start Frame.'
}
if ($startFrame -gt $totalFrames) {
    Show-ErrorAndExit 'Start Frame exceeds the total number of frames.'
}
if ($endFrame -gt $totalFrames) {
    Show-ErrorAndExit 'End Frame exceeds the total number of frames.'
}

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
