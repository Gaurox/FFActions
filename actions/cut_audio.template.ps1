param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

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

function Set-ControlDoubleBuffered {
    param([Parameter(Mandatory = $true)][System.Windows.Forms.Control]$Control)

    try {
        $flags = [System.Reflection.BindingFlags]'Instance, NonPublic'
        $property = $Control.GetType().GetProperty('DoubleBuffered', $flags)
        if ($property) {
            $property.SetValue($Control, $true, $null)
        }
    }
    catch {}
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

function Parse-TimeInput {
    param([Parameter(Mandatory = $true)][string]$Text)

    $value = $Text.Trim()
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw 'Time value is required.'
    }

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $seconds = 0.0

    if ($value -match '^\d+(?:\.\d+)?$') {
        if (-not [double]::TryParse($value, [System.Globalization.NumberStyles]::Float, $culture, [ref]$seconds)) {
            throw 'Invalid time value.'
        }
        return $seconds
    }

    $m = [regex]::Match($value, '^(?<h>\d{1,2}):(?<m>\d{1,2}):(?<s>\d{1,2}(?:\.\d+)?)$')
    if ($m.Success) {
        $hours = [double]::Parse($m.Groups['h'].Value, $culture)
        $mins  = [double]::Parse($m.Groups['m'].Value, $culture)
        $secs  = [double]::Parse($m.Groups['s'].Value, $culture)
        return ($hours * 3600.0) + ($mins * 60.0) + $secs
    }

    $m2 = [regex]::Match($value, '^(?<m>\d{1,2}):(?<s>\d{1,2}(?:\.\d+)?)$')
    if ($m2.Success) {
        $mins  = [double]::Parse($m2.Groups['m'].Value, $culture)
        $secs  = [double]::Parse($m2.Groups['s'].Value, $culture)
        return ($mins * 60.0) + $secs
    }

    throw 'Invalid time format. Use seconds or hh:mm:ss.mmm'
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

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $duration = [double]::Parse($map['duration'].Replace(',', '.'), $culture)
    if ($duration -le 0) {
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
        DurationSeconds = $duration
        SampleRate      = $sampleRate
        Channels        = $channels
    }
}

function Convert-AudioToWaveformWav {
    param(
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$OutputWavPath
    )

    Remove-FileIfExists -Path $OutputWavPath

    $result = Invoke-HiddenProcess -FilePath $FfmpegPath -Arguments @(
        '-y',
        '-hide_banner',
        '-i', $InputPath,
        '-vn',
        '-ac', '1',
        '-ar', '8000',
        '-c:a', 'pcm_s16le',
        $OutputWavPath
    )

    if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $OutputWavPath)) {
        throw (Get-ShortErrorText -StdErr $result.StdErr)
    }
}

function Convert-AudioToEditWav {
    param(
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$OutputWavPath
    )

    Remove-FileIfExists -Path $OutputWavPath

    $result = Invoke-HiddenProcess -FilePath $FfmpegPath -Arguments @(
        '-y',
        '-hide_banner',
        '-i', $InputPath,
        '-vn',
        '-ac', '2',
        '-ar', '44100',
        '-c:a', 'pcm_s16le',
        $OutputWavPath
    )

    if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $OutputWavPath)) {
        throw (Get-ShortErrorText -StdErr $result.StdErr)
    }
}

function Get-WaveformPointsFromWav {
    param(
        [Parameter(Mandatory = $true)][string]$WavPath,
        [Parameter(Mandatory = $true)][int]$PointCount
    )

    if ($PointCount -lt 32) { $PointCount = 32 }

    $bytes = [System.IO.File]::ReadAllBytes($WavPath)
    if ($bytes.Length -lt 44) {
        throw 'Invalid WAV data.'
    }

    $dataOffset = 44
    for ($i = 12; $i -le ($bytes.Length - 8); ) {
        $chunkId = [System.Text.Encoding]::ASCII.GetString($bytes, $i, 4)
        $chunkSize = [BitConverter]::ToInt32($bytes, $i + 4)
        if ($chunkId -eq 'data') {
            $dataOffset = $i + 8
            break
        }
        $i += 8 + $chunkSize
        if (($chunkSize % 2) -ne 0) { $i++ }
    }

    $dataLength = $bytes.Length - $dataOffset
    if ($dataLength -le 0) {
        throw 'WAV data chunk not found.'
    }

    $sampleCount = [int][Math]::Floor($dataLength / 2)
    if ($sampleCount -le 0) {
        throw 'No audio samples found.'
    }

    $samplesPerBucket = [Math]::Max(1, [int][Math]::Ceiling($sampleCount / [double]$PointCount))
    $points = New-Object 'System.Collections.Generic.List[double]'

    for ($bucket = 0; $bucket -lt $PointCount; $bucket++) {
        $startSample = $bucket * $samplesPerBucket
        if ($startSample -ge $sampleCount) {
            $points.Add(0.0)
            continue
        }

        $endSample = [Math]::Min($sampleCount, $startSample + $samplesPerBucket)
        $peak = 0.0

        for ($s = $startSample; $s -lt $endSample; $s++) {
            $offset = $dataOffset + ($s * 2)
            $sample = [BitConverter]::ToInt16($bytes, $offset)
            $amp = [Math]::Abs($sample / 32768.0)
            if ($amp -gt $peak) { $peak = $amp }
        }

        $points.Add($peak)
    }

    return ,$points.ToArray()
}

