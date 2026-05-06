param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function New-RemoveAudioArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile
    )

    $ffmpegArgs = @(
        '-hide_banner',
        '-loglevel', 'error',
        '-progress', 'pipe:1',
        '-nostats',
        '-y',
        '-i', $InputFile,
        '-map', '0:v:0?',
        '-c:v', 'copy',
        '-an',
        $OutputFile
    )

    return ,$ffmpegArgs
}

#__FFCOMMON_INJECT_HERE__

if ([string]::IsNullOrWhiteSpace($InputFile)) {
    Show-Error 'No input file received.'
    exit 1
}

if (-not (Test-Path -LiteralPath $InputFile)) {
    Show-Error "Input file not found.`n$InputFile"
    exit 1
}

$extension = [System.IO.Path]::GetExtension($InputFile).ToLowerInvariant()
if ($extension -notin @('.mp4', '.mkv', '.avi', '.mov', '.webm', '.m4v')) {
    Show-Error 'Unsupported file format. Supported: .mp4, .mkv, .avi, .mov, .webm, .m4v'
    exit 1
}

$ffmpegPath = Get-ToolPath -ToolName 'ffmpeg.exe'
$ffprobePath = Get-ToolPath -ToolName 'ffprobe.exe'

if (-not (Test-Path -LiteralPath $ffmpegPath)) {
    Show-Error "ffmpeg.exe not found.`n$ffmpegPath"
    exit 1
}

if (-not (Test-Path -LiteralPath $ffprobePath)) {
    Show-Error "ffprobe.exe not found.`n$ffprobePath"
    exit 1
}

try {
    $videoInfo = Get-VideoInfo -FfprobePath $ffprobePath -FilePath $InputFile
    $durationSeconds = [double]$videoInfo.DurationSeconds
}
catch {
    Show-Error $_.Exception.Message
    exit 1
}

$inputDir = Split-Path -Parent $InputFile
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
$outputExtension = [System.IO.Path]::GetExtension($InputFile)
$desiredOutput = Join-Path $inputDir ($baseName + '_noaudio' + $outputExtension)
$script:OutputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

$encodingPlan = [PSCustomObject]@{
    Primary  = [PSCustomObject]@{ ModeLabel = 'Stream copy' }
    Fallback = $null
}

$result = Invoke-WithEncodingPlan -FfmpegPath $ffmpegPath -EncodingPlan $encodingPlan -DurationSeconds $durationSeconds -Title 'Remove audio' -PreparingText 'Preparing audio removal...' -OutputFile $script:OutputFile -ArgumentFactory {
    param($profile)
    New-RemoveAudioArguments -InputFile $InputFile -OutputFile $script:OutputFile
}

if ($result.Cancelled) {
    Remove-PartialOutput -Path $script:OutputFile
    exit 0
}

if ($result.ExitCode -ne 0) {
    Remove-PartialOutput -Path $script:OutputFile
    $errorText = Get-ShortErrorText -StdErr $result.StdErr -FallbackMessage 'FFmpeg failed while removing audio.'
    Show-Error $errorText
    exit 1
}

exit 0
