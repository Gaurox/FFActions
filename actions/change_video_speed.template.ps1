param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System

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

    return Get-ShortErrorTextFromFfmpeg -StdErr $StdErr -FallbackMessage 'FFmpeg failed during processing.'
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

function Get-VideoInfo {
    param(
        [Parameter(Mandatory = $true)][string]$FfprobePath,
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    $durationResult = Invoke-HiddenProcess -FilePath $FfprobePath -Arguments @(
        '-v', 'error',
        '-show_entries', 'format=duration',
        '-of', 'default=nokey=1:noprint_wrappers=1',
        $FilePath
    )

    if ($durationResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($durationResult.StdOut)) {
        throw 'Unable to determine video duration.'
    }

    $durationText = ($durationResult.StdOut -split "`r?`n" | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1)
    $duration = [double]::Parse($durationText.Trim().Replace(',', '.'), [System.Globalization.CultureInfo]::InvariantCulture)
    if ($duration -le 0) {
        throw 'Invalid video duration.'
    }

    $audioResult = Invoke-HiddenProcess -FilePath $FfprobePath -Arguments @(
        '-v', 'error',
        '-select_streams', 'a:0',
        '-show_entries', 'stream=sample_rate',
        '-of', 'default=nokey=1:noprint_wrappers=1',
        $FilePath
    )

    $hasAudio = $false
    $sampleRate = 44100
    if ($audioResult.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($audioResult.StdOut)) {
        $rateText = ($audioResult.StdOut -split "`r?`n" | Where-Object { $_.Trim() -match '^\d+$' } | Select-Object -First 1)
        if (-not [string]::IsNullOrWhiteSpace($rateText)) {
            $hasAudio = $true
            $sampleRate = [int]$rateText.Trim()
        }
    }

    return [PSCustomObject]@{
        DurationSeconds = $duration
        HasAudio        = $hasAudio
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

function Get-AudioSpeedFilter {
    param(
        [Parameter(Mandatory = $true)][double]$SpeedFactor,
        [Parameter(Mandatory = $true)][bool]$KeepPitch,
        [Parameter(Mandatory = $true)][int]$SampleRate
    )

    if ($KeepPitch) {
        return (Build-AtempoChain -Factor $SpeedFactor)
    }

    $rate = [Math]::Max(1000, [int][Math]::Round($SampleRate * $SpeedFactor))
    return ('asetrate=' + $rate + ',aresample=' + $SampleRate)
}

function Get-VideoSpeedFilter {
    param([Parameter(Mandatory = $true)][double]$SpeedFactor)

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $setPtsFactor = 1.0 / $SpeedFactor
    return ('setpts=' + $setPtsFactor.ToString('0.######', $culture) + '*PTS')
}

function Add-VideoCodecArguments {
    param(
        [Parameter(Mandatory = $true)][object[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Extension,
        [Parameter(Mandatory = $true)][bool]$HasAudio
    )

    switch ($Extension.ToLowerInvariant()) {
        '.webm' {
            $Arguments += @('-c:v', 'libvpx-vp9', '-crf', '32', '-b:v', '0')
            if ($HasAudio) { $Arguments += @('-c:a', 'libopus', '-b:a', '160k') }
        }
        '.avi' {
            $Arguments += @('-c:v', 'mpeg4', '-q:v', '3')
            if ($HasAudio) { $Arguments += @('-c:a', 'libmp3lame', '-b:a', '192k') }
        }
        default {
            $Arguments += @('-c:v', 'libx264', '-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p')
            if ($HasAudio) { $Arguments += @('-c:a', 'aac', '-b:a', '192k') }
        }
    }

    return ,$Arguments
}

function Get-VideoSpeedArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)][string]$Extension,
        [Parameter(Mandatory = $true)][double]$SpeedFactor,
        [Parameter(Mandatory = $true)][bool]$KeepPitch,
        [Parameter(Mandatory = $true)][bool]$HasAudio,
        [Parameter(Mandatory = $true)][int]$SampleRate
    )

    $videoFilter = Get-VideoSpeedFilter -SpeedFactor $SpeedFactor
    $args = @(
        '-y',
        '-hide_banner',
        '-loglevel', 'error',
        '-progress', 'pipe:1',
        '-nostats',
        '-i', $InputFile
    )

    if ($HasAudio) {
        $audioFilter = Get-AudioSpeedFilter -SpeedFactor $SpeedFactor -KeepPitch $KeepPitch -SampleRate $SampleRate
        $filter = '[0:v]' + $videoFilter + '[v];[0:a]' + $audioFilter + '[a]'
        $args += @('-filter_complex', $filter, '-map', '[v]', '-map', '[a]')
    }
    else {
        $args += @('-filter:v', $videoFilter, '-an')
    }

    $args = Add-VideoCodecArguments -Arguments $args -Extension $Extension -HasAudio $HasAudio
    $args += @($OutputFile)
    return ,$args
}

function Get-PreviewVideoArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)][double]$SpeedFactor,
        [Parameter(Mandatory = $true)][bool]$KeepPitch,
        [Parameter(Mandatory = $true)][bool]$HasAudio,
        [Parameter(Mandatory = $true)][int]$SampleRate,
        [Parameter(Mandatory = $true)][double]$PreviewSeconds
    )

    $videoFilter = Get-VideoSpeedFilter -SpeedFactor $SpeedFactor
    $args = @(
        '-y',
        '-hide_banner',
        '-loglevel', 'error',
        '-t', $PreviewSeconds.ToString('0.###', [System.Globalization.CultureInfo]::InvariantCulture),
        '-i', $InputFile
    )

    if ($HasAudio) {
        $audioFilter = Get-AudioSpeedFilter -SpeedFactor $SpeedFactor -KeepPitch $KeepPitch -SampleRate $SampleRate
        $filter = '[0:v]' + $videoFilter + '[v];[0:a]' + $audioFilter + '[a]'
        $args += @('-filter_complex', $filter, '-map', '[v]', '-map', '[a]', '-c:a', 'aac', '-b:a', '128k')
    }
    else {
        $args += @('-filter:v', $videoFilter, '-an')
    }

    $args += @('-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '23', '-pix_fmt', 'yuv420p', $OutputFile)
    return ,$args
}

