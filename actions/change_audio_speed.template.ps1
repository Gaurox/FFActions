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
    param([object[]]$Arguments)

    return (($Arguments | ForEach-Object {
        Quote-ProcessArgument ([string]$_)
    }) -join ' ')
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

function Remove-FileIfExists {
    param([string]$Path)
    if (-not [string]::IsNullOrWhiteSpace($Path) -and (Test-Path -LiteralPath $Path)) {
        try { Remove-Item -LiteralPath $Path -Force -ErrorAction Stop } catch {}
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

function Parse-TimeInput {
    param([Parameter(Mandatory = $true)][string]$Text)

    $value = $Text.Trim()
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw 'Time value is required.'
    }

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $seconds = 0.0

    if ($value -match '^\d+(?:[\.,]\d+)?$') {
        $normalized = $value.Replace(',', '.')
        if (-not [double]::TryParse($normalized, [System.Globalization.NumberStyles]::Float, $culture, [ref]$seconds)) {
            throw 'Invalid time value.'
        }
        return $seconds
    }

    $m = [regex]::Match($value, '^(?<h>\d{1,2}):(?<m>\d{1,2}):(?<s>\d{1,2}(?:[\.,]\d+)?)$')
    if ($m.Success) {
        $hours = [double]::Parse($m.Groups['h'].Value, $culture)
        $mins  = [double]::Parse($m.Groups['m'].Value, $culture)
        $secs  = [double]::Parse($m.Groups['s'].Value.Replace(',', '.'), $culture)
        return ($hours * 3600.0) + ($mins * 60.0) + $secs
    }

    $m2 = [regex]::Match($value, '^(?<m>\d{1,2}):(?<s>\d{1,2}(?:[\.,]\d+)?)$')
    if ($m2.Success) {
        $mins  = [double]::Parse($m2.Groups['m'].Value, $culture)
        $secs  = [double]::Parse($m2.Groups['s'].Value.Replace(',', '.'), $culture)
        return ($mins * 60.0) + $secs
    }

    throw 'Invalid time format. Use seconds or hh:mm:ss.'
}

function Format-SecondsForDisplay {
    param([double]$Seconds)

    if ($Seconds -lt 0) { $Seconds = 0 }
    $totalMs = [int][Math]::Round($Seconds * 1000.0)
    $hours = [int][Math]::Floor($totalMs / 3600000)
    $minutes = [int][Math]::Floor(($totalMs % 3600000) / 60000)
    $secs = [int][Math]::Floor(($totalMs % 60000) / 1000)
    $ms = $totalMs % 1000
    return ('{0:00}:{1:00}:{2:00}.{3:000}' -f $hours, $minutes, $secs, $ms)
}

function Format-PercentValue {
    param([double]$Value)
    return ([Math]::Round($Value, 2)).ToString('0.##', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-AudioInfo {
    param(
        [Parameter(Mandatory = $true)][string]$FfprobePath,
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    $probeResult = Invoke-HiddenProcess -FilePath $FfprobePath -Arguments @(
        '-v', 'error',
        '-select_streams', 'a:0',
        '-show_entries', 'stream=sample_rate:format=duration',
        '-of', 'default=nokey=0:noprint_wrappers=1',
        $FilePath
    )

    if ($probeResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($probeResult.StdOut)) {
        $probeErr = $probeResult.StdErr.Trim()
        if ([string]::IsNullOrWhiteSpace($probeErr)) {
            $probeErr = 'ffprobe failed to read audio information.'
        }
        throw $probeErr
    }

    $map = @{}
    foreach ($line in ($probeResult.StdOut -split "`r?`n")) {
        if ($line -match '^(?<k>[^=]+)=(?<v>.*)$') {
            $map[$matches['k']] = $matches['v']
        }
    }

    if (-not $map.ContainsKey('duration')) {
        throw 'Unable to determine audio duration.'
    }

    $duration = [double]::Parse($map['duration'].Replace(',', '.'), [System.Globalization.CultureInfo]::InvariantCulture)
    if ($duration -le 0) {
        throw 'Invalid audio duration.'
    }

    $sampleRate = 44100
    if ($map.ContainsKey('sample_rate') -and $map['sample_rate'] -match '^\d+$') {
        $sampleRate = [int]$map['sample_rate']
    }

    return [PSCustomObject]@{
        DurationSeconds = $duration
        SampleRate      = $sampleRate
    }
}

function Build-AtempoChain {
    param([double]$Factor)

    if ($Factor -le 0) {
        throw 'Invalid speed factor.'
    }

    $parts = New-Object System.Collections.Generic.List[string]
    $remaining = $Factor
    $culture = [System.Globalization.CultureInfo]::InvariantCulture

    while ($remaining -gt 2.0) {
        $parts.Add('atempo=2.0')
        $remaining = $remaining / 2.0
    }

    while ($remaining -lt 0.5) {
        $parts.Add('atempo=0.5')
        $remaining = $remaining / 0.5
    }

    $parts.Add('atempo=' + $remaining.ToString('0.######', $culture))
    return ($parts -join ',')
}

function Get-FinalAudioArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)][string]$Extension,
        [Parameter(Mandatory = $true)][double]$SpeedFactor,
        [Parameter(Mandatory = $true)][bool]$KeepPitch,
        [Parameter(Mandatory = $true)][int]$SampleRate
    )

    $filter = if ($KeepPitch) {
        Build-AtempoChain -Factor $SpeedFactor
    }
    else {
        $rate = [Math]::Max(1000, [int][Math]::Round($SampleRate * $SpeedFactor))
        'asetrate=' + $rate + ',aresample=' + $SampleRate
    }

    $args = @(
        '-y',
        '-hide_banner',
        '-progress', '-',
        '-nostats',
        '-i', $InputFile,
        '-vn',
        '-filter:a', $filter
    )

    switch ($Extension.ToLowerInvariant()) {
        '.wav' {
            $args += @('-c:a', 'pcm_s16le')
        }
        '.mp3' {
            $args += @('-c:a', 'libmp3lame', '-b:a', '320k')
        }
        '.flac' {
            $args += @('-c:a', 'flac', '-compression_level', '5')
        }
        '.m4a' {
            $args += @('-c:a', 'aac', '-b:a', '256k')
        }
        '.ogg' {
            $args += @('-c:a', 'libvorbis', '-q:a', '6')
        }
        default {
            throw 'Unsupported audio format. Only .wav, .mp3, .flac, .m4a and .ogg are supported.'
        }
    }

    $args += @($OutputFile)
    return ,$args
}

