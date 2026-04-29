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

function Write-DebugLog {
    param([string]$Message)

    try {
        $logPath = Join-Path ([System.IO.Path]::GetTempPath()) 'ffactions_change_audio_pitch.log'
        $timestamp = [System.DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss.fff')
        Add-Content -Path $logPath -Value ($timestamp + ' | ' + $Message) -Encoding UTF8
    }
    catch {}
}

function Get-AppRoot {
    if ($PSCommandPath) {
        $scriptDir = Split-Path -Parent $PSCommandPath
        return Split-Path -Parent $scriptDir
    }

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

function Format-DecimalValue {
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

function Get-FinalAudioArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)][string]$Extension,
        [Parameter(Mandatory = $true)][double]$PitchFactor,
        [Parameter(Mandatory = $true)][bool]$KeepDuration,
        [Parameter(Mandatory = $true)][int]$SampleRate
    )

    $args = @(
        '-y',
        '-hide_banner',
        '-progress', '-',
        '-nostats',
        '-i', $InputFile,
        '-vn'
    )

    if ($KeepDuration) {
        $pitchFilter = 'rubberband=pitch=' + $PitchFactor.ToString('0.######', [System.Globalization.CultureInfo]::InvariantCulture)
        $args += @(
            '-af',
            $pitchFilter
        )
    }
    else {
        $rate = [Math]::Max(1000, [int][Math]::Round($SampleRate * $PitchFactor))
        $varispeedFilter = 'asetrate=' + $rate + ',aresample=' + $SampleRate
        $args += @(
            '-filter:a',
            $varispeedFilter
        )
    }

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