function Show-SpeedWindow {
    param(
        [Parameter(Mandatory = $true)][double]$OriginalDurationSeconds,
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [Parameter(Mandatory = $true)][bool]$HasAudio,
        [Parameter(Mandatory = $true)][int]$SampleRate
    )

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $script:syncing = $false
    $script:previewFile = $null

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFActions - Change video speed'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(560, 430)
    $form.TopMost = $true

    $labelOriginal = New-Object System.Windows.Forms.Label
    $labelOriginal.Location = New-Object System.Drawing.Point(20, 18)
    $labelOriginal.Size = New-Object System.Drawing.Size(510, 22)
    $labelOriginal.Text = 'Original duration: ' + (Format-SecondsForDisplay -Seconds $OriginalDurationSeconds)
    $form.Controls.Add($labelOriginal)

    $groupSpeed = New-Object System.Windows.Forms.GroupBox
    $groupSpeed.Text = 'Speed'
    $groupSpeed.Location = New-Object System.Drawing.Point(18, 50)
    $groupSpeed.Size = New-Object System.Drawing.Size(524, 184)
    $form.Controls.Add($groupSpeed)

    $labelSliderLeft = New-Object System.Windows.Forms.Label
    $labelSliderLeft.Text = '25%'
    $labelSliderLeft.Location = New-Object System.Drawing.Point(18, 28)
    $labelSliderLeft.Size = New-Object System.Drawing.Size(42, 20)
    $labelSliderLeft.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $groupSpeed.Controls.Add($labelSliderLeft)

    $trackSpeed = New-Object System.Windows.Forms.TrackBar
    $trackSpeed.Location = New-Object System.Drawing.Point(60, 20)
    $trackSpeed.Size = New-Object System.Drawing.Size(404, 45)
    $trackSpeed.Minimum = 25
    $trackSpeed.Maximum = 400
    $trackSpeed.TickFrequency = 25
    $trackSpeed.SmallChange = 1
    $trackSpeed.LargeChange = 25
    $groupSpeed.Controls.Add($trackSpeed)

    $labelSliderRight = New-Object System.Windows.Forms.Label
    $labelSliderRight.Text = '400%'
    $labelSliderRight.Location = New-Object System.Drawing.Point(466, 28)
    $labelSliderRight.Size = New-Object System.Drawing.Size(42, 20)
    $labelSliderRight.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $groupSpeed.Controls.Add($labelSliderRight)

    $radioPercent = New-Object System.Windows.Forms.RadioButton
    $radioPercent.Text = 'Speed (%)'
    $radioPercent.Location = New-Object System.Drawing.Point(18, 74)
    $radioPercent.Size = New-Object System.Drawing.Size(110, 24)
    $radioPercent.Checked = $true
    $groupSpeed.Controls.Add($radioPercent)

    $textPercent = New-Object System.Windows.Forms.TextBox
    $textPercent.Location = New-Object System.Drawing.Point(150, 74)
    $textPercent.Size = New-Object System.Drawing.Size(90, 23)
    $textPercent.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Right
    $groupSpeed.Controls.Add($textPercent)

    $labelPercent = New-Object System.Windows.Forms.Label
    $labelPercent.Text = '%'
    $labelPercent.Location = New-Object System.Drawing.Point(248, 77)
    $labelPercent.Size = New-Object System.Drawing.Size(18, 20)
    $groupSpeed.Controls.Add($labelPercent)

    $radioDuration = New-Object System.Windows.Forms.RadioButton
    $radioDuration.Text = 'Target duration'
    $radioDuration.Location = New-Object System.Drawing.Point(18, 109)
    $radioDuration.Size = New-Object System.Drawing.Size(120, 24)
    $groupSpeed.Controls.Add($radioDuration)

    $textDuration = New-Object System.Windows.Forms.TextBox
    $textDuration.Location = New-Object System.Drawing.Point(150, 109)
    $textDuration.Size = New-Object System.Drawing.Size(130, 23)
    $groupSpeed.Controls.Add($textDuration)

    $labelDurationHint = New-Object System.Windows.Forms.Label
    $labelDurationHint.Text = 'sec or hh:mm:ss'
    $labelDurationHint.Location = New-Object System.Drawing.Point(288, 112)
    $labelDurationHint.Size = New-Object System.Drawing.Size(140, 20)
    $groupSpeed.Controls.Add($labelDurationHint)

    $presetValues = @(25, 50, 75, 100, 125, 150, 200, 400)
    $presetWidth = 56
    $presetGap = 5
    for ($i = 0; $i -lt $presetValues.Count; $i++) {
        $value = [int]$presetValues[$i]
        $button = New-Object System.Windows.Forms.Button
        $button.Text = "$value%"
        $button.Tag = $value
        $button.Size = New-Object System.Drawing.Size($presetWidth, 26)
        $button.Location = New-Object System.Drawing.Point((18 + ($i * ($presetWidth + $presetGap))), 146)
        $button.Add_Click({
            param($sender, $eventArgs)
            $radioPercent.Checked = $true
            $textPercent.Text = [string]$sender.Tag
        })
        $groupSpeed.Controls.Add($button)
    }

    $groupAudio = New-Object System.Windows.Forms.GroupBox
    $groupAudio.Text = 'Audio'
    $groupAudio.Location = New-Object System.Drawing.Point(18, 246)
    $groupAudio.Size = New-Object System.Drawing.Size(524, 55)
    $form.Controls.Add($groupAudio)

    $checkKeepPitch = New-Object System.Windows.Forms.CheckBox
    $checkKeepPitch.Text = 'Keep original audio pitch'
    $checkKeepPitch.Checked = $true
    $checkKeepPitch.Location = New-Object System.Drawing.Point(18, 22)
    $checkKeepPitch.Size = New-Object System.Drawing.Size(220, 24)
    $checkKeepPitch.Enabled = $HasAudio
    $groupAudio.Controls.Add($checkKeepPitch)

    $labelResult = New-Object System.Windows.Forms.Label
    $labelResult.Location = New-Object System.Drawing.Point(20, 312)
    $labelResult.Size = New-Object System.Drawing.Size(520, 20)
    $form.Controls.Add($labelResult)

    $buttonPreview = New-Object System.Windows.Forms.Button
    $buttonPreview.Text = 'Preview 10s'
    $buttonPreview.Location = New-Object System.Drawing.Point(20, 366)
    $buttonPreview.Size = New-Object System.Drawing.Size(104, 28)
    $form.Controls.Add($buttonPreview)

    $labelPreview = New-Object System.Windows.Forms.Label
    $labelPreview.Location = New-Object System.Drawing.Point(136, 370)
    $labelPreview.Size = New-Object System.Drawing.Size(190, 20)
    $form.Controls.Add($labelPreview)

    $buttonOK = New-Object System.Windows.Forms.Button
    $buttonOK.Text = 'OK'
    $buttonOK.Location = New-Object System.Drawing.Point(346, 366)
    $buttonOK.Size = New-Object System.Drawing.Size(90, 28)
    $buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($buttonOK)

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.Location = New-Object System.Drawing.Point(448, 366)
    $buttonCancel.Size = New-Object System.Drawing.Size(90, 28)
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($buttonCancel)

    $form.AcceptButton = $buttonOK
    $form.CancelButton = $buttonCancel

    function Update-UiState {
        $textPercent.Enabled = $radioPercent.Checked
        $textDuration.Enabled = $radioDuration.Checked
    }

    function Try-GetCurrentSpeedConfig {
        $percentText = $textPercent.Text.Trim().Replace(',', '.')
        $percent = 0.0
        if (-not [double]::TryParse($percentText, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$percent)) {
            throw 'Enter a valid speed percentage before previewing.'
        }

        if ($percent -lt 25.0 -or $percent -gt 400.0) {
            throw 'Speed must stay between 25% and 400%.'
        }

        return [PSCustomObject]@{
            SpeedFactor = $percent / 100.0
            KeepPitch   = [bool]$checkKeepPitch.Checked
        }
    }

    function Start-Preview {
        try {
            $config = Try-GetCurrentSpeedConfig
            $previewSeconds = [Math]::Min(10.0, [Math]::Max(0.5, $OriginalDurationSeconds))
            $previewPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ffactions_video_speed_preview_{0}.mp4' -f ([System.Guid]::NewGuid().ToString('N')))
            $args = Get-PreviewVideoArguments -InputFile $InputFile -OutputFile $previewPath -SpeedFactor $config.SpeedFactor -KeepPitch $config.KeepPitch -HasAudio $HasAudio -SampleRate $SampleRate -PreviewSeconds $previewSeconds

            $buttonPreview.Enabled = $false
            $labelPreview.Text = 'Preparing preview...'
            [System.Windows.Forms.Application]::DoEvents()

            $result = Invoke-HiddenProcess -FilePath $FfmpegPath -Arguments $args
            if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $previewPath)) {
                Remove-FileIfExists -Path $previewPath
                throw (Get-ShortErrorText -StdErr $result.StdErr)
            }

            Remove-FileIfExists -Path $script:previewFile
            $script:previewFile = $previewPath
            Start-Process -FilePath $previewPath | Out-Null
            $labelPreview.Text = 'Preview opened'
        }
        catch {
            $labelPreview.Text = ''
            [System.Windows.Forms.MessageBox]::Show(
                $_.Exception.Message,
                'FFActions - Preview error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
        finally {
            $buttonPreview.Enabled = $true
        }
    }

    function Sync-SliderFromPercent {
        param([double]$Percent)
        $sliderValue = [int][Math]::Round([Math]::Max($trackSpeed.Minimum, [Math]::Min($trackSpeed.Maximum, $Percent)))
        if ($trackSpeed.Value -ne $sliderValue) {
            $trackSpeed.Value = $sliderValue
        }
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
                Sync-SliderFromPercent -Percent $percent
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
                $percent = $speedFactor * 100.0
                $textPercent.Text = Format-PercentValue $percent
                Sync-SliderFromPercent -Percent $percent
                $script:syncing = $false
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

    $trackSpeed.Add_ValueChanged({
        if ($script:syncing) { return }
        $radioPercent.Checked = $true
        $script:syncing = $true
        $textPercent.Text = Format-PercentValue $trackSpeed.Value
        $script:syncing = $false
        Update-ResultLabel
    })

    $buttonPreview.Add_Click({ Start-Preview })

    $textPercent.Text = '100'
    $textDuration.Text = Format-SecondsForDisplay -Seconds $OriginalDurationSeconds
    $trackSpeed.Value = 100
    Update-UiState
    Update-ResultLabel

    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        $form.Dispose()
        return $null
    }

    try {
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

        if ($speedFactor -lt 0.25 -or $speedFactor -gt 4.0) {
            throw 'Speed must stay between 25% and 400%.'
        }

        $payload = [PSCustomObject]@{
            SpeedFactor       = $speedFactor
            TargetDuration    = $targetDuration
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
    if ($extension -notin @('.mp4', '.mkv', '.avi', '.mov', '.webm', '.m4v')) {
        Show-ErrorAndExit 'Unsupported input format. Only .mp4, .mkv, .avi, .mov, .webm and .m4v are supported.'
    }

    $ffmpegPath = Get-ToolPath -ToolName 'ffmpeg.exe'
    $ffprobePath = Get-ToolPath -ToolName 'ffprobe.exe'

    if (-not (Test-Path -LiteralPath $ffmpegPath)) {
        Show-ErrorAndExit 'ffmpeg.exe not found.'
    }
    if (-not (Test-Path -LiteralPath $ffprobePath)) {
        Show-ErrorAndExit 'ffprobe.exe not found.'
    }

    $videoInfo = Get-VideoInfo -FfprobePath $ffprobePath -FilePath $InputFile
    $speedConfig = Show-SpeedWindow -OriginalDurationSeconds $videoInfo.DurationSeconds -InputFile $InputFile -FfmpegPath $ffmpegPath -HasAudio $videoInfo.HasAudio -SampleRate $videoInfo.SampleRate
    if ($null -eq $speedConfig) {
        exit 0
    }

    $inputDir = Split-Path -Parent $InputFile
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $speedPercent = [int][Math]::Round($speedConfig.SpeedFactor * 100.0)
    $desiredOutput = Join-Path $inputDir ($baseName + '_video_speed_' + $speedPercent + 'pct' + $extension)
    $outputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

    $ffmpegArgs = Get-VideoSpeedArguments -InputFile $InputFile -OutputFile $outputFile -Extension $extension -SpeedFactor $speedConfig.SpeedFactor -KeepPitch $speedConfig.KeepOriginalPitch -HasAudio $videoInfo.HasAudio -SampleRate $videoInfo.SampleRate
    $result = Invoke-FFmpegWithProgress -FfmpegPath $ffmpegPath -Arguments $ffmpegArgs -DurationSeconds $speedConfig.TargetDuration -OutputFile $outputFile -Title 'Change video speed' -StatusText 'Processing video speed...' -ModeLabel 'Video'

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
