param (
    [string]$inputFile
)

function Get-AppRoot {
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $exeDir = Split-Path -Parent $exePath
    return Split-Path -Parent $exeDir
}

function Show-ErrorAndExit {
    param([string]$Message)
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        "FFActions - Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit
}

function Get-DecimalString {
    param([double]$Value)
    return $Value.ToString("0.###", [System.Globalization.CultureInfo]::InvariantCulture)
}

function Quote-ProcessArgument {
    param([string]$Value)

    if ($null -eq $Value) {
        return '""'
    }

    if ($Value -eq "") {
        return '""'
    }

    if ($Value -notmatch '[\s"]') {
        return $Value
    }

    $escaped = $Value -replace '(\\*)"', '$1$1\"'
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

    return [PSCustomObject]@{
        ExitCode = $process.ExitCode
        StdOut   = $stdOut
        StdErr   = $stdErr
    }
}

function Convert-FFmpegTimeToSeconds {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $trimmed = $Value.Trim()

    if ($trimmed -match '^(\d+):(\d+):(\d+(?:[\.,]\d+)?)$') {
        $hours = [double]::Parse($matches[1], [System.Globalization.CultureInfo]::InvariantCulture)
        $minutes = [double]::Parse($matches[2], [System.Globalization.CultureInfo]::InvariantCulture)
        $seconds = [double]::Parse($matches[3].Replace(',', '.'), [System.Globalization.CultureInfo]::InvariantCulture)
        return ($hours * 3600.0) + ($minutes * 60.0) + $seconds
    }

    return $null
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

    $duration = [double]::Parse($durationText, [System.Globalization.CultureInfo]::InvariantCulture)
    if ($duration -le 0) {
        throw 'Invalid media duration.'
    }

    return $duration
}

#__FFCOMMON_INJECT_HERE__

if ([string]::IsNullOrWhiteSpace($inputFile)) {
    Show-ErrorAndExit "No input file received."
}

if (-not (Test-Path -LiteralPath $inputFile)) {
    Show-ErrorAndExit "Input file not found.`n$inputFile"
}

$extension = [System.IO.Path]::GetExtension($inputFile).ToLowerInvariant()
if ($extension -notin @('.mp4', '.mkv', '.avi', '.mov', '.webm', '.m4v')) {
    Show-ErrorAndExit 'Unsupported input format. Only .mp4, .mkv, .avi, .mov, .webm and .m4v are supported.'
}

$appRoot = Get-AppRoot
$ffmpeg = Join-Path $appRoot "tools\ffmpeg\ffmpeg.exe"
$ffprobe = Join-Path $appRoot "tools\ffmpeg\ffprobe.exe"

if (-not (Test-Path -LiteralPath $ffmpeg)) {
    Show-ErrorAndExit "ffmpeg.exe not found.`n$ffmpeg"
}

if (-not (Test-Path -LiteralPath $ffprobe)) {
    Show-ErrorAndExit "ffprobe.exe not found.`n$ffprobe"
}

try {
    $probeResult = Invoke-HiddenProcess -FilePath $ffprobe -Arguments @(
        '-v', 'error',
        '-select_streams', 'v:0',
        '-show_entries', 'stream=r_frame_rate',
        '-of', 'default=nokey=1:noprint_wrappers=1',
        $inputFile
    )

    if ($probeResult.ExitCode -ne 0) {
        $probeErr = $probeResult.StdErr.Trim()
        if ([string]::IsNullOrWhiteSpace($probeErr)) {
            $probeErr = 'ffprobe failed.'
        }
        throw $probeErr
    }

    $fpsRaw = $probeResult.StdOut.Trim()

    if ([string]::IsNullOrWhiteSpace($fpsRaw)) {
        throw 'Unable to detect source FPS.'
    }

    if ($fpsRaw -match '^\s*(\d+)\s*/\s*(\d+)\s*$') {
        $num = [double]$matches[1]
        $den = [double]$matches[2]

        if ($den -eq 0) {
            throw 'Invalid FPS denominator.'
        }

        $sourceFps = $num / $den
    }
    else {
        $sourceFps = [double]::Parse($fpsRaw, [System.Globalization.CultureInfo]::InvariantCulture)
    }

    if ($sourceFps -le 0) {
        throw 'Invalid source FPS.'
    }
}
catch {
    Show-ErrorAndExit "Unable to detect source FPS.`n$($_.Exception.Message)"
}

