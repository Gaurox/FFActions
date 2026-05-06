param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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
    if ($sourceExtension -notin @('.mp3', '.wav', '.flac', '.m4a', '.ogg')) {
        Show-Error 'Unsupported input format. Only .mp3, .wav, .flac, .m4a and .ogg are supported.'
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
        Show-Error (Get-ShortErrorText -StdErr $result.StdErr -FallbackMessage 'FFmpeg failed during audio reverse.')
        exit 1
    }

    exit 0
}
catch {
    $message = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($message)) { $message = 'Unknown reverse audio error.' }
    Show-Error $message
    exit 1
}
