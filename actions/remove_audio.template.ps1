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

    $index = 1
    while ($true) {
        $candidate = Join-Path $dir ("{0}_{1}{2}" -f $base, $index, $ext)
        if (-not (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
        $index++
    }
}

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

function Get-ShortErrorText {
    param([string]$StdErr)

    if (-not [string]::IsNullOrWhiteSpace($StdErr)) {
        $firstLines = ($StdErr -split "`r?`n" | Where-Object { $_.Trim() -ne '' } | Select-Object -First 12) -join "`r`n"
        if (-not [string]::IsNullOrWhiteSpace($firstLines)) {
            return $firstLines
        }
    }

    return 'FFmpeg failed while removing audio.'
}

function Remove-PartialOutput {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (Test-Path -LiteralPath $Path) {
        try { Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue } catch {}
    }
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
    $errorText = Get-ShortErrorText -StdErr $result.StdErr
    Show-ErrorAndExit $errorText
}

exit 0
