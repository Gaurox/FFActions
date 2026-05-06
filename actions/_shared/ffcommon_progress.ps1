function Format-DurationClock {
    param([double]$Seconds)

    if ($Seconds -lt 0) { $Seconds = 0 }
    $ts = [TimeSpan]::FromSeconds([Math]::Round($Seconds))

    if ($ts.TotalHours -ge 1) {
        return ('{0:00}:{1:00}:{2:00}' -f [int]$ts.TotalHours, $ts.Minutes, $ts.Seconds)
    }

    return ('{0:00}:{1:00}' -f $ts.Minutes, $ts.Seconds)
}

function Convert-FFmpegTimeToSeconds {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $m = [regex]::Match($Value.Trim(), '^(?:(?<h>\d+):)?(?<m>\d+):(?<s>\d+(?:\.\d+)?)$')
    if (-not $m.Success) {
        return $null
    }

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $hours = if ([string]::IsNullOrWhiteSpace($m.Groups['h'].Value)) { 0 } else { [double]::Parse($m.Groups['h'].Value, $culture) }
    $mins  = [double]::Parse($m.Groups['m'].Value, $culture)
    $secs  = [double]::Parse($m.Groups['s'].Value, $culture)

    return ($hours * 3600.0) + ($mins * 60.0) + $secs
}

function Enable-ControlDoubleBuffering {
    param([Parameter(Mandatory = $true)]$Control)

    try {
        $prop = $Control.GetType().GetProperty(
            'DoubleBuffered',
            [System.Reflection.BindingFlags]'Instance, NonPublic'
        )
        if ($prop) {
            $prop.SetValue($Control, $true, $null)
        }
    } catch {
        # Best effort only: ne jamais bloquer l'action pour une optimisation UI.
    }
}

function Set-ProgressBarValueSafe {
    param(
        [Parameter(Mandatory = $true)]$ProgressBar,
        [Parameter(Mandatory = $true)][int]$Value
    )

    if ($Value -lt $ProgressBar.Minimum) { $Value = $ProgressBar.Minimum }
    if ($Value -gt $ProgressBar.Maximum) { $Value = $ProgressBar.Maximum }

    if ($ProgressBar.Value -ne $Value) {
        $ProgressBar.Value = $Value
    }
}


function Stop-FFmpegProcessSafe {
    param(
        [Parameter(Mandatory = $true)]$Process,
        [int]$TimeoutMilliseconds = 1500
    )

    try {
        if ($null -ne $Process -and -not $Process.HasExited) {
            $Process.Kill()
            try { [void]$Process.WaitForExit($TimeoutMilliseconds) } catch {}
        }
    } catch {
        # Ne jamais faire planter le script si l'arrêt échoue.
    }
}