function Get-WaveformPointsForSource {
    param(
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$TempRoot,
        [Parameter(Mandatory = $true)][int]$PointCount
    )

    if (-not (Test-Path -LiteralPath $TempRoot)) {
        [void](New-Item -ItemType Directory -Path $TempRoot -Force)
    }

    $waveformWavPath = Join-Path $TempRoot ('waveform_' + [guid]::NewGuid().ToString('N') + '.wav')
    try {
        Convert-AudioToWaveformWav -FfmpegPath $FfmpegPath -InputPath $SourcePath -OutputWavPath $waveformWavPath
        return Get-WaveformPointsFromWav -WavPath $waveformWavPath -PointCount $PointCount
    }
    finally {
        Remove-FileIfExists -Path $waveformWavPath
    }
}

function Remove-SelectionFromWorkingAudio {
    param(
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)][double]$StartSeconds,
        [Parameter(Mandatory = $true)][double]$EndSeconds,
        [Parameter(Mandatory = $true)][double]$CurrentDurationSeconds
    )

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $startText = [string]::Format($culture, '{0:0.###}', $StartSeconds)
    $endText = [string]::Format($culture, '{0:0.###}', $EndSeconds)

    if ($StartSeconds -le 0.0005 -and $EndSeconds -ge ($CurrentDurationSeconds - 0.0005)) {
        throw 'Remove selection cannot delete the entire audio.'
    }

    $filter = ''
    if ($StartSeconds -le 0.0005) {
        $filter = ('[0:a]atrim=start={0},asetpts=PTS-STARTPTS[out]' -f $endText)
    }
    elseif ($EndSeconds -ge ($CurrentDurationSeconds - 0.0005)) {
        $filter = ('[0:a]atrim=0:{0},asetpts=PTS-STARTPTS[out]' -f $startText)
    }
    else {
        $filter = ('[0:a]atrim=0:{0},asetpts=PTS-STARTPTS[a0];[0:a]atrim=start={1},asetpts=PTS-STARTPTS[a1];[a0][a1]concat=n=2:v=0:a=1[out]' -f $startText, $endText)
    }

    Remove-FileIfExists -Path $OutputFile

    $result = Invoke-HiddenProcess -FilePath $FfmpegPath -Arguments @(
        '-y',
        '-hide_banner',
        '-i', $InputFile,
        '-filter_complex', $filter,
        '-map', '[out]',
        '-c:a', 'pcm_s16le',
        $OutputFile
    )

    if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $OutputFile)) {
        Remove-FileIfExists -Path $OutputFile
        throw (Get-ShortErrorText -StdErr $result.StdErr)
    }
}


function Silence-SelectionInWorkingAudio {
    param(
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)][double]$StartSeconds,
        [Parameter(Mandatory = $true)][double]$EndSeconds,
        [Parameter(Mandatory = $true)][double]$CurrentDurationSeconds
    )

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $startText = [string]::Format($culture, '{0:0.###}', $StartSeconds)
    $endText = [string]::Format($culture, '{0:0.###}', $EndSeconds)
    $silenceDuration = $EndSeconds - $StartSeconds
    if ($silenceDuration -le 0.0005) {
        throw 'Selection is too short to silence.'
    }
    $silenceText = [string]::Format($culture, '{0:0.###}', $silenceDuration)

    $filter = ''
    if ($StartSeconds -le 0.0005 -and $EndSeconds -ge ($CurrentDurationSeconds - 0.0005)) {
        $filter = '[1:a]asetpts=PTS-STARTPTS[out]'
    }
    elseif ($StartSeconds -le 0.0005) {
        $filter = ('[1:a]asetpts=PTS-STARTPTS[s];[0:a]atrim=start={0},asetpts=PTS-STARTPTS[a1];[s][a1]concat=n=2:v=0:a=1[out]' -f $endText)
    }
    elseif ($EndSeconds -ge ($CurrentDurationSeconds - 0.0005)) {
        $filter = ('[0:a]atrim=0:{0},asetpts=PTS-STARTPTS[a0];[1:a]asetpts=PTS-STARTPTS[s];[a0][s]concat=n=2:v=0:a=1[out]' -f $startText)
    }
    else {
        $filter = ('[0:a]atrim=0:{0},asetpts=PTS-STARTPTS[a0];[1:a]asetpts=PTS-STARTPTS[s];[0:a]atrim=start={1},asetpts=PTS-STARTPTS[a1];[a0][s][a1]concat=n=3:v=0:a=1[out]' -f $startText, $endText)
    }

    Remove-FileIfExists -Path $OutputFile

    $result = Invoke-HiddenProcess -FilePath $FfmpegPath -Arguments @(
        '-y',
        '-hide_banner',
        '-i', $InputFile,
        '-f', 'lavfi',
        '-t', $silenceText,
        '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
        '-filter_complex', $filter,
        '-map', '[out]',
        '-c:a', 'pcm_s16le',
        $OutputFile
    )

    if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $OutputFile)) {
        Remove-FileIfExists -Path $OutputFile
        throw (Get-ShortErrorText -StdErr $result.StdErr)
    }
}

