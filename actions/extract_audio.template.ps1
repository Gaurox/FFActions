param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


function Get-TargetFormatFromExeName {
    $exeName = [System.IO.Path]::GetFileNameWithoutExtension([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)

    switch ($exeName.ToLowerInvariant()) {
        'extract_audio_to_mp3'  { return '.mp3' }
        'extract_audio_to_wav'  { return '.wav' }
        'extract_audio_to_flac' { return '.flac' }
        'extract_audio_to_m4a'  { return '.m4a' }
        'extract_audio_to_ogg'  { return '.ogg' }
        default { throw 'Unknown extraction target. Expected extract_audio_to_mp3.exe, extract_audio_to_wav.exe, extract_audio_to_flac.exe, extract_audio_to_m4a.exe or extract_audio_to_ogg.exe.' }
    }
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

    $fullInputPath = [System.IO.Path]::GetFullPath($InputFile)
    if (-not (Test-Path -LiteralPath $fullInputPath)) {
        Show-Error "Input file not found:`r`n$fullInputPath"
        exit 1
    }

    $sourceExtension = [System.IO.Path]::GetExtension($fullInputPath).ToLowerInvariant()
    if ($sourceExtension -notin @('.mp4', '.mkv', '.avi', '.mov', '.webm', '.m4v')) {
        Show-Error 'Unsupported source format. Supported video formats: .mp4, .mkv, .avi, .mov, .webm, .m4v'
        exit 1
    }

    $targetExtension = Get-TargetFormatFromExeName
    $inputDir = Split-Path -Parent $fullInputPath
    $inputBase = [System.IO.Path]::GetFileNameWithoutExtension($fullInputPath)
    $outputPath = Join-Path $inputDir ($inputBase + '_audio' + $targetExtension)
    $outputPath = Get-UniqueOutputPath $outputPath

    $ffmpegPath = Get-ToolPath 'ffmpeg.exe'
    $ffprobePath = Get-ToolPath 'ffprobe.exe'

    if (-not (Test-Path -LiteralPath $ffmpegPath)) {
        Show-Error "ffmpeg.exe not found:`r`n$ffmpegPath"
        exit 1
    }

    if (-not (Test-Path -LiteralPath $ffprobePath)) {
        Show-Error "ffprobe.exe not found:`r`n$ffprobePath"
        exit 1
    }

    $videoInfo = Get-VideoInfo -FfprobePath $ffprobePath -FilePath $fullInputPath
    $encodingProfile = Get-EncodingProfile -TargetExtension $targetExtension

    $result = Invoke-WithEncodingPlan `
        -FfmpegPath $ffmpegPath `
        -EncodingPlan ([PSCustomObject]@{ Primary = $encodingProfile; Fallback = $null }) `
        -DurationSeconds $videoInfo.DurationSeconds `
        -Title 'Extract audio' `
        -PreparingText 'Preparing audio extraction...' `
        -OutputFile $outputPath `
        -ArgumentFactory {
            param($profile)
            New-FFmpegArguments -InputFile $fullInputPath -OutputFile $outputPath -EncodingProfile $profile
        }

    if ($result.Cancelled) {
        Remove-PartialOutput -Path $outputPath
        exit 0
    }

    if ($result.ExitCode -ne 0) {
        Remove-PartialOutput -Path $outputPath
        Show-Error (Get-ShortErrorText -StdErr $result.StdErr)
        exit 1
    }
}
catch {
    if ($outputPath) {
        Remove-PartialOutput -Path $outputPath
    }

    Show-Error $_.Exception.Message
    exit 1
}

exit 0
