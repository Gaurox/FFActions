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

    $m = [regex]::Match($Value.Trim(), '^(?<h>\d+):(?<m>\d+):(?<s>\d+(?:\.\d+)?)$')
    if (-not $m.Success) {
        return $null
    }

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $hours = [double]::Parse($m.Groups['h'].Value, $culture)
    $mins  = [double]::Parse($m.Groups['m'].Value, $culture)
    $secs  = [double]::Parse($m.Groups['s'].Value, $culture)

    return ($hours * 3600.0) + ($mins * 60.0) + $secs
}

function Quote-ProcessArgument {
    param([string]$Value)

    if ($null -eq $Value) {
        return ''
    }

    if ($Value -eq '') {
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

    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($arg in $Arguments) {
        if ($null -eq $arg) { continue }
        $text = [string]$arg
        if ($text -eq '') { continue }
        $parts.Add((Quote-ProcessArgument -Value $text))
    }

    return ($parts -join ' ')
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
    $progressBar.Maximum = 100
    $progressBar.Value = 0
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
        $ProgressContext.ProgressBar.Value = 0
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

    if ($StatusLabel) {
        $StatusLabel.Text = $StatusText
    }
    if ($ModeControl) {
        $ModeControl.Text = "Mode: $ModeLabel"
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FfmpegPath
    $psi.Arguments = Join-ProcessArguments -Arguments $argumentArray
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    $errorBuilder = New-Object System.Text.StringBuilder
    $errorHandler = [System.Diagnostics.DataReceivedEventHandler]{
        param($sender, $e)
        if (-not [string]::IsNullOrWhiteSpace($e.Data)) {
            [void]$errorBuilder.AppendLine($e.Data)
        }
    }

    $process.add_ErrorDataReceived($errorHandler)

    [void]$process.Start()
    $process.BeginErrorReadLine()

    $lastPercent = 0
    $exitCode = -1
    $isCancelled = $false
    $startTime = [System.DateTime]::Now

    if ($ProgressBar) {
        $ProgressBar.Value = 0
    }
    if ($PercentLabel) {
        $PercentLabel.Text = '0%'
    }
    if ($TimeLabel) {
        $TimeLabel.Text = ''
    }
    if ($CancelButton) {
        $CancelButton.Enabled = $true
    }

    try {
        while (-not $process.StandardOutput.EndOfStream) {
            $line = $process.StandardOutput.ReadLine()

            if ($null -eq $line) {
                continue
            }

            if ($line -match '^out_time=(.+)$') {
                $seconds = Convert-FFmpegTimeToSeconds $matches[1]

                if ($null -ne $seconds -and $DurationSeconds -gt 0) {
                    $percent = [int][Math]::Floor(($seconds / $DurationSeconds) * 100.0)
                    if ($percent -lt 0) { $percent = 0 }
                    if ($percent -gt 100) { $percent = 100 }

                    if ($percent -ne $lastPercent) {
                        $lastPercent = $percent
                        if ($ProgressBar) { $ProgressBar.Value = $percent }
                        if ($PercentLabel) { $PercentLabel.Text = "$percent%" }
                    }

                    $elapsedSeconds = ([System.DateTime]::Now - $startTime).TotalSeconds
                    if ($elapsedSeconds -ge 3 -and $seconds -gt 0.1 -and $percent -gt 0 -and $percent -lt 100) {
                        $remainingSeconds = ($elapsedSeconds / $seconds) * ($DurationSeconds - $seconds)
                        if ($remainingSeconds -lt 0) { $remainingSeconds = 0 }

                        $elapsedText = Format-DurationClock $elapsedSeconds
                        $remainingText = Format-DurationClock $remainingSeconds
                        if ($TimeLabel) { $TimeLabel.Text = "Elapsed: $elapsedText    Remaining: ~$remainingText" }
                    }
                }
            }
            elseif ($line -eq 'progress=end') {
                $lastPercent = 100
                if ($ProgressBar) { $ProgressBar.Value = 100 }
                if ($PercentLabel) { $PercentLabel.Text = '100%' }
            }

            [System.Windows.Forms.Application]::DoEvents()

            if ($ProgressForm -and $ProgressForm.Tag -eq 'cancel') {
                $isCancelled = $true
                if ($StatusLabel) { $StatusLabel.Text = 'Cancelling...' }
                if ($TimeLabel) { $TimeLabel.Text = '' }
                if ($CancelButton) { $CancelButton.Enabled = $false }
                if (-not $process.HasExited) {
                    try { $process.Kill() } catch {}
                }
                break
            }

            if ($ProgressForm -and $ProgressForm.IsDisposed) {
                $isCancelled = $true
                if (-not $process.HasExited) {
                    try { $process.Kill() } catch {}
                }
                break
            }
        }

        $process.WaitForExit()
        $exitCode = $process.ExitCode
        [System.Windows.Forms.Application]::DoEvents()

        if ($isCancelled -and $OutputFile -and (Test-Path -LiteralPath $OutputFile)) {
            try { Remove-Item -LiteralPath $OutputFile -Force -ErrorAction SilentlyContinue } catch {}
        }

        return [PSCustomObject]@{
            ExitCode  = $exitCode
            StdErr    = $errorBuilder.ToString()
            Cancelled = $isCancelled
        }
    }
    finally {
        try { $process.CancelErrorRead() } catch {}
        try { $process.remove_ErrorDataReceived($errorHandler) } catch {}
        $process.Dispose()

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