function New-PreviewPlayer {
    $player = New-Object psobject -Property @{
        SoundPlayer = $null
        TempPath    = $null
    }
    return $player
}

function Stop-PreviewPlayer {
    param($Player)

    if ($null -eq $Player) { return }

    if ($Player.SoundPlayer) {
        try { $Player.SoundPlayer.Stop() } catch {}
        $Player.SoundPlayer = $null
    }

    if ($Player.TempPath) {
        Remove-FileIfExists -Path $Player.TempPath
        $Player.TempPath = $null
    }
}

function Start-PreviewSelection {
    param(
        [Parameter(Mandatory = $true)]$Player,
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][double]$StartSeconds,
        [Parameter(Mandatory = $true)][double]$EndSeconds,
        [Parameter(Mandatory = $true)][string]$TempRoot
    )

    Stop-PreviewPlayer -Player $Player

    $duration = $EndSeconds - $StartSeconds
    if ($duration -le 0.05) {
        throw 'Selection is too short to preview.'
    }

    if (-not (Test-Path -LiteralPath $TempRoot)) {
        [void](New-Item -ItemType Directory -Path $TempRoot -Force)
    }

    $previewPath = Join-Path $TempRoot ('preview_' + [guid]::NewGuid().ToString('N') + '.wav')

    $result = Invoke-HiddenProcess -FilePath $FfmpegPath -Arguments @(
        '-y',
        '-hide_banner',
        '-ss', ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.###}', $StartSeconds)),
        '-t',  ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.###}', $duration)),
        '-i', $InputFile,
        '-vn',
        '-ac', '2',
        '-ar', '44100',
        '-c:a', 'pcm_s16le',
        $previewPath
    )

    if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $previewPath)) {
        throw (Get-ShortErrorText -StdErr $result.StdErr)
    }

    $soundPlayer = New-Object System.Media.SoundPlayer $previewPath
    $soundPlayer.Load()
    $soundPlayer.Play()

    $Player.SoundPlayer = $soundPlayer
    $Player.TempPath = $previewPath
}

