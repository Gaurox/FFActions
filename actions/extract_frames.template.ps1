param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function New-FFmpegArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputPattern
    )

    $ffmpegArgs = @(
        '-hide_banner',
        '-loglevel', 'error',
        '-progress', 'pipe:1',
        '-nostats',
        '-y',
        '-i', $InputFile,
        '-map', '0:v:0?',
        '-an',
        '-sn',
        '-dn',
        '-vsync', '0',
        '-c:v', 'png',
        '-compression_level', '6',
        $OutputPattern
    )

    return ,$ffmpegArgs
}

function Get-UniqueOutputDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$DesiredPath
    )

    if (-not (Test-Path -LiteralPath $DesiredPath)) {
        return $DesiredPath
    }

    for ($i = 1; $i -le 999; $i++) {
        $candidate = '{0}_{1:D3}' -f $DesiredPath, $i
        if (-not (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    throw 'Unable to create a unique output folder name.'
}

function Remove-DirectoryIfPresent {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    if (Test-Path -LiteralPath $Path) {
        try {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
        }
        catch {}
    }
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

    $inputDir = Split-Path -Parent $fullInputPath
    $inputBase = [System.IO.Path]::GetFileNameWithoutExtension($fullInputPath)
    $desiredOutputDir = Join-Path $inputDir ($inputBase + '_frames')
    $outputDir = Get-UniqueOutputDirectory -DesiredPath $desiredOutputDir

    [System.IO.Directory]::CreateDirectory($outputDir) | Out-Null

    $outputPattern = Join-Path $outputDir ($inputBase + '_%06d.png')

    $result = Invoke-FFmpegWithProgress `
        -FfmpegPath $ffmpegPath `
        -Arguments (New-FFmpegArguments -InputFile $fullInputPath -OutputPattern $outputPattern) `
        -DurationSeconds ([double]$videoInfo.DurationSeconds) `
        -OutputFile $outputPattern `
        -Title 'Extract frames' `
        -StatusText 'Extracting PNG frames...' `
        -ModeLabel 'CPU'

    if ($result.Cancelled) {
        Remove-DirectoryIfPresent -Path $outputDir
        exit 0
    }

    $pngFiles = @(Get-ChildItem -LiteralPath $outputDir -Filter '*.png' -File -ErrorAction SilentlyContinue)
    if ($result.ExitCode -ne 0 -or $pngFiles.Count -eq 0) {
        Remove-DirectoryIfPresent -Path $outputDir
        Show-Error (Get-ShortErrorText -StdErr $result.StdErr -FallbackMessage 'FFmpeg failed during frame extraction.')
        exit 1
    }
}
catch {
    if ($outputDir) {
        Remove-DirectoryIfPresent -Path $outputDir
    }

    Show-Error $_.Exception.Message
    exit 1
}

exit 0