function Wait-OutputFileFinalized {
    param(
        [string]$OutputFile,
        [int]$StableChecksRequired = 3,
        [int]$DelayMilliseconds = 250,
        [int]$TimeoutMilliseconds = 0,
        $ProgressForm,
        $StatusLabel
    )

    if ([string]::IsNullOrWhiteSpace($OutputFile)) {
        return
    }
    if (-not (Test-Path -LiteralPath $OutputFile)) {
        return
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $stableChecks = 0
    $lastLength = -1L

    if ($StatusLabel) {
        $StatusLabel.Text = 'Finalizing output file...'
    }

    while ($true) {
        if ($TimeoutMilliseconds -gt 0 -and $sw.ElapsedMilliseconds -ge $TimeoutMilliseconds) {
            return
        }

        $length = -1L
        $isUnlocked = $false

        try {
            $info = New-Object System.IO.FileInfo($OutputFile)
            if ($info.Exists) {
                $length = [int64]$info.Length
            }
        } catch {
            $length = -1L
        }

        try {
            $fs = [System.IO.File]::Open($OutputFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
            $fs.Close()
            $fs.Dispose()
            $isUnlocked = $true
        } catch {
            $isUnlocked = $false
        }

        if ($isUnlocked -and $length -ge 0 -and $length -eq $lastLength) {
            $stableChecks++
        } else {
            $stableChecks = 0
            $lastLength = $length
        }

        if ($stableChecks -ge $StableChecksRequired) {
            return
        }

        if ($ProgressForm -and -not $ProgressForm.IsDisposed) {
            [System.Windows.Forms.Application]::DoEvents()
        }
        [System.Threading.Thread]::Sleep($DelayMilliseconds)
    }
}

function Set-ProgressUiSmooth {
    param(
        [Parameter(Mandatory = $true)]$ProgressBar,
        [Parameter(Mandatory = $true)][int]$TargetValue,
        [Parameter(Mandatory = $true)][ref]$DisplayedValue,
        [double]$SmoothingFactor = 0.18
    )

    if ($TargetValue -lt $ProgressBar.Minimum) { $TargetValue = $ProgressBar.Minimum }
    if ($TargetValue -gt $ProgressBar.Maximum) { $TargetValue = $ProgressBar.Maximum }

    $current = [int]$DisplayedValue.Value

    if ($TargetValue -le $current) {
        if ($TargetValue -eq $ProgressBar.Maximum -and $current -ne $TargetValue) {
            $DisplayedValue.Value = $TargetValue
            Set-ProgressBarValueSafe -ProgressBar $ProgressBar -Value $TargetValue
        }
        return
    }

    $delta = $TargetValue - $current
    $step = [int][Math]::Ceiling($delta * $SmoothingFactor)
    if ($step -lt 1) { $step = 1 }
    if ($step -gt 35) { $step = 35 }

    $newValue = $current + $step
    if ($newValue -gt $TargetValue) { $newValue = $TargetValue }

    $DisplayedValue.Value = $newValue
    Set-ProgressBarValueSafe -ProgressBar $ProgressBar -Value $newValue
}

function New-ProgressForm {
    param(
        [string]$Title = 'Processing',
        [string]$InitialStatus = 'Processing...',
        [string]$InitialModeLabel = 'CPU'
    )

    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    Add-Type -AssemblyName System.Drawing | Out-Null

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(520, 170)
    $form.TopMost = $true
    $form.Tag = ''
    Enable-ControlDoubleBuffering -Control $form

    $labelStatus = New-Object System.Windows.Forms.Label
    $labelStatus.Location = New-Object System.Drawing.Point(15, 15)
    $labelStatus.Size = New-Object System.Drawing.Size(490, 20)
    $labelStatus.Text = $InitialStatus
    $form.Controls.Add($labelStatus)

    $labelMode = New-Object System.Windows.Forms.Label
    $labelMode.Location = New-Object System.Drawing.Point(15, 40)
    $labelMode.Size = New-Object System.Drawing.Size(490, 20)
    $labelMode.Text = "Mode: $InitialModeLabel"
    $form.Controls.Add($labelMode)

    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(15, 68)
    $progressBar.Size = New-Object System.Drawing.Size(490, 22)
    $progressBar.Minimum = 0
    $progressBar.Maximum = 1000
    $progressBar.Value = 0
    $progressBar.Style = 'Continuous'
    $form.Controls.Add($progressBar)

    $labelPercent = New-Object System.Windows.Forms.Label
    $labelPercent.Location = New-Object System.Drawing.Point(15, 98)
    $labelPercent.Size = New-Object System.Drawing.Size(120, 20)
    $labelPercent.Text = '0%'
    $form.Controls.Add($labelPercent)

    $labelEta = New-Object System.Windows.Forms.Label
    $labelEta.Location = New-Object System.Drawing.Point(150, 98)
    $labelEta.Size = New-Object System.Drawing.Size(260, 20)
    $labelEta.Text = ''
    $form.Controls.Add($labelEta)

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Location = New-Object System.Drawing.Point(405, 125)
    $buttonCancel.Size = New-Object System.Drawing.Size(100, 28)
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.Add_Click({
        param($sender, $eventArgs)
        $parentForm = $null
        try { $parentForm = $sender.FindForm() } catch {}
        if ($parentForm) {
            $parentForm.Tag = 'cancel'
        }
    })
    $form.Controls.Add($buttonCancel)

    return [PSCustomObject]@{
        Form         = $form
        StatusLabel  = $labelStatus
        ModeLabel    = $labelMode
        ProgressBar  = $progressBar
        PercentLabel = $labelPercent
        EtaLabel     = $labelEta
        CancelButton = $buttonCancel
    }
}

function Set-ProgressMode {
    param(
        [Parameter(Mandatory = $true)]$ModeControl,
        [Parameter(Mandatory = $true)][string]$ModeLabel
    )

    if ($ModeControl) {
        $ModeControl.Text = "Mode: $ModeLabel"
    }
}

function Reset-ProgressUi {
    param(
        [Parameter(Mandatory = $true)]$ProgressContext,
        [string]$StatusText = 'Processing...',
        [string]$ModeLabel = 'CPU'
    )

    if ($ProgressContext.StatusLabel) {
        $ProgressContext.StatusLabel.Text = $StatusText
    }
    if ($ProgressContext.ModeLabel) {
        $ProgressContext.ModeLabel.Text = "Mode: $ModeLabel"
    }
    if ($ProgressContext.ProgressBar) {
        Set-ProgressBarValueSafe -ProgressBar $ProgressContext.ProgressBar -Value 0
    }
    if ($ProgressContext.PercentLabel) {
        $ProgressContext.PercentLabel.Text = '0%'
    }
    if ($ProgressContext.EtaLabel) {
        $ProgressContext.EtaLabel.Text = ''
    }
    if ($ProgressContext.Form) {
        $ProgressContext.Form.Tag = ''
    }
    if ($ProgressContext.CancelButton) {
        $ProgressContext.CancelButton.Enabled = $true
    }
}

function Invoke-FFmpegWithProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [Parameter(Mandatory = $true)][object]$Arguments,
        [Parameter(Mandatory = $true)][double]$DurationSeconds,
        [Parameter()][string]$OutputFile,

        # Old signature used by interpolate.template.ps1
        [Parameter()]$ProgressForm,
        [Parameter()]$ProgressBar,
        [Parameter()]$StatusLabel,
        [Parameter()]$PercentLabel,
        [Parameter()]$TimeLabel,
        [Parameter()]$CancelButton,

        # Optional shared signature
        [Parameter()]$ProgressContext,
        [Parameter()][string]$Title = 'Processing',
        [Parameter()][string]$StatusText = 'Processing...',
        [Parameter()][string]$ModeLabel = 'CPU',
        [Parameter()]$ModeControl
    )

    if ($Arguments -is [string]) {
        $argumentArray = @($Arguments)
    }
    elseif ($Arguments -is [System.Collections.IEnumerable] -and -not ($Arguments -is [string])) {
        $argumentArray = @($Arguments)
    }
    else {
        $argumentArray = @([string]$Arguments)
    }

    if ([string]::IsNullOrWhiteSpace($OutputFile) -and $argumentArray.Count -gt 0) {
        # Best effort: plusieurs actions passent déjà OutputFile, mais cette détection évite
        # de fermer trop tôt si une ancienne action ne le transmet pas.
        for ($i = $argumentArray.Count - 1; $i -ge 0; $i--) {
            $candidate = [string]$argumentArray[$i]
            if (-not [string]::IsNullOrWhiteSpace($candidate) -and $candidate -notmatch '^-') {
                $OutputFile = $candidate
                break
            }
        }
    }

    if ($ProgressContext) {
        if (-not $ProgressForm -and $ProgressContext.PSObject.Properties['Form'])         { $ProgressForm = $ProgressContext.Form }
        if (-not $ProgressBar -and $ProgressContext.PSObject.Properties['ProgressBar'])   { $ProgressBar = $ProgressContext.ProgressBar }
        if (-not $StatusLabel -and $ProgressContext.PSObject.Properties['StatusLabel'])   { $StatusLabel = $ProgressContext.StatusLabel }
        if (-not $PercentLabel -and $ProgressContext.PSObject.Properties['PercentLabel']) { $PercentLabel = $ProgressContext.PercentLabel }
        if (-not $TimeLabel -and $ProgressContext.PSObject.Properties['EtaLabel'])        { $TimeLabel = $ProgressContext.EtaLabel }
        if (-not $CancelButton -and $ProgressContext.PSObject.Properties['CancelButton']) { $CancelButton = $ProgressContext.CancelButton }
        if (-not $ModeControl -and $ProgressContext.PSObject.Properties['ModeLabel'])     { $ModeControl = $ProgressContext.ModeLabel }
    }

    $ownsForm = $false
    if (-not $ProgressForm) {
        $ownsForm = $true
        $ctx = New-ProgressForm -Title $Title -InitialStatus $StatusText -InitialModeLabel $ModeLabel
        $ProgressForm  = $ctx.Form
        $ProgressBar   = $ctx.ProgressBar
        $StatusLabel   = $ctx.StatusLabel
        $PercentLabel  = $ctx.PercentLabel
        $TimeLabel     = $ctx.EtaLabel
        $CancelButton  = $ctx.CancelButton
        $ModeControl   = $ctx.ModeLabel
        $ProgressForm.Show()
        [System.Windows.Forms.Application]::DoEvents()
    }

    if ($StatusLabel) { $StatusLabel.Text = $StatusText }
    if ($ModeControl) { $ModeControl.Text = "Mode: $ModeLabel" }
    if ($ProgressBar) {
        $ProgressBar.Minimum = 0
        $ProgressBar.Maximum = 1000
        Set-ProgressBarValueSafe -ProgressBar $ProgressBar -Value 0
    }
    if ($PercentLabel) { $PercentLabel.Text = '0%' }
    if ($TimeLabel) { $TimeLabel.Text = '' }
    if ($CancelButton) { $CancelButton.Enabled = $true }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FfmpegPath
    $psi.Arguments = Join-ProcessArguments -Arguments $argumentArray
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    $stdErrBuilder = New-Object System.Text.StringBuilder
    $stdErrHandler = [System.Diagnostics.DataReceivedEventHandler]{
        param($sender, $eventArgs)
        if ($null -ne $eventArgs.Data) {
            [void]$stdErrBuilder.AppendLine($eventArgs.Data)
        }
    }
    $process.add_ErrorDataReceived($stdErrHandler)

    $exitCode = -1
    $isCancelled = $false
    $stdErr = ''
    $displayedProgressValue = 0
    $targetProgressValue = 0
    $currentSeconds = 0.0
    $lastShownWholePercent = -1
    $lastEtaUpdate = [System.DateTime]::MinValue
    $smoothedRemainingSeconds = $null
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        [void]$process.Start()
        $process.BeginErrorReadLine()

        # IMPORTANT : lecture stdout volontairement synchrone.
        # La version async pouvait laisser la fenêtre se fermer alors que FFmpeg travaillait encore
        # dans certains contextes PS2EXE/noConsole. Ici, la fonction ne peut pas terminer avant EOF stdout
        # puis WaitForExit(), donc avant la vraie fin de FFmpeg.
        while ($true) {
            if ($ProgressForm -and $ProgressForm.Tag -eq 'cancel') {
                $isCancelled = $true
                if ($StatusLabel) { $StatusLabel.Text = 'Cancelling...' }
                if ($TimeLabel) { $TimeLabel.Text = '' }
                if ($CancelButton) { $CancelButton.Enabled = $false }
                Stop-FFmpegProcessSafe -Process $process
                break
            }

            if ($ProgressForm -and $ProgressForm.IsDisposed) {
                $isCancelled = $true
                Stop-FFmpegProcessSafe -Process $process
                break
            }

            $line = $process.StandardOutput.ReadLine()
            if ($null -eq $line) {
                break
            }

            if (-not [string]::IsNullOrWhiteSpace($line)) {
                if ($line -match '^out_time=(.+)$') {
                    if (-not [string]::IsNullOrWhiteSpace($matches[1])) {
                        $seconds = Convert-FFmpegTimeToSeconds $matches[1]
                        if ($null -ne $seconds -and $DurationSeconds -gt 0) {
                            $currentSeconds = [double]$seconds
                            $rawPercent = ($currentSeconds / $DurationSeconds) * 100.0
                            if ($rawPercent -lt 0) { $rawPercent = 0 }
                            if ($rawPercent -gt 100) { $rawPercent = 100 }
                            $targetProgressValue = [int][Math]::Floor($rawPercent * 10.0)
                            if ($targetProgressValue -lt 0) { $targetProgressValue = 0 }
                            if ($targetProgressValue -gt 1000) { $targetProgressValue = 1000 }
                        }
                    }
                }
                elseif ($line -eq 'progress=end') {
                    $targetProgressValue = 1000
                    $currentSeconds = $DurationSeconds
                    if ($StatusLabel) { $StatusLabel.Text = 'Finalizing...' }
                }
            }

            if ($ProgressBar) {
                Set-ProgressUiSmooth -ProgressBar $ProgressBar -TargetValue $targetProgressValue -DisplayedValue ([ref]$displayedProgressValue)
            }

            $wholePercent = [int][Math]::Floor($displayedProgressValue / 10.0)
            if ($targetProgressValue -ge 1000) { $wholePercent = 100 }
            if ($wholePercent -lt 0) { $wholePercent = 0 }
            if ($wholePercent -gt 100) { $wholePercent = 100 }

            if ($PercentLabel -and $wholePercent -ne $lastShownWholePercent) {
                $PercentLabel.Text = "$wholePercent%"
                $lastShownWholePercent = $wholePercent
            }

            $now = [System.DateTime]::Now
            if ($TimeLabel -and ($now - $lastEtaUpdate).TotalMilliseconds -ge 1000) {
                $elapsedSeconds = $stopwatch.Elapsed.TotalSeconds

                if ($elapsedSeconds -ge 3 -and $currentSeconds -gt 0.1 -and $targetProgressValue -gt 0 -and $targetProgressValue -lt 1000 -and $DurationSeconds -gt 0) {
                    $remainingSeconds = ($elapsedSeconds / $currentSeconds) * ($DurationSeconds - $currentSeconds)
                    if ($remainingSeconds -lt 0) { $remainingSeconds = 0 }

                    if ($null -eq $smoothedRemainingSeconds) {
                        $smoothedRemainingSeconds = $remainingSeconds
                    } else {
                        $smoothedRemainingSeconds = ($smoothedRemainingSeconds * 0.70) + ($remainingSeconds * 0.30)
                    }

                    $elapsedText = Format-DurationClock $elapsedSeconds
                    $remainingText = Format-DurationClock $smoothedRemainingSeconds
                    $TimeLabel.Text = "Elapsed: $elapsedText | ETA: ~$remainingText"
                }

                $lastEtaUpdate = $now
            }

            [System.Windows.Forms.Application]::DoEvents()
        }

        if (-not $process.HasExited) {
            try { [void]$process.WaitForExit() } catch {}
        }
        try { $process.WaitForExit() } catch {}

        $exitCode = $process.ExitCode
        $stdErr = $stdErrBuilder.ToString()

        if (-not $isCancelled -and $exitCode -eq 0) {
            Wait-OutputFileFinalized -OutputFile $OutputFile -ProgressForm $ProgressForm -StatusLabel $StatusLabel

            $displayedProgressValue = 1000
            if ($ProgressBar) { Set-ProgressBarValueSafe -ProgressBar $ProgressBar -Value 1000 }
            if ($PercentLabel) { $PercentLabel.Text = '100%' }
            if ($TimeLabel) { $TimeLabel.Text = 'Done' }
            [System.Windows.Forms.Application]::DoEvents()
            [System.Threading.Thread]::Sleep(250)
        }

        try { $process.CancelErrorRead() } catch {}

        if ($isCancelled -and $OutputFile -and (Test-Path -LiteralPath $OutputFile)) {
            try { Remove-Item -LiteralPath $OutputFile -Force -ErrorAction SilentlyContinue } catch {}
        }

        if ($exitCode -ne 0 -and -not $isCancelled) {
            $errorLines = $stdErr -split "`r?`n" | Where-Object { $_ -notmatch '^\s*$' } | Select-Object -Last 3
            $errorMessage = $errorLines | ForEach-Object { $_.Trim() } -join "`n"

            if ($errorMessage) {
                $outputFileLine = ''
                if ($OutputFile -and $OutputFile -notmatch '^\s*$') {
                    $outputFileLine = " (output: $OutputFile)"
                }
                Write-Host "FFmpeg failed${outputFileLine}:$errorMessage" -ForegroundColor Red
            }
        }

        return [PSCustomObject]@{
            ExitCode   = $exitCode
            StdErr     = $stdErr
            Cancelled  = $isCancelled
            FfmpegPath = $FfmpegPath
            Arguments  = if ($argumentArray -is [System.Collections.IEnumerable] -and -not ($argumentArray -is [string])) { ($argumentArray | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' ' } else { $argumentArray }
            OutputFile = $OutputFile
        }
    }
    finally {
        try {
            if ($process -and $stdErrHandler) {
                $process.remove_ErrorDataReceived($stdErrHandler)
            }
        } catch {}
        try {
            if ($process) {
                $process.Dispose()
            }
        } catch {}

        if ($ownsForm -and $ProgressForm) {
            try { $ProgressForm.Close() } catch {}
            try { $ProgressForm.Dispose() } catch {}
        }
    }
}