function Get-FinalAudioArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)][double]$StartSeconds,
        [Parameter(Mandatory = $true)][double]$DurationSeconds,
        [Parameter(Mandatory = $true)][string]$Extension
    )

    $startText = [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.###}', $StartSeconds)
    $durationText = [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.###}', $DurationSeconds)

    switch ($Extension.ToLowerInvariant()) {
        '.wav' {
            return @(
                '-y',
                '-hide_banner',
                '-progress', '-',
                '-nostats',
                '-ss', $startText,
                '-t', $durationText,
                '-i', $InputFile,
                '-vn',
                '-c:a', 'pcm_s16le',
                $OutputFile
            )
        }
        '.mp3' {
            return @(
                '-y',
                '-hide_banner',
                '-progress', '-',
                '-nostats',
                '-ss', $startText,
                '-t', $durationText,
                '-i', $InputFile,
                '-vn',
                '-c:a', 'libmp3lame',
                '-b:a', '320k',
                $OutputFile
            )
        }
        '.flac' {
            return @(
                '-y',
                '-hide_banner',
                '-progress', '-',
                '-nostats',
                '-ss', $startText,
                '-t', $durationText,
                '-i', $InputFile,
                '-vn',
                '-c:a', 'flac',
                '-compression_level', '5',
                $OutputFile
            )
        }
        '.m4a' {
            return @(
                '-y',
                '-hide_banner',
                '-progress', '-',
                '-nostats',
                '-ss', $startText,
                '-t', $durationText,
                '-i', $InputFile,
                '-vn',
                '-c:a', 'aac',
                '-b:a', '256k',
                $OutputFile
            )
        }
        '.ogg' {
            return @(
                '-y',
                '-hide_banner',
                '-progress', '-',
                '-nostats',
                '-ss', $startText,
                '-t', $durationText,
                '-i', $InputFile,
                '-vn',
                '-c:a', 'libvorbis',
                '-q:a', '6',
                $OutputFile
            )
        }
        default {
            throw 'Unsupported audio format. Only .wav, .mp3, .flac, .m4a and .ogg are supported.'
        }
    }
}

function Show-CutAudioWindow {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$WorkingFile,
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [Parameter(Mandatory = $true)][string]$FfprobePath,
        [Parameter(Mandatory = $true)][double]$DurationSeconds,
        [Parameter(Mandatory = $true)][double[]]$WaveformPoints,
        [Parameter(Mandatory = $true)][string]$TempRoot
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFActions - Cut audio'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(900, 390)
    $form.TopMost = $true

    $labelFile = New-Object System.Windows.Forms.Label
    $labelFile.Location = New-Object System.Drawing.Point(15, 12)
    $labelFile.Size = New-Object System.Drawing.Size(860, 20)
    $labelFile.Text = [System.IO.Path]::GetFileName($InputFile)
    $form.Controls.Add($labelFile)

    $wavePanel = New-Object System.Windows.Forms.Panel
    $wavePanel.Location = New-Object System.Drawing.Point(15, 40)
    $wavePanel.Size = New-Object System.Drawing.Size(860, 180)
    $wavePanel.BorderStyle = 'FixedSingle'
    $wavePanel.BackColor = [System.Drawing.Color]::White
    Set-ControlDoubleBuffered -Control $wavePanel
    $form.Controls.Add($wavePanel)

    $labelStart = New-Object System.Windows.Forms.Label
    $labelStart.Location = New-Object System.Drawing.Point(15, 235)
    $labelStart.Size = New-Object System.Drawing.Size(50, 20)
    $labelStart.Text = 'Start'
    $form.Controls.Add($labelStart)

    $textStart = New-Object System.Windows.Forms.TextBox
    $textStart.Location = New-Object System.Drawing.Point(65, 232)
    $textStart.Size = New-Object System.Drawing.Size(120, 24)
    $form.Controls.Add($textStart)

    $labelEnd = New-Object System.Windows.Forms.Label
    $labelEnd.Location = New-Object System.Drawing.Point(205, 235)
    $labelEnd.Size = New-Object System.Drawing.Size(40, 20)
    $labelEnd.Text = 'End'
    $form.Controls.Add($labelEnd)

    $textEnd = New-Object System.Windows.Forms.TextBox
    $textEnd.Location = New-Object System.Drawing.Point(245, 232)
    $textEnd.Size = New-Object System.Drawing.Size(120, 24)
    $form.Controls.Add($textEnd)

    $labelSelection = New-Object System.Windows.Forms.Label
    $labelSelection.Location = New-Object System.Drawing.Point(390, 235)
    $labelSelection.Size = New-Object System.Drawing.Size(260, 20)
    $labelSelection.Text = ''
    $form.Controls.Add($labelSelection)

    $labelTimeline = New-Object System.Windows.Forms.Label
    $labelTimeline.Location = New-Object System.Drawing.Point(15, 258)
    $labelTimeline.Size = New-Object System.Drawing.Size(860, 20)
    $labelTimeline.Text = ''
    $form.Controls.Add($labelTimeline)

    $buttonPlay = New-Object System.Windows.Forms.Button
    $buttonPlay.Location = New-Object System.Drawing.Point(15, 315)
    $buttonPlay.Size = New-Object System.Drawing.Size(120, 30)
    $buttonPlay.Text = 'Play selection'
    $form.Controls.Add($buttonPlay)

    $buttonStop = New-Object System.Windows.Forms.Button
    $buttonStop.Location = New-Object System.Drawing.Point(145, 315)
    $buttonStop.Size = New-Object System.Drawing.Size(80, 30)
    $buttonStop.Text = 'Stop'
    $form.Controls.Add($buttonStop)

    $buttonRemove = New-Object System.Windows.Forms.Button
    $buttonRemove.Location = New-Object System.Drawing.Point(235, 315)
    $buttonRemove.Size = New-Object System.Drawing.Size(135, 30)
    $buttonRemove.Text = 'Remove selection'
    $form.Controls.Add($buttonRemove)

    $buttonSilence = New-Object System.Windows.Forms.Button
    $buttonSilence.Location = New-Object System.Drawing.Point(380, 315)
    $buttonSilence.Size = New-Object System.Drawing.Size(135, 30)
    $buttonSilence.Text = 'Silence selection'
    $form.Controls.Add($buttonSilence)

    $buttonCut = New-Object System.Windows.Forms.Button
    $buttonCut.Location = New-Object System.Drawing.Point(665, 315)
    $buttonCut.Size = New-Object System.Drawing.Size(100, 30)
    $buttonCut.Text = 'Cut'
    $form.Controls.Add($buttonCut)

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Location = New-Object System.Drawing.Point(775, 315)
    $buttonCancel.Size = New-Object System.Drawing.Size(100, 30)
    $buttonCancel.Text = 'Cancel'
    $form.Controls.Add($buttonCancel)

    $state = [PSCustomObject]@{
        WorkingFile          = $WorkingFile
        DurationSeconds      = $DurationSeconds
        WaveformPoints       = $WaveformPoints
        RemoveCount          = 0
        TotalRemovedSeconds  = 0.0
    }

    $selection = [PSCustomObject]@{
        StartSeconds = 0.0
        EndSeconds   = $DurationSeconds
    }

    $dragState = [PSCustomObject]@{
        Active             = $false
        Target             = ''
        LastTextUpdateTick = 0
        LastPaintStartX    = -1
        LastPaintEndX      = -1
    }

    $previewPlayer = New-PreviewPlayer

    $syncSelectionText = {
        $textStart.Text = Format-SecondsForDisplay -Seconds $selection.StartSeconds
        $textEnd.Text = Format-SecondsForDisplay -Seconds $selection.EndSeconds
    }

    $updateLabels = {
        $selectionDuration = $selection.EndSeconds - $selection.StartSeconds
        if ($selectionDuration -lt 0) { $selectionDuration = 0 }
        $labelSelection.Text = 'Selection: ' + (Format-SecondsForDisplay -Seconds $selectionDuration)

        $timelineText = 'Current audio: ' + (Format-SecondsForDisplay -Seconds $state.DurationSeconds)
        if ($state.RemoveCount -gt 0) {
            $timelineText += ('    Removed: {0} ({1})' -f $state.RemoveCount, (Format-SecondsForDisplay -Seconds $state.TotalRemovedSeconds))
        }
        $labelTimeline.Text = $timelineText
    }

    $timeToX = {
        param([double]$Seconds)
        $usableWidth = [Math]::Max(1, $wavePanel.ClientSize.Width - 1)
        if ($state.DurationSeconds -le 0) { return 0 }
        return [int][Math]::Round(($Seconds / $state.DurationSeconds) * $usableWidth)
    }

    $xToTime = {
        param([int]$X)
        $usableWidth = [Math]::Max(1, $wavePanel.ClientSize.Width - 1)
        $clampedX = [Math]::Max(0, [Math]::Min($usableWidth, $X))
        if ($state.DurationSeconds -le 0) { return 0.0 }
        return ($clampedX / [double]$usableWidth) * $state.DurationSeconds
    }

    $refreshSelectionUi = {
        param([bool]$ForceText)

        $startX = & $timeToX $selection.StartSeconds
        $endX = & $timeToX $selection.EndSeconds

        if ($ForceText) {
            & $syncSelectionText
            & $updateLabels
            $dragState.LastTextUpdateTick = [Environment]::TickCount
        }
        else {
            $nowTick = [Environment]::TickCount
            $elapsed = $nowTick - $dragState.LastTextUpdateTick
            if ($elapsed -lt 0) { $elapsed += [int]::MaxValue }
            if ($elapsed -ge 80) {
                & $syncSelectionText
                & $updateLabels
                $dragState.LastTextUpdateTick = $nowTick
            }
            else {
                & $updateLabels
            }
        }

        $oldStartX = $dragState.LastPaintStartX
        $oldEndX = $dragState.LastPaintEndX
        $dragState.LastPaintStartX = $startX
        $dragState.LastPaintEndX = $endX

        if ($ForceText -or $oldStartX -lt 0 -or $oldEndX -lt 0) {
            $wavePanel.Invalidate()
        }
        else {
            $pad = 10
            $left = [Math]::Max(0, [Math]::Min([Math]::Min($oldStartX, $startX), [Math]::Min($oldEndX, $endX)) - $pad)
            $right = [Math]::Min($wavePanel.ClientSize.Width - 1, [Math]::Max([Math]::Max($oldStartX, $startX), [Math]::Max($oldEndX, $endX)) + $pad)
            $invalidateWidth = [Math]::Max(1, $right - $left + 1)
            $rect = New-Object System.Drawing.Rectangle($left, 0, $invalidateWidth, $wavePanel.ClientSize.Height)
            $wavePanel.Invalidate($rect)
        }
    }

    $setSelectionToFullRange = {
        $selection.StartSeconds = 0.0
        $selection.EndSeconds = [Math]::Max(0.01, $state.DurationSeconds)
        if ($selection.EndSeconds -gt $state.DurationSeconds) {
            $selection.EndSeconds = $state.DurationSeconds
        }
        if ($selection.EndSeconds -le $selection.StartSeconds) {
            $selection.EndSeconds = [Math]::Min($state.DurationSeconds, $selection.StartSeconds + 0.01)
        }
    }

    $applyBoundaryFromText = {
        param([string]$Target)

        try {
            if ($Target -eq 'start') {
                $newStart = Parse-TimeInput -Text $textStart.Text
                if ($newStart -lt 0) { $newStart = 0 }
                if ($newStart -ge $selection.EndSeconds) { throw 'Start must be before end.' }
                if ($newStart -gt $state.DurationSeconds) { $newStart = $state.DurationSeconds }
                $selection.StartSeconds = $newStart
            }
            elseif ($Target -eq 'end') {
                $newEnd = Parse-TimeInput -Text $textEnd.Text
                if ($newEnd -gt $state.DurationSeconds) { $newEnd = $state.DurationSeconds }
                if ($newEnd -le $selection.StartSeconds) { throw 'End must be after start.' }
                $selection.EndSeconds = $newEnd
            }
            & $refreshSelectionUi $true
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                $_.Exception.Message,
                'FFActions - Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
            & $refreshSelectionUi $true
        }
    }

    $wavePanel.Add_Paint({
        param($sender, $e)

        $g = $e.Graphics
        $width = $sender.ClientSize.Width
        $height = $sender.ClientSize.Height
        $midY = [int]($height / 2)

        $g.Clear([System.Drawing.Color]::White)

        $wavePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, 110, 160), 1)
        $selectionBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(35, 80, 160, 220))
        $cursorStartPen = New-Object System.Drawing.Pen([System.Drawing.Color]::ForestGreen, 2)
        $cursorEndPen = New-Object System.Drawing.Pen([System.Drawing.Color]::Crimson, 2)
        $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::LightGray, 1)

        try {
            if ($state.WaveformPoints.Length -gt 0) {
                $maxIndex = [Math]::Min($width, $state.WaveformPoints.Length)
                for ($x = 0; $x -lt $maxIndex; $x++) {
                    $amp = $state.WaveformPoints[[Math]::Min($state.WaveformPoints.Length - 1, $x)]
                    if ($amp -lt 0) { $amp = 0 }
                    if ($amp -gt 1) { $amp = 1 }
                    $lineHalf = [int][Math]::Round($amp * (($height - 12) / 2.0))
                    if ($lineHalf -lt 1) { $lineHalf = 1 }
                    $g.DrawLine($wavePen, $x, $midY - $lineHalf, $x, $midY + $lineHalf)
                }
            }

            $startX = & $timeToX $selection.StartSeconds
            $endX = & $timeToX $selection.EndSeconds
            if ($endX -lt $startX) { $tmp = $startX; $startX = $endX; $endX = $tmp }

            $g.FillRectangle($selectionBrush, $startX, 0, [Math]::Max(1, $endX - $startX), $height)
            $g.DrawLine($cursorStartPen, $startX, 0, $startX, $height)
            $g.DrawLine($cursorEndPen, $endX, 0, $endX, $height)
            $g.DrawRectangle($borderPen, 0, 0, $width - 1, $height - 1)
        }
        finally {
            $wavePen.Dispose()
            $selectionBrush.Dispose()
            $cursorStartPen.Dispose()
            $cursorEndPen.Dispose()
            $borderPen.Dispose()
        }
    })

    $wavePanel.Add_MouseDown({
        param($sender, $e)

        $startX = & $timeToX $selection.StartSeconds
        $endX = & $timeToX $selection.EndSeconds
        if ([Math]::Abs($e.X - $startX) -le 8) {
            $dragState.Active = $true
            $dragState.Target = 'start'
        }
        elseif ([Math]::Abs($e.X - $endX) -le 8) {
            $dragState.Active = $true
            $dragState.Target = 'end'
        }
        else {
            $time = & $xToTime $e.X
            if ([Math]::Abs($time - $selection.StartSeconds) -le [Math]::Abs($time - $selection.EndSeconds)) {
                $dragState.Active = $true
                $dragState.Target = 'start'
            }
            else {
                $dragState.Active = $true
                $dragState.Target = 'end'
            }
        }

        $dragState.LastTextUpdateTick = [Environment]::TickCount
        $sender.Capture = $true
    })

    $wavePanel.Add_MouseMove({
        param($sender, $e)

        $startX = & $timeToX $selection.StartSeconds
        $endX = & $timeToX $selection.EndSeconds
        if (([Math]::Abs($e.X - $startX) -le 8) -or ([Math]::Abs($e.X - $endX) -le 8) -or $dragState.Active) {
            $sender.Cursor = [System.Windows.Forms.Cursors]::SizeWE
        }
        else {
            $sender.Cursor = [System.Windows.Forms.Cursors]::Default
        }

        if (-not $dragState.Active) {
            return
        }

        $time = & $xToTime $e.X
        if ($dragState.Target -eq 'start') {
            if ($time -lt 0) { $time = 0 }
            if ($time -gt ($selection.EndSeconds - 0.01)) { $time = $selection.EndSeconds - 0.01 }
            $selection.StartSeconds = [Math]::Max(0.0, $time)
        }
        elseif ($dragState.Target -eq 'end') {
            if ($time -lt ($selection.StartSeconds + 0.01)) { $time = $selection.StartSeconds + 0.01 }
            if ($time -gt $state.DurationSeconds) { $time = $state.DurationSeconds }
            $selection.EndSeconds = [Math]::Min($state.DurationSeconds, $time)
        }

        & $refreshSelectionUi $true
    })

    $wavePanel.Add_MouseUp({
        param($sender, $e)
        $dragState.Active = $false
        $dragState.Target = ''
    })

    $buttonPlay.Add_Click({
        try {
            Start-PreviewSelection -Player $previewPlayer -FfmpegPath $FfmpegPath -InputFile $state.WorkingFile -StartSeconds $selection.StartSeconds -EndSeconds $selection.EndSeconds -TempRoot $TempRoot
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                $_.Exception.Message,
                'FFActions - Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    })

    $buttonStop.Add_Click({
        Stop-PreviewPlayer -Player $previewPlayer
    })

    $buttonRemove.Add_Click({
        $newWorkingFile = $null
        try {
            & $applyBoundaryFromText 'start'
            & $applyBoundaryFromText 'end'

            $removeDuration = $selection.EndSeconds - $selection.StartSeconds
            if ($removeDuration -le 0.05) {
                throw 'Selection is too short to remove.'
            }
            if (($state.DurationSeconds - $removeDuration) -le 0.05) {
                throw 'Remove selection cannot delete the entire audio.'
            }

            Stop-PreviewPlayer -Player $previewPlayer

            $oldWorkingFile = $state.WorkingFile
            $newWorkingFile = Join-Path $TempRoot ('edit_' + [guid]::NewGuid().ToString('N') + '.wav')

            Remove-SelectionFromWorkingAudio -FfmpegPath $FfmpegPath -InputFile $oldWorkingFile -OutputFile $newWorkingFile -StartSeconds $selection.StartSeconds -EndSeconds $selection.EndSeconds -CurrentDurationSeconds $state.DurationSeconds

            $newInfo = Get-AudioInfo -FfprobePath $FfprobePath -FilePath $newWorkingFile
            $newWaveform = Get-WaveformPointsForSource -FfmpegPath $FfmpegPath -SourcePath $newWorkingFile -TempRoot $TempRoot -PointCount 860

            $state.WorkingFile = $newWorkingFile
            $state.DurationSeconds = $newInfo.DurationSeconds
            $state.WaveformPoints = $newWaveform
            $state.RemoveCount++
            $state.TotalRemovedSeconds += $removeDuration

            Remove-FileIfExists -Path $oldWorkingFile
            $newWorkingFile = $null

            & $setSelectionToFullRange
            $dragState.LastPaintStartX = -1
            $dragState.LastPaintEndX = -1
            & $refreshSelectionUi $true
        }
        catch {
            Remove-FileIfExists -Path $newWorkingFile
            [System.Windows.Forms.MessageBox]::Show(
                $_.Exception.Message,
                'FFActions - Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    })


    $buttonSilence.Add_Click({
        $newWorkingFile = $null
        try {
            & $applyBoundaryFromText 'start'
            & $applyBoundaryFromText 'end'

            $silenceDuration = $selection.EndSeconds - $selection.StartSeconds
            if ($silenceDuration -le 0.05) {
                throw 'Selection is too short to silence.'
            }

            Stop-PreviewPlayer -Player $previewPlayer

            $oldWorkingFile = $state.WorkingFile
            $newWorkingFile = Join-Path $TempRoot ('edit_' + [guid]::NewGuid().ToString('N') + '.wav')

            Silence-SelectionInWorkingAudio -FfmpegPath $FfmpegPath -InputFile $oldWorkingFile -OutputFile $newWorkingFile -StartSeconds $selection.StartSeconds -EndSeconds $selection.EndSeconds -CurrentDurationSeconds $state.DurationSeconds

            $newInfo = Get-AudioInfo -FfprobePath $FfprobePath -FilePath $newWorkingFile
            $newWaveform = Get-WaveformPointsForSource -FfmpegPath $FfmpegPath -SourcePath $newWorkingFile -TempRoot $TempRoot -PointCount 860

            $state.WorkingFile = $newWorkingFile
            $state.DurationSeconds = $newInfo.DurationSeconds
            $state.WaveformPoints = $newWaveform

            Remove-FileIfExists -Path $oldWorkingFile
            $newWorkingFile = $null

            $dragState.LastPaintStartX = -1
            $dragState.LastPaintEndX = -1
            & $refreshSelectionUi $true
        }
        catch {
            Remove-FileIfExists -Path $newWorkingFile
            [System.Windows.Forms.MessageBox]::Show(
                $_.Exception.Message,
                'FFActions - Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    })

    $buttonCancel.Add_Click({
        $form.Tag = 'cancel'
        $form.Close()
    })

    $buttonCut.Add_Click({
        try {
            & $applyBoundaryFromText 'start'
            & $applyBoundaryFromText 'end'

            $duration = $selection.EndSeconds - $selection.StartSeconds
            if ($duration -le 0.05) {
                throw 'Selection is too short.'
            }

            Stop-PreviewPlayer -Player $previewPlayer
            $form.Tag = [PSCustomObject]@{
                WorkingFile   = $state.WorkingFile
                StartSeconds  = $selection.StartSeconds
                EndSeconds    = $selection.EndSeconds
                Duration      = $duration
                RemoveCount   = $state.RemoveCount
                RemovedTotal  = $state.TotalRemovedSeconds
            }
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Close()
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                $_.Exception.Message,
                'FFActions - Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    })

    $textStart.Add_Leave({ & $applyBoundaryFromText 'start' })
    $textEnd.Add_Leave({ & $applyBoundaryFromText 'end' })

    $form.Add_FormClosing({
        param($sender, $e)
        Stop-PreviewPlayer -Player $previewPlayer
    })

    & $setSelectionToFullRange
    & $refreshSelectionUi $true

    $dialogResult = $form.ShowDialog()
    $result = $form.Tag
    $form.Dispose()

    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK -and $result -is [psobject]) {
        return $result
    }

    Remove-FileIfExists -Path $state.WorkingFile
    return $null
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

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'FFActionsAudio'
    if (-not (Test-Path -LiteralPath $tempRoot)) {
        [void](New-Item -ItemType Directory -Path $tempRoot -Force)
    }

    $workingAudioPath = Join-Path $tempRoot ('edit_' + [guid]::NewGuid().ToString('N') + '.wav')
    $workingAudioPathToCleanup = $workingAudioPath
    $selection = $null

    try {
        Convert-AudioToEditWav -FfmpegPath $ffmpegPath -InputPath $InputFile -OutputWavPath $workingAudioPath
        $waveformPoints = Get-WaveformPointsForSource -FfmpegPath $ffmpegPath -SourcePath $workingAudioPath -TempRoot $tempRoot -PointCount 860

        $selection = Show-CutAudioWindow -InputFile $InputFile -WorkingFile $workingAudioPath -FfmpegPath $ffmpegPath -FfprobePath $ffprobePath -DurationSeconds $audioInfo.DurationSeconds -WaveformPoints $waveformPoints -TempRoot $tempRoot
        if ($null -eq $selection) {
            exit 0
        }

        $workingAudioPathToCleanup = $selection.WorkingFile

        $inputDir = Split-Path -Parent $InputFile
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
        $desiredOutput = Join-Path $inputDir ($baseName + '_cut' + $extension)
        $outputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

        $ffmpegArgs = Get-FinalAudioArguments -InputFile $selection.WorkingFile -OutputFile $outputFile -StartSeconds $selection.StartSeconds -DurationSeconds $selection.Duration -Extension $extension

        $result = Invoke-FFmpegWithProgress -FfmpegPath $ffmpegPath -Arguments $ffmpegArgs -DurationSeconds $selection.Duration -OutputFile $outputFile -Title 'Cut audio' -StatusText 'Cutting audio...' -ModeLabel 'Audio'

        if ($result.Cancelled) {
            exit 0
        }

        if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $outputFile)) {
            Remove-FileIfExists -Path $outputFile
            Show-ErrorAndExit (Get-ShortErrorText -StdErr $result.StdErr)
        }

        exit 0
    }
    finally {
        Remove-FileIfExists -Path $workingAudioPathToCleanup
    }
}
catch {
    Show-ErrorAndExit $_.Exception.Message
}