function Show-SpeedWindow {
    param(
        [Parameter(Mandatory = $true)][double]$OriginalDurationSeconds
    )

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $script:syncing = $false

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFActions - Change audio speed'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(500, 320)
    $form.TopMost = $true

    $labelOriginal = New-Object System.Windows.Forms.Label
    $labelOriginal.Location = New-Object System.Drawing.Point(20, 18)
    $labelOriginal.Size = New-Object System.Drawing.Size(450, 22)
    $labelOriginal.Text = 'Original duration: ' + (Format-SecondsForDisplay -Seconds $OriginalDurationSeconds)
    $form.Controls.Add($labelOriginal)

    $groupMode = New-Object System.Windows.Forms.GroupBox
    $groupMode.Text = 'Mode'
    $groupMode.Location = New-Object System.Drawing.Point(18, 50)
    $groupMode.Size = New-Object System.Drawing.Size(464, 122)
    $form.Controls.Add($groupMode)

    $radioPercent = New-Object System.Windows.Forms.RadioButton
    $radioPercent.Text = 'Speed (%)'
    $radioPercent.Location = New-Object System.Drawing.Point(18, 28)
    $radioPercent.Size = New-Object System.Drawing.Size(110, 24)
    $radioPercent.Checked = $true
    $groupMode.Controls.Add($radioPercent)

    $textPercent = New-Object System.Windows.Forms.TextBox
    $textPercent.Location = New-Object System.Drawing.Point(150, 28)
    $textPercent.Size = New-Object System.Drawing.Size(90, 23)
    $textPercent.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Right
    $groupMode.Controls.Add($textPercent)

    $labelPercent = New-Object System.Windows.Forms.Label
    $labelPercent.Text = '%'
    $labelPercent.Location = New-Object System.Drawing.Point(248, 31)
    $labelPercent.Size = New-Object System.Drawing.Size(18, 20)
    $groupMode.Controls.Add($labelPercent)

    $radioDuration = New-Object System.Windows.Forms.RadioButton
    $radioDuration.Text = 'Target duration'
    $radioDuration.Location = New-Object System.Drawing.Point(18, 63)
    $radioDuration.Size = New-Object System.Drawing.Size(120, 24)
    $groupMode.Controls.Add($radioDuration)

    $textDuration = New-Object System.Windows.Forms.TextBox
    $textDuration.Location = New-Object System.Drawing.Point(150, 63)
    $textDuration.Size = New-Object System.Drawing.Size(130, 23)
    $groupMode.Controls.Add($textDuration)

    $labelDurationHint = New-Object System.Windows.Forms.Label
    $labelDurationHint.Text = 'sec or hh:mm:ss'
    $labelDurationHint.Location = New-Object System.Drawing.Point(288, 66)
    $labelDurationHint.Size = New-Object System.Drawing.Size(140, 20)
    $groupMode.Controls.Add($labelDurationHint)

    $presetValues = @(50, 75, 100, 125, 150, 200)
    $presetWidth = 62
    $presetStartX = 18
    for ($i = 0; $i -lt $presetValues.Count; $i++) {
        $value = [int]$presetValues[$i]
        $button = New-Object System.Windows.Forms.Button
        $button.Text = "$value%"
        $button.Tag = $value
        $button.Size = New-Object System.Drawing.Size($presetWidth, 26)
        $button.Location = New-Object System.Drawing.Point(($presetStartX + ($i * 72)), 92)
        $button.Add_Click({
            param($sender, $eventArgs)
            $radioPercent.Checked = $true
            $textPercent.Text = [string]$sender.Tag
        })
        $groupMode.Controls.Add($button)
    }

    $groupPitch = New-Object System.Windows.Forms.GroupBox
    $groupPitch.Text = 'Pitch'
    $groupPitch.Location = New-Object System.Drawing.Point(18, 182)
    $groupPitch.Size = New-Object System.Drawing.Size(464, 55)
    $form.Controls.Add($groupPitch)

    $checkKeepPitch = New-Object System.Windows.Forms.CheckBox
    $checkKeepPitch.Text = 'Keep original pitch'
    $checkKeepPitch.Checked = $true
    $checkKeepPitch.Location = New-Object System.Drawing.Point(18, 22)
    $checkKeepPitch.Size = New-Object System.Drawing.Size(180, 24)
    $groupPitch.Controls.Add($checkKeepPitch)

    $labelResult = New-Object System.Windows.Forms.Label
    $labelResult.Location = New-Object System.Drawing.Point(20, 248)
    $labelResult.Size = New-Object System.Drawing.Size(450, 20)
    $form.Controls.Add($labelResult)

    $buttonOK = New-Object System.Windows.Forms.Button
    $buttonOK.Text = 'OK'
    $buttonOK.Location = New-Object System.Drawing.Point(286, 278)
    $buttonOK.Size = New-Object System.Drawing.Size(90, 28)
    $buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($buttonOK)

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.Location = New-Object System.Drawing.Point(388, 278)
    $buttonCancel.Size = New-Object System.Drawing.Size(90, 28)
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($buttonCancel)

    $form.AcceptButton = $buttonOK
    $form.CancelButton = $buttonCancel

    function Update-UiState {
        $textPercent.Enabled = $radioPercent.Checked
        $textDuration.Enabled = $radioDuration.Checked
    }

    function Update-ResultLabel {
        if ($script:syncing) { return }
        try {
            $speedFactor = $null
            $targetDuration = $null

            if ($radioPercent.Checked) {
                $percentText = $textPercent.Text.Trim().Replace(',', '.')
                $percent = 0.0
                if (-not [double]::TryParse($percentText, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$percent) -or $percent -le 0) {
                    $labelResult.Text = 'Enter a speed percentage greater than 0.'
                    return
                }
                $speedFactor = $percent / 100.0
                $targetDuration = $OriginalDurationSeconds / $speedFactor

                $script:syncing = $true
                $textDuration.Text = Format-SecondsForDisplay -Seconds $targetDuration
                $script:syncing = $false
            }
            else {
                $targetDuration = Parse-TimeInput -Text $textDuration.Text
                if ($targetDuration -le 0) {
                    $labelResult.Text = 'Target duration must be greater than 0.'
                    return
                }
                $speedFactor = $OriginalDurationSeconds / $targetDuration

                $script:syncing = $true
                $textPercent.Text = Format-PercentValue ($speedFactor * 100.0)
                $script:syncing = $false
            }

            if ($speedFactor -le 0) {
                $labelResult.Text = 'Invalid speed value.'
                return
            }

            $labelResult.Text = 'New duration: ' + (Format-SecondsForDisplay -Seconds $targetDuration) + '    Speed factor: x' + $speedFactor.ToString('0.###', [System.Globalization.CultureInfo]::InvariantCulture)
        }
        catch {
            $labelResult.Text = $_.Exception.Message
        }
    }

    $radioPercent.Add_CheckedChanged({
        Update-UiState
        Update-ResultLabel
    })

    $radioDuration.Add_CheckedChanged({
        Update-UiState
        Update-ResultLabel
    })

    $textPercent.Add_TextChanged({
        if (-not $radioPercent.Checked) { return }
        Update-ResultLabel
    })

    $textDuration.Add_TextChanged({
        if (-not $radioDuration.Checked) { return }
        Update-ResultLabel
    })

    $textPercent.Text = '100'
    Update-UiState
    Update-ResultLabel

    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        $form.Dispose()
        return $null
    }

    try {
        $speedFactor = 1.0
        $targetDuration = $OriginalDurationSeconds

        if ($radioPercent.Checked) {
            $percent = [double]::Parse($textPercent.Text.Trim().Replace(',', '.'), [System.Globalization.CultureInfo]::InvariantCulture)
            if ($percent -le 0) { throw 'Speed percentage must be greater than 0.' }
            $speedFactor = $percent / 100.0
            $targetDuration = $OriginalDurationSeconds / $speedFactor
        }
        else {
            $targetDuration = Parse-TimeInput -Text $textDuration.Text
            if ($targetDuration -le 0) { throw 'Target duration must be greater than 0.' }
            $speedFactor = $OriginalDurationSeconds / $targetDuration
        }

        if ($speedFactor -lt 0.25 -or $speedFactor -gt 8.0) {
            throw 'Speed must stay between 25% and 800%.'
        }

        $payload = [PSCustomObject]@{
            SpeedFactor      = $speedFactor
            TargetDuration   = $targetDuration
            KeepOriginalPitch = [bool]$checkKeepPitch.Checked
        }

        $form.Dispose()
        return $payload
    }
    catch {
        $message = $_.Exception.Message
        $form.Dispose()
        Show-ErrorAndExit $message
    }
}