$sourceFpsText = Get-DecimalString $sourceFps

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Interpolate'
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ClientSize = New-Object System.Drawing.Size(360, 160)
$form.TopMost = $true

$btnX2 = New-Object System.Windows.Forms.Button
$btnX2.Text = 'x2'
$btnX2.Size = New-Object System.Drawing.Size(80, 30)
$btnX2.Location = New-Object System.Drawing.Point(20, 20)

$btnX3 = New-Object System.Windows.Forms.Button
$btnX3.Text = 'x3'
$btnX3.Size = New-Object System.Drawing.Size(80, 30)
$btnX3.Location = New-Object System.Drawing.Point(110, 20)

$btnX4 = New-Object System.Windows.Forms.Button
$btnX4.Text = 'x4'
$btnX4.Size = New-Object System.Drawing.Size(80, 30)
$btnX4.Location = New-Object System.Drawing.Point(200, 20)

$lblTarget = New-Object System.Windows.Forms.Label
$lblTarget.Text = 'Target FPS'
$lblTarget.AutoSize = $true
$lblTarget.Location = New-Object System.Drawing.Point(20, 68)

$txtFps = New-Object System.Windows.Forms.TextBox
$txtFps.Size = New-Object System.Drawing.Size(120, 23)
$txtFps.Location = New-Object System.Drawing.Point(110, 64)

$lblSource = New-Object System.Windows.Forms.Label
$lblSource.Text = "Source FPS: $sourceFpsText"
$lblSource.AutoSize = $true
$lblSource.Location = New-Object System.Drawing.Point(245, 68)

$btnOk = New-Object System.Windows.Forms.Button
$btnOk.Text = 'OK'
$btnOk.Size = New-Object System.Drawing.Size(90, 30)
$btnOk.Location = New-Object System.Drawing.Point(90, 110)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = 'Cancel'
$btnCancel.Size = New-Object System.Drawing.Size(90, 30)
$btnCancel.Location = New-Object System.Drawing.Point(190, 110)
$btnCancel.Add_Click({
    $form.Close()
})

$btnX2.Add_Click({
    $txtFps.Text = Get-DecimalString ($sourceFps * 2)
})

$btnX3.Add_Click({
    $txtFps.Text = Get-DecimalString ($sourceFps * 3)
})

$btnX4.Add_Click({
    $txtFps.Text = Get-DecimalString ($sourceFps * 4)
})

