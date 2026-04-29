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

function Get-VideoInfo {
    param(
        [Parameter(Mandatory = $true)][string]$FfprobePath,
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    $probeResult = Invoke-HiddenProcess -FilePath $FfprobePath -Arguments @(
        '-v', 'error',
        '-select_streams', 'v:0',
        '-show_entries', 'format=duration:stream=width,height',
        '-of', 'default=nokey=0:noprint_wrappers=1',
        $FilePath
    )

    if ($probeResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($probeResult.StdOut)) {
        $probeErr = $probeResult.StdErr.Trim()
        if ([string]::IsNullOrWhiteSpace($probeErr)) {
            $probeErr = 'ffprobe failed to read video information.'
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
        throw 'Unable to determine video duration.'
    }

    $duration = [double]::Parse($map['duration'].Replace(',', '.'), [System.Globalization.CultureInfo]::InvariantCulture)
    if ($duration -le 0) {
        throw 'Invalid video duration.'
    }

    $width = 0
    $height = 0
    if ($map.ContainsKey('width') -and $map['width'] -match '^\d+$') { $width = [int]$map['width'] }
    if ($map.ContainsKey('height') -and $map['height'] -match '^\d+$') { $height = [int]$map['height'] }

    return [PSCustomObject]@{
        DurationSeconds = $duration
        Width = $width
        Height = $height
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

    return 'FFmpeg failed during video compression.'
}

function Test-NvencAvailable {
    param([Parameter(Mandatory = $true)][string]$FfmpegPath)

    $result = Invoke-HiddenProcess -FilePath $FfmpegPath -Arguments @('-hide_banner', '-encoders')
    if ($result.ExitCode -ne 0) {
        return $false
    }

    $allText = ($result.StdOut + "`r`n" + $result.StdErr)
    return ($allText -match '(^|\s)h264_nvenc(\s|$)')
}

function Get-DefaultAudioBitrateKbps {
    param(
        [Parameter(Mandatory = $true)][string]$Extension,
        [Parameter(Mandatory = $true)][string]$PresetKey
    )

    switch ($Extension.ToLowerInvariant()) {
        '.webm' {
            switch ($PresetKey) {
                'high'     { return 128 }
                'balanced' { return 96 }
                'small'    { return 64 }
            }
        }
        '.avi' {
            switch ($PresetKey) {
                'high'     { return 192 }
                'balanced' { return 128 }
                'small'    { return 96 }
            }
        }
        default {
            switch ($PresetKey) {
                'high'     { return 192 }
                'balanced' { return 128 }
                'small'    { return 96 }
            }
        }
    }

    return 128
}

function Get-PresetEncodingPlan {
    param(
        [Parameter(Mandatory = $true)][string]$Extension,
        [Parameter(Mandatory = $true)][string]$PresetKey,
        [Parameter(Mandatory = $true)][bool]$NvencAvailable
    )

    switch ($Extension.ToLowerInvariant()) {
        '.mp4' {
            $audioKbps = Get-DefaultAudioBitrateKbps -Extension '.mp4' -PresetKey $PresetKey
            $crf = switch ($PresetKey) { 'high' { 22 } 'balanced' { 27 } default { 31 } }
            $cq = switch ($PresetKey) { 'high' { 24 } 'balanced' { 29 } default { 33 } }

            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'libx264'
                VideoArgs  = @('-preset', 'medium', '-crf', [string]$crf, '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                AudioCodec = 'aac'
                AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
            }

            if ($NvencAvailable) {
                $gpu = [PSCustomObject]@{
                    ModeLabel  = 'NVIDIA GPU'
                    VideoCodec = 'h264_nvenc'
                    VideoArgs  = @('-preset', 'p5', '-cq', [string]$cq, '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                    AudioCodec = 'aac'
                    AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
                }
                return [PSCustomObject]@{ Primary = $gpu; Fallback = $cpu }
            }

            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        '.mkv' {
            $audioKbps = Get-DefaultAudioBitrateKbps -Extension '.mkv' -PresetKey $PresetKey
            $crf = switch ($PresetKey) { 'high' { 22 } 'balanced' { 27 } default { 31 } }
            $cq = switch ($PresetKey) { 'high' { 24 } 'balanced' { 29 } default { 33 } }

            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'libx264'
                VideoArgs  = @('-preset', 'medium', '-crf', [string]$crf, '-pix_fmt', 'yuv420p')
                AudioCodec = 'aac'
                AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
            }

            if ($NvencAvailable) {
                $gpu = [PSCustomObject]@{
                    ModeLabel  = 'NVIDIA GPU'
                    VideoCodec = 'h264_nvenc'
                    VideoArgs  = @('-preset', 'p5', '-cq', [string]$cq, '-pix_fmt', 'yuv420p')
                    AudioCodec = 'aac'
                    AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
                }
                return [PSCustomObject]@{ Primary = $gpu; Fallback = $cpu }
            }

            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        '.mov' {
            $audioKbps = Get-DefaultAudioBitrateKbps -Extension '.mov' -PresetKey $PresetKey
            $crf = switch ($PresetKey) { 'high' { 22 } 'balanced' { 27 } default { 31 } }
            $cq = switch ($PresetKey) { 'high' { 24 } 'balanced' { 29 } default { 33 } }

            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'libx264'
                VideoArgs  = @('-preset', 'medium', '-crf', [string]$crf, '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                AudioCodec = 'aac'
                AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
            }

            if ($NvencAvailable) {
                $gpu = [PSCustomObject]@{
                    ModeLabel  = 'NVIDIA GPU'
                    VideoCodec = 'h264_nvenc'
                    VideoArgs  = @('-preset', 'p5', '-cq', [string]$cq, '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                    AudioCodec = 'aac'
                    AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
                }
                return [PSCustomObject]@{ Primary = $gpu; Fallback = $cpu }
            }

            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        '.m4v' {
            $audioKbps = Get-DefaultAudioBitrateKbps -Extension '.m4v' -PresetKey $PresetKey
            $crf = switch ($PresetKey) { 'high' { 22 } 'balanced' { 27 } default { 31 } }
            $cq = switch ($PresetKey) { 'high' { 24 } 'balanced' { 29 } default { 33 } }

            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'libx264'
                VideoArgs  = @('-preset', 'medium', '-crf', [string]$crf, '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                AudioCodec = 'aac'
                AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
            }

            if ($NvencAvailable) {
                $gpu = [PSCustomObject]@{
                    ModeLabel  = 'NVIDIA GPU'
                    VideoCodec = 'h264_nvenc'
                    VideoArgs  = @('-preset', 'p5', '-cq', [string]$cq, '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                    AudioCodec = 'aac'
                    AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
                }
                return [PSCustomObject]@{ Primary = $gpu; Fallback = $cpu }
            }

            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        '.avi' {
            $audioKbps = Get-DefaultAudioBitrateKbps -Extension '.avi' -PresetKey $PresetKey
            $qv = switch ($PresetKey) { 'high' { 4 } 'balanced' { 8 } default { 12 } }

            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'mpeg4'
                VideoArgs  = @('-q:v', [string]$qv)
                AudioCodec = 'libmp3lame'
                AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
            }

            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        '.webm' {
            $audioKbps = Get-DefaultAudioBitrateKbps -Extension '.webm' -PresetKey $PresetKey
            $crf = switch ($PresetKey) { 'high' { 34 } 'balanced' { 40 } default { 46 } }

            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'libvpx-vp9'
                VideoArgs  = @('-crf', [string]$crf, '-b:v', '0', '-deadline', 'good', '-cpu-used', '2', '-row-mt', '1')
                AudioCodec = 'libopus'
                AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
            }

            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        default {
            throw 'Unsupported file format. Supported: .mp4, .mkv, .avi, .mov, .webm, .m4v'
        }
    }
}

function Get-TargetEncodingPlan {
    param(
        [Parameter(Mandatory = $true)][string]$Extension,
        [Parameter(Mandatory = $true)][string]$PresetKey,
        [Parameter(Mandatory = $true)][bool]$NvencAvailable,
        [Parameter(Mandatory = $true)][long]$TargetBytes,
        [Parameter(Mandatory = $true)][double]$DurationSeconds
    )

    $totalKbps = [int][Math]::Floor((($TargetBytes * 8.0) / $DurationSeconds) / 1000.0 * 0.97)
    if ($totalKbps -lt 64) {
        throw 'Target size is too small for this video duration.'
    }

    $audioKbps = Get-DefaultAudioBitrateKbps -Extension $Extension -PresetKey $PresetKey
    $minVideoKbps = if ($Extension -eq '.webm') { 120 } else { 180 }

    if (($totalKbps - $audioKbps) -lt $minVideoKbps) {
        $audioKbps = [Math]::Max(48, $totalKbps - $minVideoKbps)
    }

    $videoKbps = [Math]::Max($minVideoKbps, $totalKbps - $audioKbps)
    $bufKbps = [Math]::Max($videoKbps * 2, $videoKbps + 128)

    switch ($Extension.ToLowerInvariant()) {
        '.mp4' {
            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'libx264'
                VideoArgs  = @('-preset', 'medium', '-b:v', ('{0}k' -f $videoKbps), '-maxrate', ('{0}k' -f $videoKbps), '-bufsize', ('{0}k' -f $bufKbps), '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                AudioCodec = 'aac'
                AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
            }
            if ($NvencAvailable) {
                $gpu = [PSCustomObject]@{
                    ModeLabel  = 'NVIDIA GPU'
                    VideoCodec = 'h264_nvenc'
                    VideoArgs  = @('-preset', 'p5', '-b:v', ('{0}k' -f $videoKbps), '-maxrate', ('{0}k' -f $videoKbps), '-bufsize', ('{0}k' -f $bufKbps), '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                    AudioCodec = 'aac'
                    AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
                }
                return [PSCustomObject]@{ Primary = $gpu; Fallback = $cpu }
            }
            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        '.mkv' {
            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'libx264'
                VideoArgs  = @('-preset', 'medium', '-b:v', ('{0}k' -f $videoKbps), '-maxrate', ('{0}k' -f $videoKbps), '-bufsize', ('{0}k' -f $bufKbps), '-pix_fmt', 'yuv420p')
                AudioCodec = 'aac'
                AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
            }
            if ($NvencAvailable) {
                $gpu = [PSCustomObject]@{
                    ModeLabel  = 'NVIDIA GPU'
                    VideoCodec = 'h264_nvenc'
                    VideoArgs  = @('-preset', 'p5', '-b:v', ('{0}k' -f $videoKbps), '-maxrate', ('{0}k' -f $videoKbps), '-bufsize', ('{0}k' -f $bufKbps), '-pix_fmt', 'yuv420p')
                    AudioCodec = 'aac'
                    AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
                }
                return [PSCustomObject]@{ Primary = $gpu; Fallback = $cpu }
            }
            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        '.mov' {
            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'libx264'
                VideoArgs  = @('-preset', 'medium', '-b:v', ('{0}k' -f $videoKbps), '-maxrate', ('{0}k' -f $videoKbps), '-bufsize', ('{0}k' -f $bufKbps), '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                AudioCodec = 'aac'
                AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
            }
            if ($NvencAvailable) {
                $gpu = [PSCustomObject]@{
                    ModeLabel  = 'NVIDIA GPU'
                    VideoCodec = 'h264_nvenc'
                    VideoArgs  = @('-preset', 'p5', '-b:v', ('{0}k' -f $videoKbps), '-maxrate', ('{0}k' -f $videoKbps), '-bufsize', ('{0}k' -f $bufKbps), '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                    AudioCodec = 'aac'
                    AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
                }
                return [PSCustomObject]@{ Primary = $gpu; Fallback = $cpu }
            }
            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        '.m4v' {
            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'libx264'
                VideoArgs  = @('-preset', 'medium', '-b:v', ('{0}k' -f $videoKbps), '-maxrate', ('{0}k' -f $videoKbps), '-bufsize', ('{0}k' -f $bufKbps), '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                AudioCodec = 'aac'
                AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
            }
            if ($NvencAvailable) {
                $gpu = [PSCustomObject]@{
                    ModeLabel  = 'NVIDIA GPU'
                    VideoCodec = 'h264_nvenc'
                    VideoArgs  = @('-preset', 'p5', '-b:v', ('{0}k' -f $videoKbps), '-maxrate', ('{0}k' -f $videoKbps), '-bufsize', ('{0}k' -f $bufKbps), '-pix_fmt', 'yuv420p', '-movflags', '+faststart')
                    AudioCodec = 'aac'
                    AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
                }
                return [PSCustomObject]@{ Primary = $gpu; Fallback = $cpu }
            }
            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        '.avi' {
            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'mpeg4'
                VideoArgs  = @('-b:v', ('{0}k' -f $videoKbps))
                AudioCodec = 'libmp3lame'
                AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
            }
            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        '.webm' {
            $cpu = [PSCustomObject]@{
                ModeLabel  = 'CPU'
                VideoCodec = 'libvpx-vp9'
                VideoArgs  = @('-b:v', ('{0}k' -f $videoKbps), '-deadline', 'good', '-cpu-used', '2', '-row-mt', '1')
                AudioCodec = 'libopus'
                AudioArgs  = @('-b:a', ('{0}k' -f $audioKbps))
            }
            return [PSCustomObject]@{ Primary = $cpu; Fallback = $null }
        }
        default {
            throw 'Unsupported file format. Supported: .mp4, .mkv, .avi, .mov, .webm, .m4v'
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
        '-map', '0:v:0?',
        '-map', '0:a?',
        '-sn',
        '-dn',
        '-c:v', $EncodingProfile.VideoCodec
    )

    $ffmpegArgs += $EncodingProfile.VideoArgs
    $ffmpegArgs += @('-c:a', $EncodingProfile.AudioCodec)
    $ffmpegArgs += $EncodingProfile.AudioArgs
    $ffmpegArgs += @($OutputFile)

    return ,$ffmpegArgs
}

function Show-CompressVideoWindow {
    param(
        [Parameter(Mandatory = $true)][string]$SourceExtension,
        [Parameter(Mandatory = $true)][long]$SourceBytes,
        [Parameter(Mandatory = $true)]$VideoInfo
    )

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFActions - Compress video'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(520, 325)
    $form.TopMost = $true

    $labelInfo = New-Object System.Windows.Forms.Label
    $labelInfo.Location = New-Object System.Drawing.Point(18, 14)
    $labelInfo.Size = New-Object System.Drawing.Size(480, 40)
    $resolution = if ($VideoInfo.Width -gt 0 -and $VideoInfo.Height -gt 0) { "$($VideoInfo.Width)x$($VideoInfo.Height)" } else { 'unknown resolution' }
    $labelInfo.Text = "Source: $($SourceExtension.TrimStart('.').ToUpperInvariant())    Size: $(Format-FileSize $SourceBytes)    Video: $resolution"
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
    $labelPresetHint.Text = 'High quality keeps more detail, Small file reduces size more aggressively.'
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
    $labelTargetHint.Text = 'Best-effort target'
    $groupTarget.Controls.Add($labelTargetHint)

    $checkTarget.Add_CheckedChanged({
        $textTarget.Enabled = $checkTarget.Checked
        $comboUnit.Enabled = $checkTarget.Checked
    })

    $labelNote = New-Object System.Windows.Forms.Label
    $labelNote.Location = New-Object System.Drawing.Point(18, 250)
    $labelNote.Size = New-Object System.Drawing.Size(475, 30)
    $labelNote.Text = 'The compressed video is created next to the original file. The format stays the same.'
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

        if ($checkTarget.Checked) {
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
    $sourceInfo = Get-VideoInfo -FfprobePath $ffprobePath -FilePath $InputFile
}
catch {
    Show-ErrorAndExit $_.Exception.Message
}

$sourceBytes = (Get-Item -LiteralPath $InputFile).Length
$compressConfig = Show-CompressVideoWindow -SourceExtension $extension -SourceBytes $sourceBytes -VideoInfo $sourceInfo
if ($null -eq $compressConfig) {
    exit 0
}

$nvencAvailable = Test-NvencAvailable -FfmpegPath $ffmpegPath
if ($null -ne $compressConfig.TargetBytes) {
    $encodingPlan = Get-TargetEncodingPlan -Extension $extension -PresetKey $compressConfig.PresetKey -NvencAvailable $nvencAvailable -TargetBytes ([long]$compressConfig.TargetBytes) -DurationSeconds ([double]$sourceInfo.DurationSeconds)
}
else {
    $encodingPlan = Get-PresetEncodingPlan -Extension $extension -PresetKey $compressConfig.PresetKey -NvencAvailable $nvencAvailable
}

$inputDir = Split-Path -Parent $InputFile
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
$suffix = if ($null -ne $compressConfig.TargetBytes) { 'compress_target' } else { 'compress_' + (Get-PresetLabel -PresetKey $compressConfig.PresetKey) }
$desiredOutput = Join-Path $inputDir ("{0}_{1}{2}" -f $baseName, $suffix, $extension)
$script:OutputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

$result = Invoke-WithEncodingPlan -FfmpegPath $ffmpegPath -EncodingPlan $encodingPlan -DurationSeconds ([double]$sourceInfo.DurationSeconds) -Title 'Compress video' -PreparingText 'Preparing video compression...' -FallbackPreparingText 'GPU unavailable. Retrying in CPU mode...' -OutputFile $script:OutputFile -ArgumentFactory {
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
