param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile,
    [Parameter(Position = 1)]
    [string]$ProfileName
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Get-TargetFormatFromExeName {
    $exeName = [System.IO.Path]::GetFileNameWithoutExtension([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)

    switch ($exeName.ToLowerInvariant()) {
        'convert_to_mp4' { return '.mp4' }
        'convert_to_mkv' { return '.mkv' }
        'convert_to_avi' { return '.avi' }
        'convert_to_mov' { return '.mov' }
        'convert_to_webm' { return '.webm' }
        'convert_to_m4v' { return '.m4v' }
        default { throw 'Unknown conversion target. Expected convert_to_mp4.exe, convert_to_mkv.exe, convert_to_avi.exe, convert_to_mov.exe, convert_to_webm.exe or convert_to_m4v.exe.' }
    }
}

function Test-NvencAvailable([string]$FfmpegPath) {
    $probeResult = Invoke-HiddenProcess -FilePath $FfmpegPath -Arguments @('-hide_banner', '-encoders')
    if ($probeResult.ExitCode -ne 0) {
        return $false
    }

    $allText = ($probeResult.StdOut + "`r`n" + $probeResult.StdErr)
    return ($allText -match '(^|\s)h264_nvenc(\s|$)')
}

function New-EncodingPlanResult {
    param(
        [Parameter(Mandatory = $true)]$Primary,
        $Fallback = $null
    )

    return [PSCustomObject]@{
        Primary  = $Primary
        Fallback = $Fallback
    }
}

function New-RemuxEncodingPlan {
    param([Parameter(Mandatory = $true)][string]$TargetExtension)

    $globalArgs = @()
    if ($TargetExtension.ToLowerInvariant() -in @('.mp4', '.mov', '.m4v')) {
        $globalArgs = @('-movflags', '+faststart')
    }

    $profile = [PSCustomObject]@{
        ModeLabel  = 'Copy codecs'
        VideoCodec = 'copy'
        VideoArgs  = @()
        AudioCodec = 'copy'
        AudioArgs  = @()
        GlobalArgs = $globalArgs
    }

    return (New-EncodingPlanResult -Primary $profile)
}

function Get-ConversionProfileItems {
    $items = New-Object System.Collections.Generic.List[object]
    $items.Add([PSCustomObject]@{
        Id          = 'universal'
        Label       = 'Universal'
        Description = 'Default profile for most files.'
    })
    $items.Add([PSCustomObject]@{
        Id          = 'remux'
        Label       = 'Remux (copy codecs, fast)'
        Description = 'Fast copy without re-encoding.'
    })
    $items.Add([PSCustomObject]@{
        Id          = 'montage'
        Label       = 'Montage'
        Description = 'Higher quality for editing.'
    })
    $items.Add([PSCustomObject]@{
        Id          = 'youtube'
        Label       = 'Web / YouTube'
        Description = 'Balanced profile for upload.'
    })
    $items.Add([PSCustomObject]@{
        Id          = 'streaming'
        Label       = 'Streaming light'
        Description = 'Smaller files for sharing.'
    })
    $items.Add([PSCustomObject]@{
        Id          = 'tv'
        Label       = 'TV / USB'
        Description = 'Safer playback on TVs and USB.'
    })

    return $items.ToArray()
}

function Confirm-Continue {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$Title = 'FFActions - Warning'
    )

    $result = [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OKCancel,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    return ($result -eq [System.Windows.Forms.DialogResult]::OK)
}

function Test-ProfileTargetCompatibility {
    param(
        [Parameter(Mandatory = $true)][string]$TargetExtension,
        [Parameter(Mandatory = $true)][string]$ProfileName
    )

    $target = $TargetExtension.ToLowerInvariant()
    $profile = $ProfileName.ToLowerInvariant()

    if ($target -eq '.avi' -and $profile -in @('youtube', 'streaming')) {
        return 'This profile is not compatible with AVI output. Choose Universal, Montage, TV / USB, or another output format.'
    }

    if ($target -eq '.webm' -and $profile -eq 'tv') {
        return 'TV / USB is not compatible with WEBM output. Choose MP4, M4V, MKV, or another profile.'
    }

    if ($target -eq '.mov' -and $profile -eq 'tv') {
        return 'TV / USB is not compatible with MOV output. Choose MP4, M4V, MKV, or another profile.'
    }

    return $null
}

function Get-ProfileCompatibilityFallbackMessage {
    param(
        [Parameter(Mandatory = $true)][string]$TargetExtension,
        [Parameter(Mandatory = $true)][string]$ProfileName
    )

    $target = $TargetExtension.ToLowerInvariant()
    $profile = $ProfileName.ToLowerInvariant()

    if ($target -eq '.avi' -and $profile -in @('youtube', 'streaming')) {
        return 'This profile is not compatible with AVI output. FFActions can continue with Universal profile instead. Continue?'
    }

    if ($target -eq '.webm' -and $profile -eq 'tv') {
        return 'TV / USB profile is not compatible with WEBM output. FFActions can continue with Universal profile instead. Continue?'
    }

    if ($target -eq '.mov' -and $profile -eq 'tv') {
        return 'TV / USB profile is not compatible with MOV output. FFActions can continue with Universal profile instead. Continue?'
    }

    return $null
}

function Get-MediaStreamSummary {
    param(
        [Parameter(Mandatory = $true)][string]$FfprobePath,
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    $probeResult = Invoke-HiddenProcess -FilePath $FfprobePath -Arguments @(
        '-v', 'error',
        '-show_entries', 'stream=index,codec_type,codec_name',
        '-of', 'json',
        $FilePath
    )

    $audioCount = 0
    $subtitleCount = 0
    $dataCount = 0
    $textSubtitleIndexes = New-Object System.Collections.Generic.List[int]
    $imageSubtitleIndexes = New-Object System.Collections.Generic.List[int]
    $otherSubtitleIndexes = New-Object System.Collections.Generic.List[int]

    if ($probeResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($probeResult.StdOut)) {
        return [PSCustomObject]@{
            AudioCount           = 0
            SubtitleCount        = 0
            DataCount            = 0
            TextSubtitleIndexes  = @()
            ImageSubtitleIndexes = @()
            OtherSubtitleIndexes = @()
        }
    }

    try {
        $json = $probeResult.StdOut | ConvertFrom-Json
        foreach ($stream in @($json.streams)) {
            $codecType = [string]$stream.codec_type
            $codecName = ([string]$stream.codec_name).ToLowerInvariant()
            $index = [int]$stream.index

            if ($codecType -eq 'audio') {
                $audioCount++
            }
            elseif ($codecType -eq 'subtitle') {
                $subtitleCount++
                if ($codecName -in @('subrip', 'ass', 'ssa', 'webvtt', 'mov_text', 'text')) {
                    $textSubtitleIndexes.Add($index)
                }
                elseif ($codecName -in @('hdmv_pgs_subtitle', 'dvd_subtitle', 'dvb_subtitle', 'xsub')) {
                    $imageSubtitleIndexes.Add($index)
                }
                else {
                    $otherSubtitleIndexes.Add($index)
                }
            }
            elseif ($codecType -eq 'data' -or $codecType -eq 'attachment') {
                $dataCount++
            }
        }
    }
    catch {
        # If stream probing fails, conversion can still proceed with conservative mapping.
    }

    return [PSCustomObject]@{
        AudioCount           = $audioCount
        SubtitleCount        = $subtitleCount
        DataCount            = $dataCount
        TextSubtitleIndexes  = @($textSubtitleIndexes.ToArray())
        ImageSubtitleIndexes = @($imageSubtitleIndexes.ToArray())
        OtherSubtitleIndexes = @($otherSubtitleIndexes.ToArray())
    }
}

function Get-VideoCodecName {
    param(
        [Parameter(Mandatory = $true)][string]$FfprobePath,
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    $probeResult = Invoke-HiddenProcess -FilePath $FfprobePath -Arguments @(
        '-v', 'error',
        '-select_streams', 'v:0',
        '-show_entries', 'stream=codec_name',
        '-of', 'default=nokey=1:noprint_wrappers=1',
        $FilePath
    )

    if ($probeResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($probeResult.StdOut)) {
        return $null
    }

    return (($probeResult.StdOut -split "`r?`n" | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1).Trim().ToLowerInvariant())
}

function Get-AudioCodecNames {
    param(
        [Parameter(Mandatory = $true)][string]$FfprobePath,
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    $probeResult = Invoke-HiddenProcess -FilePath $FfprobePath -Arguments @(
        '-v', 'error',
        '-select_streams', 'a',
        '-show_entries', 'stream=codec_name',
        '-of', 'default=nokey=1:noprint_wrappers=1',
        $FilePath
    )

    if ($probeResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($probeResult.StdOut)) {
        return @()
    }

    return @(
        $probeResult.StdOut -split "`r?`n" |
            Where-Object { $_.Trim() -ne '' } |
            ForEach-Object { $_.Trim().ToLowerInvariant() }
    )
}

function Get-SubtitleCodecNames {
    param(
        [Parameter(Mandatory = $true)][string]$FfprobePath,
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    $probeResult = Invoke-HiddenProcess -FilePath $FfprobePath -Arguments @(
        '-v', 'error',
        '-select_streams', 's',
        '-show_entries', 'stream=codec_name',
        '-of', 'default=nokey=1:noprint_wrappers=1',
        $FilePath
    )

    if ($probeResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($probeResult.StdOut)) {
        return @()
    }

    return @(
        $probeResult.StdOut -split "`r?`n" |
            Where-Object { $_.Trim() -ne '' } |
            ForEach-Object { $_.Trim().ToLowerInvariant() }
    )
}

function Test-RemuxCompatibility {
    param(
        [Parameter(Mandatory = $true)][string]$TargetExtension,
        [Parameter(Mandatory = $true)][string]$FfprobePath,
        [Parameter(Mandatory = $true)][string]$InputFile
    )

    $target = $TargetExtension.ToLowerInvariant()
    $videoCodec = Get-VideoCodecName -FfprobePath $FfprobePath -FilePath $InputFile
    $audioCodecs = @(Get-AudioCodecNames -FfprobePath $FfprobePath -FilePath $InputFile)
    $subtitleCodecs = @(Get-SubtitleCodecNames -FfprobePath $FfprobePath -FilePath $InputFile)

    if ($target -eq '.webm') {
        if ($videoCodec -and $videoCodec -notin @('vp8', 'vp9', 'av1')) {
            return "Remux to WEBM is not possible: video codec '$videoCodec' is not WEBM-compatible."
        }

        foreach ($codec in $audioCodecs) {
            if ($codec -notin @('opus', 'vorbis')) {
                return "Remux to WEBM is not possible: audio codec '$codec' is not WEBM-compatible."
            }
        }

        foreach ($codec in $subtitleCodecs) {
            if ($codec -notin @('webvtt')) {
                return "Remux to WEBM is not possible: subtitle codec '$codec' is not WEBM-compatible."
            }
        }
    }
    elseif ($target -in @('.mp4', '.m4v')) {
        if ($videoCodec -and $videoCodec -notin @('h264', 'hevc', 'av1', 'mpeg4')) {
            return "Remux to $($target.TrimStart('.').ToUpperInvariant()) is not possible: video codec '$videoCodec' is not compatible."
        }
    }

    return $null
}

function New-StreamRetentionPlan {
    param(
        [Parameter(Mandatory = $true)][string]$TargetExtension,
        [Parameter(Mandatory = $true)]$StreamSummary
    )

    $target = $TargetExtension.ToLowerInvariant()
    $mapArgs = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]
    $subtitleCodecArgs = @()

    $mapArgs.Add('-map')
    $mapArgs.Add('0:v:0?')
    $mapArgs.Add('-map')
    $mapArgs.Add('0:a?')

    if ($target -eq '.mkv') {
        $mapArgs.Add('-map')
        $mapArgs.Add('0:s?')
        $subtitleCodecArgs = @('-c:s', 'copy')
    }
    elseif ($target -in @('.mp4', '.m4v', '.mov')) {
        foreach ($index in @($StreamSummary.TextSubtitleIndexes)) {
            $mapArgs.Add('-map')
            $mapArgs.Add("0:$index")
        }

        if (@($StreamSummary.TextSubtitleIndexes).Count -gt 0) {
            $subtitleCodecArgs = @('-c:s', 'mov_text')
        }

        $lostCount = @($StreamSummary.ImageSubtitleIndexes).Count + @($StreamSummary.OtherSubtitleIndexes).Count
        if ($lostCount -gt 0) {
            $warnings.Add('Some subtitles are not compatible with this output format and will be removed.')
        }
    }
    elseif ($target -eq '.webm') {
        foreach ($index in @($StreamSummary.TextSubtitleIndexes)) {
            $mapArgs.Add('-map')
            $mapArgs.Add("0:$index")
        }

        if (@($StreamSummary.TextSubtitleIndexes).Count -gt 0) {
            $subtitleCodecArgs = @('-c:s', 'webvtt')
        }

        $lostCount = @($StreamSummary.ImageSubtitleIndexes).Count + @($StreamSummary.OtherSubtitleIndexes).Count
        if ($lostCount -gt 0) {
            $warnings.Add('Some subtitles are not compatible with WEBM and will be removed.')
        }
    }
    elseif ($target -eq '.avi') {
        if ($StreamSummary.SubtitleCount -gt 0) {
            $warnings.Add('Subtitles cannot be kept in AVI output and will be removed.')
        }
    }

    if ($StreamSummary.DataCount -gt 0) {
        $warnings.Add('Extra data streams or attachments will be removed.')
    }

    return [PSCustomObject]@{
        MapArgs           = @($mapArgs.ToArray())
        SubtitleCodecArgs = @($subtitleCodecArgs)
        Warnings          = @($warnings.ToArray())
    }
}

function Show-ConversionProfilePicker {
    param(
        [Parameter(Mandatory = $true)][string]$TargetExtension
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFActions - Conversion Profile'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(420, 182)

    $labelTitle = New-Object System.Windows.Forms.Label
    $labelTitle.Location = New-Object System.Drawing.Point(16, 16)
    $labelTitle.Size = New-Object System.Drawing.Size(388, 20)
    $labelTitle.Text = "Output format: $($TargetExtension.TrimStart('.').ToUpperInvariant())"

    $labelHelp = New-Object System.Windows.Forms.Label
    $labelHelp.Location = New-Object System.Drawing.Point(16, 42)
    $labelHelp.Size = New-Object System.Drawing.Size(388, 32)
    $labelHelp.Text = 'Choose the conversion profile. Universal uses container-friendly codecs for broad compatibility.'

    $labelProfile = New-Object System.Windows.Forms.Label
    $labelProfile.Location = New-Object System.Drawing.Point(16, 84)
    $labelProfile.Size = New-Object System.Drawing.Size(80, 20)
    $labelProfile.Text = 'Profile:'

    $comboProfile = New-Object System.Windows.Forms.ComboBox
    $comboProfile.Location = New-Object System.Drawing.Point(100, 81)
    $comboProfile.Size = New-Object System.Drawing.Size(304, 24)
    $comboProfile.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $profileItems = @(Get-ConversionProfileItems)
    foreach ($profileItem in $profileItems) {
        [void]$comboProfile.Items.Add($profileItem.Label)
    }
    $comboProfile.SelectedIndex = 0

    $labelDescription = New-Object System.Windows.Forms.Label
    $labelDescription.Location = New-Object System.Drawing.Point(16, 114)
    $labelDescription.Size = New-Object System.Drawing.Size(388, 22)
    $labelDescription.Text = $profileItems[0].Description

    $comboProfile.Add_SelectedIndexChanged({
        if ($comboProfile.SelectedIndex -ge 0 -and $comboProfile.SelectedIndex -lt $profileItems.Count) {
            $labelDescription.Text = $profileItems[$comboProfile.SelectedIndex].Description
        }
    })

    $buttonOk = New-Object System.Windows.Forms.Button
    $buttonOk.Location = New-Object System.Drawing.Point(248, 144)
    $buttonOk.Size = New-Object System.Drawing.Size(75, 28)
    $buttonOk.Text = 'Convert'
    $buttonOk.DialogResult = [System.Windows.Forms.DialogResult]::OK

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Location = New-Object System.Drawing.Point(329, 144)
    $buttonCancel.Size = New-Object System.Drawing.Size(75, 28)
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    $form.Controls.AddRange(@(
        $labelTitle,
        $labelHelp,
        $labelProfile,
        $comboProfile,
        $labelDescription,
        $buttonOk,
        $buttonCancel
    ))
    $form.AcceptButton = $buttonOk
    $form.CancelButton = $buttonCancel

    $dialogResult = $form.ShowDialog()
    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK) {
        return $null
    }

    if ($comboProfile.SelectedIndex -ge 0 -and $comboProfile.SelectedIndex -lt $profileItems.Count) {
        return [string]$profileItems[$comboProfile.SelectedIndex].Id
    }

    return [string]$profileItems[0].Id
}

function New-StandardEncodingPlan {
    param(
        [Parameter(Mandatory = $true)][string]$TargetExtension,
        [Parameter(Mandatory = $true)][string]$ProfileName,
        [Parameter(Mandatory = $true)][bool]$NvencAvailable
    )

    switch ($TargetExtension.ToLowerInvariant()) {
        '.mp4' {
            switch ($ProfileName) {
                'montage' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libx264'
                        VideoArgs  = @('-preset', 'medium', '-crf', '14', '-g', '1', '-pix_fmt', 'yuv420p')
                        AudioCodec = 'aac'
                        AudioArgs  = @('-b:a', '320k')
                        GlobalArgs = @('-movflags', '+faststart')
                    }

                    if ($NvencAvailable) {
                        $gpu = [PSCustomObject]@{
                            ModeLabel  = 'NVIDIA GPU'
                            VideoCodec = 'h264_nvenc'
                            VideoArgs  = @('-preset', 'p5', '-cq', '17', '-g', '1', '-pix_fmt', 'yuv420p')
                            AudioCodec = 'aac'
                            AudioArgs  = @('-b:a', '320k')
                            GlobalArgs = @('-movflags', '+faststart')
                        }

                        return (New-EncodingPlanResult -Primary $gpu -Fallback $cpu)
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
                'youtube' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libx264'
                        VideoArgs  = @('-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p')
                        AudioCodec = 'aac'
                        AudioArgs  = @('-b:a', '320k')
                        GlobalArgs = @('-movflags', '+faststart')
                    }

                    if ($NvencAvailable) {
                        $gpu = [PSCustomObject]@{
                            ModeLabel  = 'NVIDIA GPU'
                            VideoCodec = 'h264_nvenc'
                            VideoArgs  = @('-preset', 'p5', '-cq', '19', '-pix_fmt', 'yuv420p')
                            AudioCodec = 'aac'
                            AudioArgs  = @('-b:a', '320k')
                            GlobalArgs = @('-movflags', '+faststart')
                        }

                        return (New-EncodingPlanResult -Primary $gpu -Fallback $cpu)
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
                'streaming' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libx264'
                        VideoArgs  = @('-preset', 'medium', '-crf', '23', '-pix_fmt', 'yuv420p')
                        AudioCodec = 'aac'
                        AudioArgs  = @('-b:a', '160k')
                        GlobalArgs = @('-movflags', '+faststart')
                    }

                    if ($NvencAvailable) {
                        $gpu = [PSCustomObject]@{
                            ModeLabel  = 'NVIDIA GPU'
                            VideoCodec = 'h264_nvenc'
                            VideoArgs  = @('-preset', 'p5', '-cq', '24', '-pix_fmt', 'yuv420p')
                            AudioCodec = 'aac'
                            AudioArgs  = @('-b:a', '160k')
                            GlobalArgs = @('-movflags', '+faststart')
                        }

                        return (New-EncodingPlanResult -Primary $gpu -Fallback $cpu)
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
                'tv' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libx264'
                        VideoArgs  = @('-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-level', '4.1')
                        AudioCodec = 'aac'
                        AudioArgs  = @('-b:a', '192k')
                        GlobalArgs = @('-movflags', '+faststart')
                    }

                    if ($NvencAvailable) {
                        $gpu = [PSCustomObject]@{
                            ModeLabel  = 'NVIDIA GPU'
                            VideoCodec = 'h264_nvenc'
                            VideoArgs  = @('-preset', 'p5', '-cq', '21', '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-level', '4.1')
                            AudioCodec = 'aac'
                            AudioArgs  = @('-b:a', '192k')
                            GlobalArgs = @('-movflags', '+faststart')
                        }

                        return (New-EncodingPlanResult -Primary $gpu -Fallback $cpu)
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
                default {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libx264'
                        VideoArgs  = @('-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p')
                        AudioCodec = 'aac'
                        AudioArgs  = @('-b:a', '320k')
                        GlobalArgs = @('-movflags', '+faststart')
                    }

                    if ($NvencAvailable) {
                        $gpu = [PSCustomObject]@{
                            ModeLabel  = 'NVIDIA GPU'
                            VideoCodec = 'h264_nvenc'
                            VideoArgs  = @('-preset', 'p5', '-cq', '21', '-pix_fmt', 'yuv420p')
                            AudioCodec = 'aac'
                            AudioArgs  = @('-b:a', '320k')
                            GlobalArgs = @('-movflags', '+faststart')
                        }

                        return (New-EncodingPlanResult -Primary $gpu -Fallback $cpu)
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
            }
        }
        '.mkv' {
            switch ($ProfileName) {
                'montage' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libx264'
                        VideoArgs  = @('-preset', 'medium', '-crf', '14', '-pix_fmt', 'yuv420p')
                        AudioCodec = 'flac'
                        AudioArgs  = @()
                        GlobalArgs = @()
                    }

                    if ($NvencAvailable) {
                        $gpu = [PSCustomObject]@{
                            ModeLabel  = 'NVIDIA GPU'
                            VideoCodec = 'h264_nvenc'
                            VideoArgs  = @('-preset', 'p5', '-cq', '17', '-pix_fmt', 'yuv420p')
                            AudioCodec = 'pcm_s16le'
                            AudioArgs  = @()
                            GlobalArgs = @()
                        }

                        $cpuFallback = [PSCustomObject]@{
                            ModeLabel  = 'CPU'
                            VideoCodec = 'libx264'
                            VideoArgs  = @('-preset', 'medium', '-crf', '14', '-pix_fmt', 'yuv420p')
                            AudioCodec = 'pcm_s16le'
                            AudioArgs  = @()
                            GlobalArgs = @()
                        }

                        return (New-EncodingPlanResult -Primary $gpu -Fallback $cpuFallback)
                    }

                    $cpu.AudioCodec = 'pcm_s16le'
                    return (New-EncodingPlanResult -Primary $cpu)
                }
                'youtube' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libx264'
                        VideoArgs  = @('-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p')
                        AudioCodec = 'aac'
                        AudioArgs  = @('-b:a', '320k')
                        GlobalArgs = @()
                    }

                    if ($NvencAvailable) {
                        $gpu = [PSCustomObject]@{
                            ModeLabel  = 'NVIDIA GPU'
                            VideoCodec = 'h264_nvenc'
                            VideoArgs  = @('-preset', 'p5', '-cq', '19', '-pix_fmt', 'yuv420p')
                            AudioCodec = 'aac'
                            AudioArgs  = @('-b:a', '320k')
                            GlobalArgs = @()
                        }

                        return (New-EncodingPlanResult -Primary $gpu -Fallback $cpu)
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
                'streaming' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libx264'
                        VideoArgs  = @('-preset', 'medium', '-crf', '23', '-pix_fmt', 'yuv420p')
                        AudioCodec = 'libopus'
                        AudioArgs  = @('-b:a', '128k')
                        GlobalArgs = @()
                    }

                    if ($NvencAvailable) {
                        $gpu = [PSCustomObject]@{
                            ModeLabel  = 'NVIDIA GPU'
                            VideoCodec = 'h264_nvenc'
                            VideoArgs  = @('-preset', 'p5', '-cq', '24', '-pix_fmt', 'yuv420p')
                            AudioCodec = 'libopus'
                            AudioArgs  = @('-b:a', '128k')
                            GlobalArgs = @()
                        }

                        return (New-EncodingPlanResult -Primary $gpu -Fallback $cpu)
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
                'tv' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libx264'
                        VideoArgs  = @('-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-level', '4.1')
                        AudioCodec = 'aac'
                        AudioArgs  = @('-b:a', '192k')
                        GlobalArgs = @()
                    }

                    if ($NvencAvailable) {
                        $gpu = [PSCustomObject]@{
                            ModeLabel  = 'NVIDIA GPU'
                            VideoCodec = 'h264_nvenc'
                            VideoArgs  = @('-preset', 'p5', '-cq', '21', '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-level', '4.1')
                            AudioCodec = 'aac'
                            AudioArgs  = @('-b:a', '192k')
                            GlobalArgs = @()
                        }

                        return (New-EncodingPlanResult -Primary $gpu -Fallback $cpu)
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
                default {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libx264'
                        VideoArgs  = @('-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p')
                        AudioCodec = 'libopus'
                        AudioArgs  = @('-b:a', '192k')
                        GlobalArgs = @()
                    }

                    if ($NvencAvailable) {
                        $gpu = [PSCustomObject]@{
                            ModeLabel  = 'NVIDIA GPU'
                            VideoCodec = 'h264_nvenc'
                            VideoArgs  = @('-preset', 'p5', '-cq', '21', '-pix_fmt', 'yuv420p')
                            AudioCodec = 'libopus'
                            AudioArgs  = @('-b:a', '192k')
                            GlobalArgs = @()
                        }

                        return (New-EncodingPlanResult -Primary $gpu -Fallback $cpu)
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
            }
        }
        '.avi' {
            switch ($ProfileName) {
                'montage' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'mpeg4'
                        VideoArgs  = @('-q:v', '1', '-vtag', 'XVID')
                        AudioCodec = 'pcm_s16le'
                        AudioArgs  = @()
                        GlobalArgs = @()
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
                'youtube' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'mpeg4'
                        VideoArgs  = @('-q:v', '2', '-vtag', 'XVID')
                        AudioCodec = 'libmp3lame'
                        AudioArgs  = @('-b:a', '192k')
                        GlobalArgs = @()
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
                'streaming' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'mpeg4'
                        VideoArgs  = @('-q:v', '5', '-vtag', 'XVID')
                        AudioCodec = 'libmp3lame'
                        AudioArgs  = @('-b:a', '128k')
                        GlobalArgs = @()
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
                'tv' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'mpeg4'
                        VideoArgs  = @('-q:v', '2', '-vtag', 'XVID')
                        AudioCodec = 'pcm_s16le'
                        AudioArgs  = @()
                        GlobalArgs = @()
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
                default {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'mpeg4'
                        VideoArgs  = @('-q:v', '2', '-vtag', 'XVID')
                        AudioCodec = 'pcm_s16le'
                        AudioArgs  = @()
                        GlobalArgs = @()
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
            }
        }
        '.mov' {
            switch ($ProfileName) {
                'montage' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libx264'
                        VideoArgs  = @('-preset', 'medium', '-crf', '16', '-pix_fmt', 'yuv420p')
                        AudioCodec = 'pcm_s16le'
                        AudioArgs  = @()
                        GlobalArgs = @('-movflags', '+faststart')
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
                'youtube' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libx264'
                        VideoArgs  = @('-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p')
                        AudioCodec = 'aac'
                        AudioArgs  = @('-b:a', '320k')
                        GlobalArgs = @('-movflags', '+faststart')
                    }

                    if ($NvencAvailable) {
                        $gpu = [PSCustomObject]@{
                            ModeLabel  = 'NVIDIA GPU'
                            VideoCodec = 'h264_nvenc'
                            VideoArgs  = @('-preset', 'p5', '-cq', '19', '-pix_fmt', 'yuv420p')
                            AudioCodec = 'aac'
                            AudioArgs  = @('-b:a', '320k')
                            GlobalArgs = @('-movflags', '+faststart')
                        }

                        return (New-EncodingPlanResult -Primary $gpu -Fallback $cpu)
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
                'streaming' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libx264'
                        VideoArgs  = @('-preset', 'medium', '-crf', '23', '-pix_fmt', 'yuv420p')
                        AudioCodec = 'aac'
                        AudioArgs  = @('-b:a', '160k')
                        GlobalArgs = @('-movflags', '+faststart')
                    }

                    if ($NvencAvailable) {
                        $gpu = [PSCustomObject]@{
                            ModeLabel  = 'NVIDIA GPU'
                            VideoCodec = 'h264_nvenc'
                            VideoArgs  = @('-preset', 'p5', '-cq', '24', '-pix_fmt', 'yuv420p')
                            AudioCodec = 'aac'
                            AudioArgs  = @('-b:a', '160k')
                            GlobalArgs = @('-movflags', '+faststart')
                        }

                        return (New-EncodingPlanResult -Primary $gpu -Fallback $cpu)
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
                'tv' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libx264'
                        VideoArgs  = @('-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-level', '4.1')
                        AudioCodec = 'aac'
                        AudioArgs  = @('-b:a', '192k')
                        GlobalArgs = @('-movflags', '+faststart')
                    }

                    if ($NvencAvailable) {
                        $gpu = [PSCustomObject]@{
                            ModeLabel  = 'NVIDIA GPU'
                            VideoCodec = 'h264_nvenc'
                            VideoArgs  = @('-preset', 'p5', '-cq', '21', '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-level', '4.1')
                            AudioCodec = 'aac'
                            AudioArgs  = @('-b:a', '192k')
                            GlobalArgs = @('-movflags', '+faststart')
                        }

                        return (New-EncodingPlanResult -Primary $gpu -Fallback $cpu)
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
                default {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libx264'
                        VideoArgs  = @('-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p')
                        AudioCodec = 'aac'
                        AudioArgs  = @('-b:a', '320k')
                        GlobalArgs = @('-movflags', '+faststart')
                    }

                    if ($NvencAvailable) {
                        $gpu = [PSCustomObject]@{
                            ModeLabel  = 'NVIDIA GPU'
                            VideoCodec = 'h264_nvenc'
                            VideoArgs  = @('-preset', 'p5', '-cq', '21', '-pix_fmt', 'yuv420p')
                            AudioCodec = 'aac'
                            AudioArgs  = @('-b:a', '320k')
                            GlobalArgs = @('-movflags', '+faststart')
                        }

                        return (New-EncodingPlanResult -Primary $gpu -Fallback $cpu)
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
            }
        }
        '.webm' {
            switch ($ProfileName) {
                'montage' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libvpx-vp9'
                        VideoArgs  = @('-crf', '18', '-b:v', '0', '-deadline', 'good', '-cpu-used', '1', '-row-mt', '1')
                        AudioCodec = 'libopus'
                        AudioArgs  = @('-b:a', '256k')
                        GlobalArgs = @()
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
                'youtube' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libvpx-vp9'
                        VideoArgs  = @('-crf', '28', '-b:v', '0', '-deadline', 'good', '-cpu-used', '2', '-row-mt', '1')
                        AudioCodec = 'libopus'
                        AudioArgs  = @('-b:a', '192k')
                        GlobalArgs = @()
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
                'streaming' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libvpx-vp9'
                        VideoArgs  = @('-crf', '34', '-b:v', '0', '-deadline', 'good', '-cpu-used', '3', '-row-mt', '1')
                        AudioCodec = 'libopus'
                        AudioArgs  = @('-b:a', '128k')
                        GlobalArgs = @()
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
                'tv' {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libvpx-vp9'
                        VideoArgs  = @('-crf', '30', '-b:v', '0', '-deadline', 'good', '-cpu-used', '2', '-row-mt', '1')
                        AudioCodec = 'libopus'
                        AudioArgs  = @('-b:a', '160k')
                        GlobalArgs = @()
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
                default {
                    $cpu = [PSCustomObject]@{
                        ModeLabel  = 'CPU'
                        VideoCodec = 'libvpx-vp9'
                        VideoArgs  = @('-crf', '31', '-b:v', '0', '-deadline', 'good', '-cpu-used', '2', '-row-mt', '1')
                        AudioCodec = 'libopus'
                        AudioArgs  = @('-b:a', '192k')
                        GlobalArgs = @()
                    }

                    return (New-EncodingPlanResult -Primary $cpu)
                }
            }
        }
        '.m4v' {
            if ($ProfileName -eq 'montage') {
                $cpu = [PSCustomObject]@{
                    ModeLabel  = 'CPU'
                    VideoCodec = 'libx264'
                    VideoArgs  = @('-preset', 'medium', '-crf', '16', '-pix_fmt', 'yuv420p')
                    AudioCodec = 'aac'
                    AudioArgs  = @('-b:a', '320k')
                    GlobalArgs = @('-movflags', '+faststart')
                }

                return (New-EncodingPlanResult -Primary $cpu)
            }

            return (New-StandardEncodingPlan -TargetExtension '.mp4' -ProfileName $ProfileName -NvencAvailable $NvencAvailable)
        }
        default {
            throw 'Unsupported target format. Only .mp4, .mkv, .avi, .mov, .webm and .m4v are supported.'
        }
    }
}

function Get-PreparingText {
    param(
        [Parameter(Mandatory = $true)][string]$ProfileName,
        [Parameter(Mandatory = $true)][string]$TargetLabel
    )

    switch ($ProfileName.ToLowerInvariant()) {
        'remux' { return "Preparing remux to $TargetLabel..." }
        'montage' { return "Preparing montage conversion to $TargetLabel..." }
        'youtube' { return "Preparing web conversion to $TargetLabel..." }
        'streaming' { return "Preparing streaming conversion to $TargetLabel..." }
        'tv' { return "Preparing TV-compatible conversion to $TargetLabel..." }
        default { return "Preparing universal conversion to $TargetLabel..." }
    }
}

function Get-EncodingPlan([string]$TargetExtension, [string]$ProfileName, [bool]$NvencAvailable) {
    switch ($ProfileName.ToLowerInvariant()) {
        'remux' {
            return (New-RemuxEncodingPlan -TargetExtension $TargetExtension)
        }
        'universal' { return (New-StandardEncodingPlan -TargetExtension $TargetExtension -ProfileName 'universal' -NvencAvailable $NvencAvailable) }
        'montage' { return (New-StandardEncodingPlan -TargetExtension $TargetExtension -ProfileName 'montage' -NvencAvailable $NvencAvailable) }
        'youtube' { return (New-StandardEncodingPlan -TargetExtension $TargetExtension -ProfileName 'youtube' -NvencAvailable $NvencAvailable) }
        'streaming' { return (New-StandardEncodingPlan -TargetExtension $TargetExtension -ProfileName 'streaming' -NvencAvailable $NvencAvailable) }
        'tv' { return (New-StandardEncodingPlan -TargetExtension $TargetExtension -ProfileName 'tv' -NvencAvailable $NvencAvailable) }
        default {
            throw 'Unsupported conversion profile.'
        }
    }
}

function New-FFmpegArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)]$EncodingProfile,
        [Parameter(Mandatory = $true)]$StreamPlan
    )

    $ffmpegArgs = @(
        '-hide_banner',
        '-loglevel', 'error',
        '-progress', 'pipe:1',
        '-nostats',
        '-y',
        '-i', $InputFile
    )

    $ffmpegArgs += $StreamPlan.MapArgs
    $ffmpegArgs += @(
        '-dn',
        '-c:v', $EncodingProfile.VideoCodec
    )

    $ffmpegArgs += $EncodingProfile.VideoArgs
    $ffmpegArgs += @('-c:a', $EncodingProfile.AudioCodec)
    $ffmpegArgs += $EncodingProfile.AudioArgs
    if ($StreamPlan.PSObject.Properties['SubtitleCodecArgs'] -and $StreamPlan.SubtitleCodecArgs) {
        $ffmpegArgs += $StreamPlan.SubtitleCodecArgs
    }
    if ($EncodingProfile.PSObject.Properties['GlobalArgs'] -and $EncodingProfile.GlobalArgs) {
        $ffmpegArgs += $EncodingProfile.GlobalArgs
    }
    $ffmpegArgs += @($OutputFile)

    return ,$ffmpegArgs
}

#__FFCOMMON_INJECT_HERE__

try {
    if ([string]::IsNullOrWhiteSpace($InputFile)) {
        Show-Error 'Input file is missing.'
        exit 1
    }

    if (-not (Test-Path -LiteralPath $InputFile)) {
        Show-Error 'Input file not found.'
        exit 1
    }

    $sourceExtension = [System.IO.Path]::GetExtension($InputFile).ToLowerInvariant()
    if ($sourceExtension -notin @('.mp4', '.mkv', '.avi', '.mov', '.webm', '.m4v')) {
        Show-Error 'Unsupported input format. Only .mp4, .mkv, .avi, .mov, .webm and .m4v are supported.'
        exit 1
    }

    $targetExtension = Get-TargetFormatFromExeName
    if ($targetExtension -eq $sourceExtension) {
        Show-Error 'Source and target formats must be different.'
        exit 1
    }

    $selectedProfile = $ProfileName
    if (-not [string]::IsNullOrWhiteSpace($selectedProfile)) {
        $selectedProfile = $selectedProfile.Trim().ToLowerInvariant()
    }
    else {
        $selectedProfile = Show-ConversionProfilePicker -TargetExtension $targetExtension
    }

    if ([string]::IsNullOrWhiteSpace($selectedProfile)) {
        exit 0
    }

    $compatibilityError = Test-ProfileTargetCompatibility -TargetExtension $targetExtension -ProfileName $selectedProfile
    if (-not [string]::IsNullOrWhiteSpace($compatibilityError)) {
        $compatibilityFallback = Get-ProfileCompatibilityFallbackMessage -TargetExtension $targetExtension -ProfileName $selectedProfile
        if ([string]::IsNullOrWhiteSpace($compatibilityFallback)) {
            Show-Error $compatibilityError
            exit 1
        }

        if (-not (Confirm-Continue -Message $compatibilityFallback -Title 'FFActions - Fallback to Universal')) {
            exit 0
        }

        $selectedProfile = 'universal'
    }

    $ffmpeg = Get-ToolPath 'ffmpeg.exe'
    $ffprobe = Get-ToolPath 'ffprobe.exe'

    if (-not (Test-Path -LiteralPath $ffmpeg)) {
        Show-Error 'ffmpeg.exe not found.'
        exit 1
    }

    if (-not (Test-Path -LiteralPath $ffprobe)) {
        Show-Error 'ffprobe.exe not found.'
        exit 1
    }

    if ($selectedProfile -eq 'remux') {
        $remuxError = Test-RemuxCompatibility -TargetExtension $targetExtension -FfprobePath $ffprobe -InputFile $InputFile
        if (-not [string]::IsNullOrWhiteSpace($remuxError)) {
            $fallbackText = "$remuxError`r`n`r`nFFActions can continue with Universal profile instead. Continue?"
            if (-not (Confirm-Continue -Message $fallbackText -Title 'FFActions - Fallback to Universal')) {
                exit 0
            }
            $selectedProfile = 'universal'
        }
    }

    $nvencAvailable = Test-NvencAvailable -FfmpegPath $ffmpeg
    $encodingPlan = Get-EncodingPlan -TargetExtension $targetExtension -ProfileName $selectedProfile -NvencAvailable $nvencAvailable
    $videoInfo = Get-VideoInfo -FfprobePath $ffprobe -FilePath $InputFile
    $totalDuration = [double]$videoInfo.DurationSeconds
    $streamSummary = Get-MediaStreamSummary -FfprobePath $ffprobe -FilePath $InputFile
    $streamPlan = New-StreamRetentionPlan -TargetExtension $targetExtension -StreamSummary $streamSummary

    if ($streamPlan.Warnings -and @($streamPlan.Warnings).Count -gt 0) {
        $warningText = ($streamPlan.Warnings | Select-Object -Unique) -join "`r`n"
        if (-not (Confirm-Continue -Message ("Some streams cannot be preserved:`r`n`r`n{0}`r`n`r`nContinue conversion?" -f $warningText))) {
            exit 0
        }
    }

    $inputDir = Split-Path -Parent $InputFile
    $inputBase = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $targetLabel = $targetExtension.TrimStart('.')
    $desiredOutput = Join-Path $inputDir ("{0}_convert_{1}{2}" -f $inputBase, $targetLabel, $targetExtension)
    $script:OutputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

    $preparingText = Get-PreparingText -ProfileName $selectedProfile -TargetLabel $targetLabel

    $result = Invoke-WithEncodingPlan -FfmpegPath $ffmpeg -EncodingPlan $encodingPlan -DurationSeconds $totalDuration -Title 'Conversion in progress' -PreparingText $preparingText -FallbackPreparingText 'GPU unavailable. Retrying in CPU mode...' -OutputFile $script:OutputFile -ArgumentFactory {
        param($profile)
        New-FFmpegArguments -InputFile $InputFile -OutputFile $script:OutputFile -EncodingProfile $profile -StreamPlan $streamPlan
    }

    if ($result.Cancelled) {
        Remove-PartialOutput -Path $script:OutputFile
        exit 0
    }

    if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $script:OutputFile)) {
        Remove-PartialOutput -Path $script:OutputFile
        Show-Error (Get-ShortErrorText -StdErr $result.StdErr)
        exit 1
    }

    exit 0
}
catch {
    $message = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($message)) { $message = 'Unknown conversion error.' }
    Show-Error $message
    exit 1
}