$btnOk.Add_Click({
    $rawText = $txtFps.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($rawText)) {
        [System.Windows.Forms.MessageBox]::Show(
            'Please enter a target FPS.',
            'FFActions',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }

    $normalizedText = $rawText.Replace(',', '.')

    try {
        $targetFpsValue = [double]::Parse($normalizedText, [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            'Invalid FPS value.',
            'FFActions',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }

    if ($targetFpsValue -le 0) {
        [System.Windows.Forms.MessageBox]::Show(
            'FPS must be greater than 0.',
            'FFActions',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }

    if ($targetFpsValue -lt $sourceFps) {
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "The target FPS is lower than the source FPS.`nThis will reduce the frame rate instead of interpolating.`n`nContinue?",
            'Confirmation',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) {
            return
        }
    }

    $form.Tag = $targetFpsValue
    $form.Close()
})

$form.Controls.Add($btnX2)
$form.Controls.Add($btnX3)
$form.Controls.Add($btnX4)
$form.Controls.Add($lblTarget)
$form.Controls.Add($txtFps)
$form.Controls.Add($lblSource)
$form.Controls.Add($btnOk)
$form.Controls.Add($btnCancel)

[void]$form.ShowDialog()

if ($null -eq $form.Tag) {
    exit
}

$targetFps = [double]$form.Tag
$targetFpsText = Get-DecimalString $targetFps

$inputDir = Split-Path -Parent $inputFile
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($inputFile)
$outputFile = Join-Path $inputDir ($baseName + '_interp_' + $targetFpsText + 'fps' + $extension)
$index = 1
while (Test-Path -LiteralPath $outputFile) {
    $outputFile = Join-Path $inputDir ($baseName + '_interp_' + $targetFpsText + 'fps_' + $index + $extension)
    $index++
}

try {
    $durationSeconds = Get-MediaDurationSeconds -FfprobePath $ffprobe -InputPath $inputFile
}
catch {
    Show-ErrorAndExit "Unable to detect media duration.`n$($_.Exception.Message)"
}

$progressUi = New-ProgressForm -Title 'Interpolation in progress' -InitialStatus 'Preparing interpolation...' -InitialModeLabel 'CPU'
$progressUi.Form.Show()
[System.Windows.Forms.Application]::DoEvents()

$ffmpegResult = $null

try {
    $ffmpegArgs = switch ($extension) {
        '.avi' {
            @(
                '-hide_banner',
                '-loglevel', 'error',
                '-progress', 'pipe:1',
                '-nostats',
                '-y',
                '-i', $inputFile,
                '-vf', "minterpolate=fps=$targetFpsText",
                '-c:v', 'mpeg4',
                '-q:v', '2',
                '-c:a', 'copy',
                $outputFile
            )
        }
        '.webm' {
            @(
                '-hide_banner',
                '-loglevel', 'error',
                '-progress', 'pipe:1',
                '-nostats',
                '-y',
                '-i', $inputFile,
                '-vf', "minterpolate=fps=$targetFpsText",
                '-c:v', 'libvpx-vp9',
                '-crf', '31',
                '-b:v', '0',
                '-deadline', 'good',
                '-cpu-used', '2',
                '-row-mt', '1',
                '-c:a', 'copy',
                $outputFile
            )
        }
        default {
            @(
                '-hide_banner',
                '-loglevel', 'error',
                '-progress', 'pipe:1',
                '-nostats',
                '-y',
                '-i', $inputFile,
                '-vf', "minterpolate=fps=$targetFpsText",
                '-c:v', 'libx264',
                '-preset', 'medium',
                '-crf', '18',
                '-pix_fmt', 'yuv420p',
                '-c:a', 'copy',
                $outputFile
            )
        }
    }

    $ffmpegResult = Invoke-FFmpegWithProgress -FfmpegPath $ffmpeg -Arguments $ffmpegArgs -DurationSeconds $durationSeconds -OutputFile $outputFile -StatusText 'Interpolating...' -ModeLabel 'CPU' -ProgressContext $progressUi
}
catch {
    if ($progressUi -and $progressUi.Form -and -not $progressUi.Form.IsDisposed) {
        $progressUi.Form.Close()
    }

    $message = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = 'Unknown interpolation error.'
    }

    Show-ErrorAndExit "Interpolation failed.`n$message"
}

if ($progressUi -and $progressUi.Form -and -not $progressUi.Form.IsDisposed) {
    $progressUi.Form.Close()
}

if ($ffmpegResult.Cancelled) {
    if (Test-Path -LiteralPath $outputFile) {
        try { Remove-Item -LiteralPath $outputFile -Force -ErrorAction Stop } catch {}
    }
    exit
}

if ($ffmpegResult.ExitCode -ne 0) {
    $errorText = $ffmpegResult.StdErr.Trim()
    if ([string]::IsNullOrWhiteSpace($errorText)) {
        $errorText = 'Unknown ffmpeg error.'
    }

    Show-ErrorAndExit "Interpolation failed.`n$errorText"
}
