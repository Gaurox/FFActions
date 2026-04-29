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

function Get-TransformConfig {
    param([string]$Key)

    switch ($Key) {
        'rotate90'  { return [PSCustomObject]@{ Filter = 'transpose=1'; Label = 'rotate90'; Text = 'Rotate 90° clockwise' } }
        'rotate180' { return [PSCustomObject]@{ Filter = 'transpose=1,transpose=1'; Label = 'rotate180'; Text = 'Rotate 180°' } }
        'rotate270' { return [PSCustomObject]@{ Filter = 'transpose=2'; Label = 'rotate270'; Text = 'Rotate 270° clockwise' } }
        'flip_h'    { return [PSCustomObject]@{ Filter = 'hflip'; Label = 'flipH'; Text = 'Mirror horizontal' } }
        'flip_v'    { return [PSCustomObject]@{ Filter = 'vflip'; Label = 'flipV'; Text = 'Mirror vertical' } }
        default     { throw 'Unknown video transform.' }
    }
}

function Show-RotateVideoWindow {
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFActions - Rotate / flip video'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(430, 305)
    $form.TopMost = $true

    $labelTitle = New-Object System.Windows.Forms.Label
    $labelTitle.Location = New-Object System.Drawing.Point(20, 16)
    $labelTitle.Size = New-Object System.Drawing.Size(380, 22)
    $labelTitle.Text = 'Choose the transform to apply'
    $form.Controls.Add($labelTitle)

    $group = New-Object System.Windows.Forms.GroupBox
    $group.Text = 'Transform'
    $group.Location = New-Object System.Drawing.Point(18, 46)
    $group.Size = New-Object System.Drawing.Size(392, 185)
    $form.Controls.Add($group)

    $options = @(
        @{ Key = 'rotate90';  Text = 'Rotate 90° clockwise';  X = 18;  Y = 28; Width = 180 },
        @{ Key = 'rotate180'; Text = 'Rotate 180°';           X = 18;  Y = 58; Width = 180 },
        @{ Key = 'rotate270'; Text = 'Rotate 270° clockwise'; X = 18;  Y = 88; Width = 180 },
        @{ Key = 'flip_h';    Text = 'Mirror horizontal';     X = 18;  Y = 128; Width = 170 },
        @{ Key = 'flip_v';    Text = 'Mirror vertical';       X = 205; Y = 128; Width = 160 }
    )

    $radioButtons = @()
    foreach ($item in $options) {
        $radio = New-Object System.Windows.Forms.RadioButton
        $radio.Text = $item.Text
        $radio.Tag = $item.Key
        $radio.Location = New-Object System.Drawing.Point($item.X, $item.Y)
        $radio.Size = New-Object System.Drawing.Size($item.Width, 24)
        if ($item.Key -eq 'rotate90') { $radio.Checked = $true }
        $group.Controls.Add($radio)
        $radioButtons += $radio
    }

    $labelNote = New-Object System.Windows.Forms.Label
    $labelNote.Location = New-Object System.Drawing.Point(20, 238)
    $labelNote.Size = New-Object System.Drawing.Size(390, 34)
    $labelNote.Text = 'The output video is created next to the original file. Audio is kept when possible.'
    $form.Controls.Add($labelNote)

    $buttonOK = New-Object System.Windows.Forms.Button
    $buttonOK.Text = 'OK'
    $buttonOK.Location = New-Object System.Drawing.Point(215, 272)
    $buttonOK.Size = New-Object System.Drawing.Size(90, 28)
    $buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($buttonOK)

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.Location = New-Object System.Drawing.Point(318, 272)
    $buttonCancel.Size = New-Object System.Drawing.Size(90, 28)
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($buttonCancel)

    $form.AcceptButton = $buttonOK
    $form.CancelButton = $buttonCancel

    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        $form.Dispose()
        return $null
    }

    $selected = $radioButtons | Where-Object { $_.Checked } | Select-Object -First 1
    if ($null -eq $selected) {
        $form.Dispose()
        Show-ErrorAndExit 'No transform selected.'
    }

    $payload = Get-TransformConfig -Key ([string]$selected.Tag)
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

$transform = Show-RotateVideoWindow
if ($null -eq $transform) {
    exit 0
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