function Show-PitchWindow {
    param(
        [Parameter(Mandatory = $true)][double]$OriginalDurationSeconds
    )

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $script:syncing = $false

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFActions - Change pitch'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(520, 330)
    $form.TopMost = $true

    $labelOriginal = New-Object System.Windows.Forms.Label
    $labelOriginal.Location = New-Object System.Drawing.Point(20, 18)
    $labelOriginal.Size = New-Object System.Drawing.Size(460, 22)
    $labelOriginal.Text = 'Original duration: ' + (Format-SecondsForDisplay -Seconds $OriginalDurationSeconds)
    $form.Controls.Add($labelOriginal)

    $groupAmount = New-Object System.Windows.Forms.GroupBox
    $groupAmount.Text = 'Pitch amount'
    $groupAmount.Location = New-Object System.Drawing.Point(18, 50)
    $groupAmount.Size = New-Object System.Drawing.Size(484, 132)
    $form.Controls.Add($groupAmount)

    $labelSemitones = New-Object System.Windows.Forms.Label
    $labelSemitones.Text = 'Semitones'
    $labelSemitones.Location = New-Object System.Drawing.Point(18, 30)
    $labelSemitones.Size = New-Object System.Drawing.Size(90, 20)
    $groupAmount.Controls.Add($labelSemitones)

    $textSemitones = New-Object System.Windows.Forms.TextBox
    $textSemitones.Location = New-Object System.Drawing.Point(130, 27)
    $textSemitones.Size = New-Object System.Drawing.Size(90, 23)
    $textSemitones.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Right
    $groupAmount.Controls.Add($textSemitones)

    $labelSemitonesHint = New-Object System.Windows.Forms.Label
    $labelSemitonesHint.Text = 'ex: -12, -3, 0, +3, +12'
    $labelSemitonesHint.Location = New-Object System.Drawing.Point(235, 30)
    $labelSemitonesHint.Size = New-Object System.Drawing.Size(180, 20)
    $groupAmount.Controls.Add($labelSemitonesHint)

    $labelPercent = New-Object System.Windows.Forms.Label
    $labelPercent.Text = 'Pitch (%)'
    $labelPercent.Location = New-Object System.Drawing.Point(18, 63)
    $labelPercent.Size = New-Object System.Drawing.Size(90, 20)
    $groupAmount.Controls.Add($labelPercent)

    $textPercent = New-Object System.Windows.Forms.TextBox
    $textPercent.Location = New-Object System.Drawing.Point(130, 60)
    $textPercent.Size = New-Object System.Drawing.Size(90, 23)
    $textPercent.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Right
    $groupAmount.Controls.Add($textPercent)

    $labelPercentUnit = New-Object System.Windows.Forms.Label
    $labelPercentUnit.Text = '%'
    $labelPercentUnit.Location = New-Object System.Drawing.Point(228, 63)
    $labelPercentUnit.Size = New-Object System.Drawing.Size(18, 20)
    $groupAmount.Controls.Add($labelPercentUnit)

    $labelPercentHint = New-Object System.Windows.Forms.Label
    $labelPercentHint.Text = '100 = unchanged'
    $labelPercentHint.Location = New-Object System.Drawing.Point(252, 63)
    $labelPercentHint.Size = New-Object System.Drawing.Size(150, 20)
    $groupAmount.Controls.Add($labelPercentHint)

    $presetSemitones = @(-12, -7, -5, -3, 0, 3, 5, 7, 12)
    $presetWidth = 46
    $presetGap = 6
    $presetStartX = 18
    for ($i = 0; $i -lt $presetSemitones.Count; $i++) {
        $value = [int]$presetSemitones[$i]
        $button = New-Object System.Windows.Forms.Button
        if ($value -gt 0) {
            $button.Text = '+' + [string]$value
        }
        else {
            $button.Text = [string]$value
        }
        $button.Tag = $value
        $button.Size = New-Object System.Drawing.Size($presetWidth, 26)
        $button.Location = New-Object System.Drawing.Point(($presetStartX + ($i * ($presetWidth + $presetGap))), 94)
        $button.Add_Click({
            param($sender, $eventArgs)
            $textSemitones.Text = [string]$sender.Tag
        })
        $groupAmount.Controls.Add($button)
    }

    $groupOptions = New-Object System.Windows.Forms.GroupBox
    $groupOptions.Text = 'Options'
    $groupOptions.Location = New-Object System.Drawing.Point(18, 192)
    $groupOptions.Size = New-Object System.Drawing.Size(484, 60)
    $form.Controls.Add($groupOptions)

    $checkKeepDuration = New-Object System.Windows.Forms.CheckBox
    $checkKeepDuration.Text = 'Keep original duration'
    $checkKeepDuration.Checked = $true
    $checkKeepDuration.Location = New-Object System.Drawing.Point(18, 24)
    $checkKeepDuration.Size = New-Object System.Drawing.Size(200, 24)
    $groupOptions.Controls.Add($checkKeepDuration)

    $labelResult = New-Object System.Windows.Forms.Label
    $labelResult.Location = New-Object System.Drawing.Point(20, 262)
    $labelResult.Size = New-Object System.Drawing.Size(470, 20)
    $form.Controls.Add($labelResult)

    $buttonOK = New-Object System.Windows.Forms.Button
    $buttonOK.Text = 'OK'
    $buttonOK.Location = New-Object System.Drawing.Point(306, 292)
    $buttonOK.Size = New-Object System.Drawing.Size(90, 28)
    $buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($buttonOK)

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.Location = New-Object System.Drawing.Point(408, 292)
    $buttonCancel.Size = New-Object System.Drawing.Size(90, 28)
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($buttonCancel)

    $form.AcceptButton = $buttonOK
    $form.CancelButton = $buttonCancel

    function Convert-SemitonesToPercent {
        param([double]$Semitones)
        return [Math]::Pow(2.0, ($Semitones / 12.0)) * 100.0
    }

    function Convert-PercentToSemitones {
        param([double]$Percent)
        if ($Percent -le 0) {
            throw 'Pitch percentage must be greater than 0.'
        }
        return 12.0 * ([Math]::Log(($Percent / 100.0), 2.0))
    }

    function Update-ResultLabel {
        if ($script:syncing) { return }
        try {
            $semiText = $textSemitones.Text.Trim().Replace(',', '.')
            $semi = 0.0
            if (-not [double]::TryParse($semiText, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$semi)) {
                $labelResult.Text = 'Enter a valid semitone value.'
                return
            }

            $percent = Convert-SemitonesToPercent -Semitones $semi
            $script:syncing = $true
            $textPercent.Text = Format-DecimalValue -Value $percent
            $script:syncing = $false

            if ($checkKeepDuration.Checked) {
                $labelResult.Text = 'Applied shift: ' + $semi.ToString('0.##', [System.Globalization.CultureInfo]::InvariantCulture) + ' semitones    Duration unchanged'
            }
            else {
                $estimatedDuration = $OriginalDurationSeconds / ($percent / 100.0)
                $labelResult.Text = 'Applied shift: ' + $semi.ToString('0.##', [System.Globalization.CultureInfo]::InvariantCulture) + ' semitones    Estimated duration: ' + (Format-SecondsForDisplay -Seconds $estimatedDuration)
            }
        }
        catch {
            $labelResult.Text = $_.Exception.Message
        }
    }

    $textSemitones.Add_TextChanged({
        if ($script:syncing) { return }
        Update-ResultLabel
    })

    $textPercent.Add_TextChanged({
        if ($script:syncing) { return }
        try {
            $percentText = $textPercent.Text.Trim().Replace(',', '.')
            $percent = 0.0
            if (-not [double]::TryParse($percentText, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$percent)) {
                $labelResult.Text = 'Enter a valid pitch percentage.'
                return
            }

            $semi = Convert-PercentToSemitones -Percent $percent
            $script:syncing = $true
            $textSemitones.Text = Format-DecimalValue -Value $semi
            $script:syncing = $false
            Update-ResultLabel
        }
        catch {
            $labelResult.Text = $_.Exception.Message
        }
    })

    $checkKeepDuration.Add_CheckedChanged({
        Update-ResultLabel
    })

    $textSemitones.Text = '0'
    Update-ResultLabel

    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        $form.Dispose()
        return $null
    }

    try {
        $semi = [double]::Parse($textSemitones.Text.Trim().Replace(',', '.'), [System.Globalization.CultureInfo]::InvariantCulture)
        if ($semi -lt -24.0 -or $semi -gt 24.0) {
            throw 'Pitch must stay between -24 and +24 semitones.'
        }

        $pitchFactor = [Math]::Pow(2.0, ($semi / 12.0))
        if ($pitchFactor -le 0) {
            throw 'Invalid pitch factor.'
        }

        $targetDuration = if ($checkKeepDuration.Checked) {
            $OriginalDurationSeconds
        }
        else {
            $OriginalDurationSeconds / $pitchFactor
        }

        $payload = [PSCustomObject]@{
            Semitones       = $semi
            PitchFactor     = $pitchFactor
            KeepDuration    = [bool]$checkKeepDuration.Checked
            TargetDuration  = $targetDuration
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
    Write-DebugLog 'Launch'
    Write-DebugLog ('InputFile=' + $InputFile)

    if (-not (Test-Path -LiteralPath $InputFile)) {
        Write-DebugLog 'Input file missing'
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
    Write-DebugLog ('DurationSeconds=' + $audioInfo.DurationSeconds.ToString([System.Globalization.CultureInfo]::InvariantCulture))
    Write-DebugLog ('SampleRate=' + $audioInfo.SampleRate)
    $pitchConfig = Show-PitchWindow -OriginalDurationSeconds $audioInfo.DurationSeconds
    if ($null -eq $pitchConfig) {
        Write-DebugLog 'Dialog cancelled'
        exit 0
    }

    Write-DebugLog ('Semitones=' + $pitchConfig.Semitones.ToString([System.Globalization.CultureInfo]::InvariantCulture))
    Write-DebugLog ('PitchFactor=' + $pitchConfig.PitchFactor.ToString([System.Globalization.CultureInfo]::InvariantCulture))
    Write-DebugLog ('KeepDuration=' + $pitchConfig.KeepDuration)

    $inputDir = Split-Path -Parent $InputFile
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $semiRounded = [int][Math]::Round($pitchConfig.Semitones)
    $semiLabel = if ($semiRounded -ge 0) { 'plus' + $semiRounded } else { 'minus' + [Math]::Abs($semiRounded) }
    $desiredOutput = Join-Path $inputDir ($baseName + '_pitch_' + $semiLabel + 'st' + $extension)
    $outputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput
    Write-DebugLog ('OutputFile=' + $outputFile)

    $ffmpegArgs = Get-FinalAudioArguments -InputFile $InputFile -OutputFile $outputFile -Extension $extension -PitchFactor $pitchConfig.PitchFactor -KeepDuration $pitchConfig.KeepDuration -SampleRate $audioInfo.SampleRate
    Write-DebugLog ('Args=' + (Join-ProcessArguments -Arguments $ffmpegArgs))
    $result = Invoke-FFmpegWithProgress -FfmpegPath $ffmpegPath -Arguments $ffmpegArgs -DurationSeconds $pitchConfig.TargetDuration -OutputFile $outputFile -Title 'Change pitch' -StatusText 'Processing audio pitch...' -ModeLabel 'Audio'
    Write-DebugLog ('Cancelled=' + $result.Cancelled)
    Write-DebugLog ('ExitCode=' + $result.ExitCode)
    if (-not [string]::IsNullOrWhiteSpace($result.StdErr)) {
        Write-DebugLog ('StdErr=' + (($result.StdErr -replace "`r`n", ' | ') -replace "`n", ' | '))
    }
    Write-DebugLog ('OutputExists=' + (Test-Path -LiteralPath $outputFile))

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