function Invoke-WithEncodingPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [Parameter(Mandatory = $true)]$EncodingPlan,
        [Parameter(Mandatory = $true)][scriptblock]$ArgumentFactory,
        [Parameter(Mandatory = $true)][double]$DurationSeconds,
        [Parameter()][string]$OutputFile,
        [string]$Title = 'Processing',
        [string]$PreparingText = 'Processing...',
        [string]$FallbackPreparingText = 'Retrying with fallback...'
    )

    $primaryMode = if ($EncodingPlan.Primary -and $EncodingPlan.Primary.ModeLabel) { $EncodingPlan.Primary.ModeLabel } else { 'CPU' }
    $ui = New-ProgressForm -Title $Title -InitialStatus $PreparingText -InitialModeLabel $primaryMode
    $ui.Form.Show()
    [System.Windows.Forms.Application]::DoEvents()

    try {
        $primaryArgs = & $ArgumentFactory $EncodingPlan.Primary
        $primaryResult = Invoke-FFmpegWithProgress -FfmpegPath $FfmpegPath -Arguments $primaryArgs -DurationSeconds $DurationSeconds -OutputFile $OutputFile -ProgressContext $ui -Title $Title -StatusText $PreparingText -ModeLabel $primaryMode
        if ($primaryResult.Cancelled) {
            return $primaryResult
        }
        if (($primaryResult.ExitCode -eq 0) -and ((-not $OutputFile) -or (Test-Path -LiteralPath $OutputFile))) {
            return $primaryResult
        }
        if (-not $EncodingPlan.Fallback) {
            return $primaryResult
        }

        if ($OutputFile -and (Test-Path -LiteralPath $OutputFile)) {
            try { Remove-Item -LiteralPath $OutputFile -Force -ErrorAction SilentlyContinue } catch {}
        }

        $fallbackMode = if ($EncodingPlan.Fallback.ModeLabel) { $EncodingPlan.Fallback.ModeLabel } else { 'CPU' }
        Reset-ProgressUi -ProgressContext $ui -StatusText $FallbackPreparingText -ModeLabel $fallbackMode

        $fallbackArgs = & $ArgumentFactory $EncodingPlan.Fallback
        return (Invoke-FFmpegWithProgress -FfmpegPath $FfmpegPath -Arguments $fallbackArgs -DurationSeconds $DurationSeconds -OutputFile $OutputFile -ProgressContext $ui -Title $Title -StatusText $FallbackPreparingText -ModeLabel $fallbackMode)
    }
    finally {
        try { $ui.Form.Close() } catch {}
        try { $ui.Form.Dispose() } catch {}
    }
}