#__FFCOMMON_INJECT_HERE__

try {
    if (-not (Test-Path -LiteralPath $InputFile)) {
        Show-ErrorAndExit 'Input file not found.'
    }

    $extension = [System.IO.Path]::GetExtension($InputFile).ToLowerInvariant()
    if ($extension -notin @('.wav', '.mp3', '.flac', '.m4a', '.ogg')) {
        Show-ErrorAndExit 'Unsupported input format. Only .wav, .mp3, .flac, .m4a and .ogg are supported.'
    }

    $ffmpegPath = Get-ToolPath -ToolName 'ffmpeg.exe'
    $ffprobePath = Get-ToolPath -ToolName 'ffprobe.exe'

    if (-not (Test-Path -LiteralPath $ffmpegPath)) {
        Show-ErrorAndExit 'ffmpeg.exe not found.'
    }
    if (-not (Test-Path -LiteralPath $ffprobePath)) {
        Show-ErrorAndExit 'ffprobe.exe not found.'
    }

    $audioInfo = Get-AudioInfo -FfprobePath $ffprobePath -FilePath $InputFile
    $speedConfig = Show-SpeedWindow -OriginalDurationSeconds $audioInfo.DurationSeconds
    if ($null -eq $speedConfig) {
        exit 0
    }

    $inputDir = Split-Path -Parent $InputFile
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $speedPercent = [int][Math]::Round($speedConfig.SpeedFactor * 100.0)
    $desiredOutput = Join-Path $inputDir ($baseName + '_speed_' + $speedPercent + 'pct' + $extension)
    $outputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

    $ffmpegArgs = Get-FinalAudioArguments -InputFile $InputFile -OutputFile $outputFile -Extension $extension -SpeedFactor $speedConfig.SpeedFactor -KeepPitch $speedConfig.KeepOriginalPitch -SampleRate $audioInfo.SampleRate
    $result = Invoke-FFmpegWithProgress -FfmpegPath $ffmpegPath -Arguments $ffmpegArgs -DurationSeconds $speedConfig.TargetDuration -OutputFile $outputFile -Title 'Change audio speed' -StatusText 'Processing audio speed...' -ModeLabel 'Audio'

    if ($result.Cancelled) {
        exit 0
    }

    if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $outputFile)) {
        Remove-FileIfExists -Path $outputFile
        Show-ErrorAndExit (Get-ShortErrorText -StdErr $result.StdErr)
    }

    exit 0
}
catch {
    Show-ErrorAndExit $_.Exception.Message
}
