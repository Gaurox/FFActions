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

function Get-AudioInfo {
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
        throw 'ffprobe failed to read audio information.'
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
        throw 'Unable to determine audio duration.'
    }

    $durationSeconds = [double]::Parse($durationText.Replace(',', '.'), [System.Globalization.CultureInfo]::InvariantCulture)
    if ($durationSeconds -le 0) {
        throw 'Invalid audio duration.'
    }

    return [PSCustomObject]@{
        DurationSeconds = $durationSeconds
    }
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

function Get-EncodingProfile([string]$TargetExtension) {
    switch ($TargetExtension.ToLowerInvariant()) {
        '.mp3' {
            return [PSCustomObject]@{
                ModeLabel = 'Audio'
                Codec     = 'libmp3lame'
                Args      = @('-b:a', '320k')
            }
        }
        '.wav' {
            return [PSCustomObject]@{
                ModeLabel = 'Audio'
                Codec     = 'pcm_s16le'
                Args      = @()
            }
        }
        '.flac' {
            return [PSCustomObject]@{
                ModeLabel = 'Audio'
                Codec     = 'flac'
                Args      = @('-compression_level', '5')
            }
        }
        '.m4a' {
            return [PSCustomObject]@{
                ModeLabel = 'Audio'
                Codec     = 'aac'
                Args      = @('-b:a', '256k')
            }
        }
        '.ogg' {
            return [PSCustomObject]@{
                ModeLabel = 'Audio'
                Codec     = 'libvorbis'
                Args      = @('-q:a', '6')
            }
        }
        default {
            throw 'Unsupported target format. Only .mp3, .wav, .flac, .m4a and .ogg are supported.'
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
        '-vn',
        '-sn',
        '-dn',
        '-map', '0:a:0?',
        '-af', 'areverse',
        '-c:a', $EncodingProfile.Codec
    )

    $ffmpegArgs += $EncodingProfile.Args
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

    return 'FFmpeg failed during audio reverse.'
}

#__FFCOMMON_INJECT_HERE__

try {
    if ([string]::IsNullOrWhiteSpace($InputFile)) {
        Show-ErrorAndExit 'Input file is missing.'
    }

    if (-not (Test-Path -LiteralPath $InputFile)) {
        Show-ErrorAndExit 'Input file not found.'
    }

    $sourceExtension = [System.IO.Path]::GetExtension($InputFile).ToLowerInvariant()
    if ($sourceExtension -notin @('.mp3', '.wav', '.flac', '.m4a', '.ogg')) {
        Show-ErrorAndExit 'Unsupported input format. Only .mp3, .wav, .flac, .m4a and .ogg are supported.'
    }

    $ffmpeg = Get-ToolPath 'ffmpeg.exe'
    $ffprobe = Get-ToolPath 'ffprobe.exe'

    if (-not (Test-Path -LiteralPath $ffmpeg)) {
        Show-ErrorAndExit 'ffmpeg.exe not found.'
    }

    if (-not (Test-Path -LiteralPath $ffprobe)) {
        Show-ErrorAndExit 'ffprobe.exe not found.'
    }

    $encodingProfile = Get-EncodingProfile -TargetExtension $sourceExtension
    $audioInfo = Get-AudioInfo -FfprobePath $ffprobe -FilePath $InputFile
    $totalDuration = [double]$audioInfo.DurationSeconds

    $inputDir = Split-Path -Parent $InputFile
    $inputBase = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $desiredOutput = Join-Path $inputDir ("{0}_reverse{1}" -f $inputBase, $sourceExtension)
    $script:OutputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

    $encodingPlan = [PSCustomObject]@{
        Primary  = $encodingProfile
        Fallback = $null
    }

    $result = Invoke-WithEncodingPlan -FfmpegPath $ffmpeg -EncodingPlan $encodingPlan -DurationSeconds $totalDuration -Title 'Reverse audio' -PreparingText 'Preparing audio reverse...' -OutputFile $script:OutputFile -ArgumentFactory {
        param($profile)
        New-FFmpegArguments -InputFile $InputFile -OutputFile $script:OutputFile -EncodingProfile $profile
    }

    if ($result.Cancelled) {
        Remove-PartialOutput -Path $script:OutputFile
        exit 0
    }

    if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $script:OutputFile)) {
        Remove-PartialOutput -Path $script:OutputFile
        Show-ErrorAndExit (Get-ShortErrorText -StdErr $result.StdErr)
    }

    exit 0
}
catch {
    $message = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($message)) { $message = 'Unknown reverse audio error.' }
    Show-ErrorAndExit $message
}
