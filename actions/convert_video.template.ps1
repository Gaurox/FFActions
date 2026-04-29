param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-Error([string]$Message) {
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        "FFActions - Error",
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
    if ($Value -eq "") { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }

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

    throw "Unable to create a unique output filename."
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
        if (-not [string]::IsNullOrWhiteSpace($probeResult.StdErr)) {
            throw $probeResult.StdErr.Trim()
        }
        throw 'ffprobe failed to read video information.'
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

    if (-not $durationText) {
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

function Get-TargetFormatFromExeName {
    $exeName = [System.IO.Path]::GetFileNameWithoutExtension([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)

    switch ($exeName.ToLowerInvariant()) {
        'convert_to_mp4' { return '.mp4' }
        'convert_to_mkv' { return '.mkv' }
        'convert_to_avi' { return '.avi' }
        default { throw 'Unknown conversion target. Expected convert_to_mp4.exe, convert_to_mkv.exe or convert_to_avi.exe.' }
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
        default {
            throw 'Unsupported target format. Only .mp4, .mkv and .avi are supported.'
        }
    }
}

function New-FFmpegArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
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
        '-c:v', $EncodingProfile.VideoCodec
    )

    $ffmpegArgs += $EncodingProfile.VideoArgs
    $ffmpegArgs += @('-c:a', $EncodingProfile.AudioCodec)
    $ffmpegArgs += $EncodingProfile.AudioArgs
    $ffmpegArgs += @($OutputFile)

    return ,$ffmpegArgs
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

    return 'FFmpeg failed during conversion.'
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
    if ($sourceExtension -notin @('.mp4', '.mkv', '.avi')) {
        Show-Error 'Unsupported input format. Only .mp4, .mkv and .avi are supported.'
        exit 1
    }

    $targetExtension = Get-TargetFormatFromExeName
    if ($targetExtension -eq $sourceExtension) {
        Show-Error 'Source and target formats must be different.'
        exit 1
    }

    $ffmpeg = Get-ToolPath 'ffmpeg.exe'
    $ffprobe = Get-ToolPath 'ffprobe.exe'

    if (-not (Test-Path -LiteralPath $ffmpeg)) {
        Show-Error 'ffmpeg.exe not found.'
        exit 1
    }

    if (-not (Test-Path -LiteralPath $ffprobe)) {
        Show-Error 'ffprobe.exe not found.'
        exit 1
    }

    $nvencAvailable = Test-NvencAvailable -FfmpegPath $ffmpeg
    $encodingPlan = Get-EncodingPlan -TargetExtension $targetExtension -NvencAvailable $nvencAvailable
    $videoInfo = Get-VideoInfo -FfprobePath $ffprobe -FilePath $InputFile
    $totalDuration = [double]$videoInfo.DurationSeconds

    $inputDir = Split-Path -Parent $InputFile
    $inputBase = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $targetLabel = $targetExtension.TrimStart('.')
    $desiredOutput = Join-Path $inputDir ("{0}_convert_{1}{2}" -f $inputBase, $targetLabel, $targetExtension)
    $script:OutputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

    $result = Invoke-WithEncodingPlan -FfmpegPath $ffmpeg -EncodingPlan $encodingPlan -DurationSeconds $totalDuration -Title 'Conversion in progress' -PreparingText "Preparing conversion to $targetLabel..." -FallbackPreparingText 'GPU unavailable. Retrying in CPU mode...' -OutputFile $script:OutputFile -ArgumentFactory {
        param($profile)
        New-FFmpegArguments -InputFile $InputFile -OutputFile $script:OutputFile -EncodingProfile $profile
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
    $message = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($message)) { $message = 'Unknown conversion error.' }
    Show-Error $message
    exit 1
}
