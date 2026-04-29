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

function Get-AudioInfo {
    param(
        [Parameter(Mandatory = $true)][string]$FfprobePath,
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    $probeResult = Invoke-HiddenProcess -FilePath $FfprobePath -Arguments @(
        '-v', 'error',
        '-select_streams', 'a:0',
        '-show_entries', 'stream=sample_rate,channels:format=duration',
        '-of', 'default=nokey=0:noprint_wrappers=1',
        $FilePath
    )

    if ($probeResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($probeResult.StdOut)) {
        if (-not [string]::IsNullOrWhiteSpace($probeResult.StdErr)) {
            throw $probeResult.StdErr.Trim()
        }
        throw 'ffprobe failed to read audio information.'
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

    $durationSeconds = [double]::Parse($map['duration'].Replace(',', '.'), [System.Globalization.CultureInfo]::InvariantCulture)
    if ($durationSeconds -le 0) {
        throw 'Invalid audio duration.'
    }

    $sampleRate = 44100
    if ($map.ContainsKey('sample_rate') -and $map['sample_rate'] -match '^\d+$') {
        $sampleRate = [int]$map['sample_rate']
    }

    $channels = 2
    if ($map.ContainsKey('channels') -and $map['channels'] -match '^\d+$') {
        $channels = [int]$map['channels']
    }

    return [PSCustomObject]@{
        DurationSeconds = $durationSeconds
        SampleRate      = $sampleRate
        Channels        = $channels
    }
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

function Remove-PartialOutput {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (Test-Path -LiteralPath $Path) {
        try { Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue } catch {}
    }
}

function Format-FileSize([long]$Bytes) {
    if ($Bytes -ge 1GB) {
        return ([Math]::Round(($Bytes / 1GB), 2)).ToString('0.##', [System.Globalization.CultureInfo]::InvariantCulture) + ' GB'
    }
    if ($Bytes -ge 1MB) {
        return ([Math]::Round(($Bytes / 1MB), 2)).ToString('0.##', [System.Globalization.CultureInfo]::InvariantCulture) + ' MB'
    }
    return ([Math]::Round(($Bytes / 1KB), 0)).ToString('0', [System.Globalization.CultureInfo]::InvariantCulture) + ' KB'
}

function Get-PresetLabel([string]$PresetKey) {
    switch ($PresetKey) {
        'high'     { return 'high' }
        'balanced' { return 'balanced' }
        'small'    { return 'small' }
        default    { return 'custom' }
    }
}

function Get-ShortErrorText {
    param([string]$StdErr)

    if (-not [string]::IsNullOrWhiteSpace($StdErr)) {
        $firstLines = ($StdErr -split "`r?`n" | Where-Object { $_.Trim() -ne '' } | Select-Object -First 12) -join "`r`n"
        if (-not [string]::IsNullOrWhiteSpace($firstLines)) {
            return $firstLines
        }
    }

    return 'FFmpeg failed during audio compression.'
}

function Get-PresetEncodingProfile {
    param(
        [Parameter(Mandatory = $true)][string]$Extension,
        [Parameter(Mandatory = $true)][string]$PresetKey,
        [Parameter(Mandatory = $true)]$AudioInfo
    )

    $sourceRate = [int]$AudioInfo.SampleRate
    $sourceChannels = [int]$AudioInfo.Channels

    $targetRate = switch ($PresetKey) {
        'high'     { [Math]::Min($sourceRate, 48000) }
        'balanced' { [Math]::Min($sourceRate, 44100) }
        default    { [Math]::Min($sourceRate, 32000) }
    }
    if ($targetRate -lt 16000) { $targetRate = $sourceRate }

    $targetChannels = if ($PresetKey -eq 'small' -and $sourceChannels -gt 1) { 1 } else { $sourceChannels }
    if ($targetChannels -lt 1) { $targetChannels = 1 }

    switch ($Extension.ToLowerInvariant()) {
        '.mp3' {
            $bitrate = switch ($PresetKey) { 'high' { 192 } 'balanced' { 128 } default { 96 } }
            return [PSCustomObject]@{
                ModeLabel = 'Audio'
                Codec     = 'libmp3lame'
                Args      = @('-b:a', ('{0}k' -f $bitrate), '-ar', [string]$targetRate, '-ac', [string]$targetChannels)
            }
        }
        '.m4a' {
            $bitrate = switch ($PresetKey) { 'high' { 160 } 'balanced' { 128 } default { 96 } }
            return [PSCustomObject]@{
                ModeLabel = 'Audio'
                Codec     = 'aac'
                Args      = @('-b:a', ('{0}k' -f $bitrate), '-ar', [string]$targetRate, '-ac', [string]$targetChannels)
            }
        }
        '.ogg' {
            $quality = switch ($PresetKey) { 'high' { 5 } 'balanced' { 4 } default { 3 } }
            return [PSCustomObject]@{
                ModeLabel = 'Audio'
                Codec     = 'libvorbis'
                Args      = @('-q:a', [string]$quality, '-ar', [string]$targetRate, '-ac', [string]$targetChannels)
            }
        }
        '.flac' {
            $compression = switch ($PresetKey) { 'high' { 5 } 'balanced' { 8 } default { 8 } }
            return [PSCustomObject]@{
                ModeLabel = 'Audio'
                Codec     = 'flac'
                Args      = @('-compression_level', [string]$compression, '-ar', [string]$targetRate, '-ac', [string]$targetChannels)
            }
        }
        '.wav' {
            $codec = switch ($PresetKey) { 'high' { 'adpcm_ms' } 'balanced' { 'adpcm_ima_wav' } default { 'adpcm_ima_wav' } }
            return [PSCustomObject]@{
                ModeLabel = 'Audio'
                Codec     = $codec
                Args      = @('-ar', [string]$targetRate, '-ac', [string]$targetChannels)
            }
        }
        default {
            throw 'Unsupported target format. Only .mp3, .wav, .flac, .m4a and .ogg are supported.'
        }
    }
}

function Get-TargetEncodingProfile {
    param(
        [Parameter(Mandatory = $true)][string]$Extension,
        [Parameter(Mandatory = $true)][long]$TargetBytes,
        [Parameter(Mandatory = $true)][double]$DurationSeconds,
        [Parameter(Mandatory = $true)]$AudioInfo
    )

    $totalKbps = [int][Math]::Floor((($TargetBytes * 8.0) / $DurationSeconds) / 1000.0 * 0.97)
    if ($totalKbps -lt 48) {
        throw 'Target size is too small for this audio duration.'
    }

    $sourceRate = [int]$AudioInfo.SampleRate
    $sourceChannels = [int]$AudioInfo.Channels
    $targetChannels = if ($totalKbps -lt 80 -and $sourceChannels -gt 1) { 1 } else { $sourceChannels }
    $targetRate = if ($totalKbps -lt 80) { [Math]::Min($sourceRate, 32000) } else { [Math]::Min($sourceRate, 44100) }
    if ($targetRate -lt 16000) { $targetRate = $sourceRate }

    switch ($Extension.ToLowerInvariant()) {
        '.mp3' {
            return [PSCustomObject]@{
                ModeLabel = 'Audio'
                Codec     = 'libmp3lame'
                Args      = @('-b:a', ('{0}k' -f $totalKbps), '-ar', [string]$targetRate, '-ac', [string]$targetChannels)
            }
        }
        '.m4a' {
            return [PSCustomObject]@{
                ModeLabel = 'Audio'
                Codec     = 'aac'
                Args      = @('-b:a', ('{0}k' -f $totalKbps), '-ar', [string]$targetRate, '-ac', [string]$targetChannels)
            }
        }
        '.ogg' {
            return [PSCustomObject]@{
                ModeLabel = 'Audio'
                Codec     = 'libvorbis'
                Args      = @('-b:a', ('{0}k' -f $totalKbps), '-ar', [string]$targetRate, '-ac', [string]$targetChannels)
            }
        }
        default {
            throw 'Target size is only supported for MP3, M4A and OGG.'
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

function Show-CompressAudioWindow {
    param(
        [Parameter(Mandatory = $true)][string]$SourceExtension,
        [Parameter(Mandatory = $true)][long]$SourceBytes,
        [Parameter(Mandatory = $true)]$AudioInfo
    )

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFActions - Compress audio'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(520, 325)
    $form.TopMost = $true

    $labelInfo = New-Object System.Windows.Forms.Label
    $labelInfo.Location = New-Object System.Drawing.Point(18, 14)
    $labelInfo.Size = New-Object System.Drawing.Size(480, 40)
    $labelInfo.Text = "Source: $($SourceExtension.TrimStart('.').ToUpperInvariant())    Size: $(Format-FileSize $SourceBytes)    Audio: $($AudioInfo.SampleRate) Hz / $($AudioInfo.Channels) ch"
    $form.Controls.Add($labelInfo)

    $groupPreset = New-Object System.Windows.Forms.GroupBox
    $groupPreset.Text = 'Compression level'
    $groupPreset.Location = New-Object System.Drawing.Point(18, 60)
    $groupPreset.Size = New-Object System.Drawing.Size(482, 92)
    $form.Controls.Add($groupPreset)

    $radioHigh = New-Object System.Windows.Forms.RadioButton
    $radioHigh.Text = 'High quality'
    $radioHigh.Location = New-Object System.Drawing.Point(18, 30)
    $radioHigh.Size = New-Object System.Drawing.Size(110, 24)
    $radioHigh.Checked = $true
    $groupPreset.Controls.Add($radioHigh)

    $radioBalanced = New-Object System.Windows.Forms.RadioButton
    $radioBalanced.Text = 'Balanced'
    $radioBalanced.Location = New-Object System.Drawing.Point(175, 30)
    $radioBalanced.Size = New-Object System.Drawing.Size(90, 24)
    $groupPreset.Controls.Add($radioBalanced)

    $radioSmall = New-Object System.Windows.Forms.RadioButton
    $radioSmall.Text = 'Small file'
    $radioSmall.Location = New-Object System.Drawing.Point(320, 30)
    $radioSmall.Size = New-Object System.Drawing.Size(90, 24)
    $groupPreset.Controls.Add($radioSmall)

    $labelPresetHint = New-Object System.Windows.Forms.Label
    $labelPresetHint.Location = New-Object System.Drawing.Point(18, 58)
    $labelPresetHint.Size = New-Object System.Drawing.Size(430, 18)
    $labelPresetHint.Text = 'High quality keeps more detail, Small file reduces bitrate and sample rate more strongly.'
    $groupPreset.Controls.Add($labelPresetHint)

    $groupTarget = New-Object System.Windows.Forms.GroupBox
    $groupTarget.Text = 'Optional target size'
    $groupTarget.Location = New-Object System.Drawing.Point(18, 165)
    $groupTarget.Size = New-Object System.Drawing.Size(482, 76)
    $form.Controls.Add($groupTarget)

    $checkTarget = New-Object System.Windows.Forms.CheckBox
    $checkTarget.Text = 'Target file size'
    $checkTarget.Location = New-Object System.Drawing.Point(18, 30)
    $checkTarget.Size = New-Object System.Drawing.Size(110, 24)
    $groupTarget.Controls.Add($checkTarget)

    $textTarget = New-Object System.Windows.Forms.TextBox
    $textTarget.Location = New-Object System.Drawing.Point(138, 29)
    $textTarget.Size = New-Object System.Drawing.Size(80, 24)
    $textTarget.Enabled = $false
    $groupTarget.Controls.Add($textTarget)

    $comboUnit = New-Object System.Windows.Forms.ComboBox
    $comboUnit.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboUnit.Location = New-Object System.Drawing.Point(228, 28)
    $comboUnit.Size = New-Object System.Drawing.Size(72, 24)
    [void]$comboUnit.Items.AddRange(@('KB', 'MB'))
    $comboUnit.SelectedItem = 'MB'
    $comboUnit.Enabled = $false
    $groupTarget.Controls.Add($comboUnit)

    $labelTargetHint = New-Object System.Windows.Forms.Label
    $labelTargetHint.Location = New-Object System.Drawing.Point(315, 31)
    $labelTargetHint.Size = New-Object System.Drawing.Size(145, 20)
    $labelTargetHint.Text = 'Lossy formats only'
    $groupTarget.Controls.Add($labelTargetHint)

    $supportsTarget = $SourceExtension.ToLowerInvariant() -in @('.mp3', '.m4a', '.ogg')
    $checkTarget.Enabled = $supportsTarget
    if (-not $supportsTarget) {
        $labelTargetHint.Text = 'Target size only for MP3/M4A/OGG'
    }

    $checkTarget.Add_CheckedChanged({
        $textTarget.Enabled = $checkTarget.Checked
        $comboUnit.Enabled = $checkTarget.Checked
    })

    $labelNote = New-Object System.Windows.Forms.Label
    $labelNote.Location = New-Object System.Drawing.Point(18, 250)
    $labelNote.Size = New-Object System.Drawing.Size(475, 30)
    $labelNote.Text = 'The compressed audio file is created next to the original file. The format stays the same.'
    $form.Controls.Add($labelNote)

    $buttonOK = New-Object System.Windows.Forms.Button
    $buttonOK.Text = 'OK'
    $buttonOK.Location = New-Object System.Drawing.Point(308, 287)
    $buttonOK.Size = New-Object System.Drawing.Size(90, 28)
    $buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($buttonOK)

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.Location = New-Object System.Drawing.Point(410, 287)
    $buttonCancel.Size = New-Object System.Drawing.Size(90, 28)
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($buttonCancel)

    $form.AcceptButton = $buttonOK
    $form.CancelButton = $buttonCancel

    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        $form.Dispose()
        return $null
    }

    try {
        $presetKey = if ($radioHigh.Checked) { 'high' } elseif ($radioBalanced.Checked) { 'balanced' } else { 'small' }
        $targetBytes = $null

        if ($supportsTarget -and $checkTarget.Checked) {
            $raw = $textTarget.Text.Trim().Replace(',', '.')
            $value = 0.0
            if (-not [double]::TryParse($raw, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$value) -or $value -le 0) {
                throw 'Target size must be a positive number.'
            }

            if ($comboUnit.SelectedItem -eq 'MB') {
                $targetBytes = [long][Math]::Round($value * 1MB)
            }
            else {
                $targetBytes = [long][Math]::Round($value * 1KB)
            }
        }

        $payload = [PSCustomObject]@{
            PresetKey   = $presetKey
            TargetBytes = $targetBytes
        }

        $form.Dispose()
        return $payload
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            'FFActions - Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        $form.Dispose()
        exit 1
    }
}

#__FFCOMMON_INJECT_HERE__

try {
    if ([string]::IsNullOrWhiteSpace($InputFile)) {
        Show-ErrorAndExit 'Input file is missing.'
    }

    if (-not (Test-Path -LiteralPath $InputFile)) {
        Show-ErrorAndExit 'Input file not found.'
    }

    $sourceExtension = [System.IO.Path]::GetExtension($InputFile).ToLowerInvariant()
    if ($sourceExtension -eq '.wave') { $sourceExtension = '.wav' }
    if ($sourceExtension -notin @('.mp3', '.wav', '.flac', '.m4a', '.ogg')) {
        Show-ErrorAndExit 'Unsupported input format. Only .mp3, .wav, .flac, .m4a and .ogg are supported.'
    }

    $ffmpeg = Get-ToolPath 'ffmpeg.exe'
    $ffprobe = Get-ToolPath 'ffprobe.exe'

    if (-not (Test-Path -LiteralPath $ffmpeg)) {
        Show-ErrorAndExit 'ffmpeg.exe not found.'
    }

    if (-not (Test-Path -LiteralPath $ffprobe)) {
        Show-ErrorAndExit 'ffprobe.exe not found.'
    }

    $audioInfo = Get-AudioInfo -FfprobePath $ffprobe -FilePath $InputFile
    $sourceBytes = (Get-Item -LiteralPath $InputFile).Length
    $compressConfig = Show-CompressAudioWindow -SourceExtension $sourceExtension -SourceBytes $sourceBytes -AudioInfo $audioInfo
    if ($null -eq $compressConfig) {
        exit 0
    }

    if ($null -ne $compressConfig.TargetBytes) {
        $encodingProfile = Get-TargetEncodingProfile -Extension $sourceExtension -TargetBytes ([long]$compressConfig.TargetBytes) -DurationSeconds ([double]$audioInfo.DurationSeconds) -AudioInfo $audioInfo
    }
    else {
        $encodingProfile = Get-PresetEncodingProfile -Extension $sourceExtension -PresetKey $compressConfig.PresetKey -AudioInfo $audioInfo
    }

    $inputDir = Split-Path -Parent $InputFile
    $inputBase = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $suffix = if ($null -ne $compressConfig.TargetBytes) { 'compress_target' } else { 'compress_' + (Get-PresetLabel -PresetKey $compressConfig.PresetKey) }
    $desiredOutput = Join-Path $inputDir ("{0}_{1}{2}" -f $inputBase, $suffix, $sourceExtension)
    $script:OutputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

    $encodingPlan = [PSCustomObject]@{
        Primary  = $encodingProfile
        Fallback = $null
    }

    $result = Invoke-WithEncodingPlan -FfmpegPath $ffmpeg -EncodingPlan $encodingPlan -DurationSeconds ([double]$audioInfo.DurationSeconds) -Title 'Compress audio' -PreparingText 'Preparing audio compression...' -OutputFile $script:OutputFile -ArgumentFactory {
        param($profile)
        New-FFmpegArguments -InputFile $InputFile -OutputFile $script:OutputFile -EncodingProfile $profile
    }

    if ($result.Cancelled) {
        Remove-PartialOutput -Path $script:OutputFile
        exit 0
    }

    if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $script:OutputFile)) {
        Remove-PartialOutput -Path $script:OutputFile
        Show-ErrorAndExit (Get-ShortErrorText -StdErr $result.StdErr)
    }

    exit 0
}
catch {
    $message = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($message)) { $message = 'Unknown audio compression error.' }
    Show-ErrorAndExit $message
}
