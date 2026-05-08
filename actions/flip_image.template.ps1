param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Get-TransformConfig {
    param([string[]]$Keys)

    if ($null -eq $Keys -or $Keys.Count -eq 0) {
        throw 'No image transform selected.'
    }

    $filters = New-Object System.Collections.Generic.List[string]
    foreach ($key in $Keys) {
        switch ($key) {
            'rotate90'  { $filters.Add('transpose=1') | Out-Null }
            'rotate270' { $filters.Add('transpose=2') | Out-Null }
            'flip_h'    { $filters.Add('hflip') | Out-Null }
            'flip_v'    { $filters.Add('vflip') | Out-Null }
            default     { throw 'Unknown image transform.' }
        }
    }

    return [PSCustomObject]@{
        Filter = ($filters -join ',')
        Label  = ($Keys -join '_')
    }
}

function Get-RotateFlipType {
    param(
        [Parameter(Mandatory = $true)][int]$QuarterTurns,
        [Parameter(Mandatory = $true)][bool]$FlipHorizontal,
        [Parameter(Mandatory = $true)][bool]$FlipVertical
    )

    $turn = (($QuarterTurns % 4) + 4) % 4
    $suffix = if ($FlipHorizontal -and $FlipVertical) {
        'XY'
    }
    elseif ($FlipHorizontal) {
        'X'
    }
    elseif ($FlipVertical) {
        'Y'
    }
    else {
        'None'
    }

    $name = switch ($turn) {
        1 { "Rotate90Flip${suffix}" }
        2 { "Rotate180Flip${suffix}" }
        3 { "Rotate270Flip${suffix}" }
        default { "RotateNoneFlip${suffix}" }
    }

    return [System.Drawing.RotateFlipType]::$name
}

function Get-TransformSummary {
    param(
        [Parameter(Mandatory = $true)][int]$QuarterTurns,
        [Parameter(Mandatory = $true)][bool]$FlipHorizontal,
        [Parameter(Mandatory = $true)][bool]$FlipVertical
    )

    $rotation = ((($QuarterTurns % 4) + 4) % 4) * 90
    $parts = @("Rotation: ${rotation}°")
    $parts += if ($FlipHorizontal) { 'Mirror H: on' } else { 'Mirror H: off' }
    $parts += if ($FlipVertical) { 'Mirror V: on' } else { 'Mirror V: off' }
    return ($parts -join '   ')
}

function New-PreviewBitmap {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$SourceBitmap,
        [Parameter(Mandatory = $true)][int]$QuarterTurns,
        [Parameter(Mandatory = $true)][bool]$FlipHorizontal,
        [Parameter(Mandatory = $true)][bool]$FlipVertical
    )

    $preview = New-Object System.Drawing.Bitmap($SourceBitmap)
    $preview.RotateFlip((Get-RotateFlipType -QuarterTurns $QuarterTurns -FlipHorizontal $FlipHorizontal -FlipVertical $FlipVertical))
    return $preview
}

function Get-RotateFlipIconPath {
    param([Parameter(Mandatory = $true)][string]$IconFileName)

    return Join-Path (Get-AppRoot) ('tools\icons\rotate.filp.menu\' + $IconFileName)
}

function New-MenuIconBitmap {
    param(
        [Parameter(Mandatory = $true)][string]$IconFileName,
        [int]$Size = 20
    )

    $iconPath = Get-RotateFlipIconPath -IconFileName $IconFileName
    if (-not (Test-Path -LiteralPath $iconPath)) {
        return $null
    }

    $sourceImage = $null
    $scaledBitmap = $null
    $graphics = $null

    try {
        if ([System.IO.Path]::GetExtension($iconPath).ToLowerInvariant() -eq '.ico') {
            $icon = New-Object System.Drawing.Icon($iconPath, $Size, $Size)
            try {
                $sourceImage = $icon.ToBitmap()
            }
            finally {
                $icon.Dispose()
            }
        }
        else {
            $sourceImage = [System.Drawing.Image]::FromFile($iconPath)
        }

        $scaledBitmap = New-Object System.Drawing.Bitmap($Size, $Size)
        $graphics = [System.Drawing.Graphics]::FromImage($scaledBitmap)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.DrawImage($sourceImage, 0, 0, $Size, $Size)
        return $scaledBitmap
    }
    finally {
        if ($graphics) { $graphics.Dispose() }
        if ($sourceImage) { $sourceImage.Dispose() }
    }
}

function Show-FlipWindow {
    param([Parameter(Mandatory = $true)][string]$ImagePath)

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $loadedImage = $null
    $originalPreview = $null
    $currentPreview = $null
    $graphics = $null
    $buttonIcons = New-Object System.Collections.Generic.List[System.IDisposable]

    try {
        $loadedImage = [System.Drawing.Image]::FromFile($ImagePath)
        $maxPreviewEdge = 512
        $scale = [Math]::Min(($maxPreviewEdge / [double]$loadedImage.Width), ($maxPreviewEdge / [double]$loadedImage.Height))
        if ($scale -gt 1.0) { $scale = 1.0 }

        $previewWidth = [Math]::Max(1, [int][Math]::Round($loadedImage.Width * $scale))
        $previewHeight = [Math]::Max(1, [int][Math]::Round($loadedImage.Height * $scale))

        $originalPreview = New-Object System.Drawing.Bitmap($previewWidth, $previewHeight)
        $graphics = [System.Drawing.Graphics]::FromImage($originalPreview)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.DrawImage($loadedImage, 0, 0, $previewWidth, $previewHeight)
        $graphics.Dispose()
        $graphics = $null
        $loadedImage.Dispose()
        $loadedImage = $null
    }
    catch {
        if ($graphics) { $graphics.Dispose() }
        if ($loadedImage) { $loadedImage.Dispose() }
        throw
    }

    $script:quarterTurns = 0
    $script:flipHorizontal = $false
    $script:flipVertical = $false
    $script:transformKeys = New-Object System.Collections.Generic.List[string]

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFActions - Rotate / flip image'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(700, 590)
    $form.TopMost = $true

    $labelTitle = New-Object System.Windows.Forms.Label
    $labelTitle.Location = New-Object System.Drawing.Point(18, 14)
    $labelTitle.Size = New-Object System.Drawing.Size(664, 22)
    $labelTitle.Text = 'Preview the result, then validate when it looks right.'
    $form.Controls.Add($labelTitle)

    $previewPanel = New-Object System.Windows.Forms.Panel
    $previewPanel.Location = New-Object System.Drawing.Point(18, 44)
    $previewPanel.Size = New-Object System.Drawing.Size(664, 430)
    $previewPanel.BackColor = [System.Drawing.Color]::FromArgb(36, 36, 36)
    $form.Controls.Add($previewPanel)

    $previewBox = New-Object System.Windows.Forms.PictureBox
    $previewBox.Location = New-Object System.Drawing.Point(0, 0)
    $previewBox.Size = $previewPanel.Size
    $previewBox.BackColor = [System.Drawing.Color]::Transparent
    $previewBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::CenterImage
    $previewPanel.Controls.Add($previewBox)

    $buttonSpecs = @(
        @{ Key = 'rotate90';  Glyph = '⟳'; IconFile = 'Rotate.right_icon.ico';    X = 18;  Tooltip = 'Rotate 90 degrees clockwise' },
        @{ Key = 'rotate270'; Glyph = '⟲'; IconFile = 'Rotate.left_icon.ico';     X = 66;  Tooltip = 'Rotate 90 degrees counterclockwise' },
        @{ Key = 'flip_h';    Glyph = '⇋'; IconFile = 'flip.horizontal_icon.ico'; X = 114; Tooltip = 'Mirror horizontally' },
        @{ Key = 'flip_v';    Glyph = '⇅'; IconFile = 'filp.vertical_icon.ico';   X = 162; Tooltip = 'Mirror vertically' }
    )

    $buttonFont = New-Object System.Drawing.Font('Segoe UI Symbol', 16, [System.Drawing.FontStyle]::Regular)
    $buttonTooltip = New-Object System.Windows.Forms.ToolTip

    $labelState = New-Object System.Windows.Forms.Label
    $labelState.Location = New-Object System.Drawing.Point(18, 486)
    $labelState.Size = New-Object System.Drawing.Size(420, 22)
    $form.Controls.Add($labelState)

    $labelHint = New-Object System.Windows.Forms.Label
    $labelHint.Location = New-Object System.Drawing.Point(18, 512)
    $labelHint.Size = New-Object System.Drawing.Size(500, 18)
    $labelHint.Text = 'The transformed image will be created next to the original file.'
    $form.Controls.Add($labelHint)

    $updatePreview = {
        if ($currentPreview) {
            $currentPreview.Dispose()
            $currentPreview = $null
        }

        $currentPreview = New-PreviewBitmap -SourceBitmap $originalPreview -QuarterTurns $script:quarterTurns -FlipHorizontal $script:flipHorizontal -FlipVertical $script:flipVertical
        $previewBox.Image = $currentPreview
        $labelState.Text = Get-TransformSummary -QuarterTurns $script:quarterTurns -FlipHorizontal $script:flipHorizontal -FlipVertical $script:flipVertical
    }

    foreach ($spec in $buttonSpecs) {
        $button = New-Object System.Windows.Forms.Button
        $button.Tag = $spec.Key
        $button.Location = New-Object System.Drawing.Point($spec.X, 536)
        $button.Size = New-Object System.Drawing.Size(36, 36)
        $button.TextImageRelation = [System.Windows.Forms.TextImageRelation]::ImageBeforeText
        $buttonTooltip.SetToolTip($button, $spec.Tooltip)

        $iconBitmap = New-MenuIconBitmap -IconFileName $spec.IconFile
        if ($iconBitmap) {
            $button.Image = $iconBitmap
            $button.ImageAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            $buttonIcons.Add($iconBitmap) | Out-Null
        }
        else {
            $button.Text = $spec.Glyph
            $button.Font = $buttonFont
        }

        $button.Add_Click({
            param($sender, $eventArgs)
            $key = [string]$sender.Tag
            switch ($key) {
                'rotate90' {
                    $script:quarterTurns = ($script:quarterTurns + 1) % 4
                }
                'rotate270' {
                    $script:quarterTurns = ($script:quarterTurns + 3) % 4
                }
                'flip_h' {
                    $script:flipHorizontal = -not $script:flipHorizontal
                }
                'flip_v' {
                    $script:flipVertical = -not $script:flipVertical
                }
            }

            $script:transformKeys.Add($key) | Out-Null
            & $updatePreview
        })
        $form.Controls.Add($button)
    }

    $buttonReset = New-Object System.Windows.Forms.Button
    $buttonReset.Text = 'Reset'
    $buttonReset.Location = New-Object System.Drawing.Point(376, 542)
    $buttonReset.Size = New-Object System.Drawing.Size(90, 28)
    $buttonReset.Add_Click({
        $script:quarterTurns = 0
        $script:flipHorizontal = $false
        $script:flipVertical = $false
        $script:transformKeys.Clear()
        & $updatePreview
    })
    $form.Controls.Add($buttonReset)

    $buttonOK = New-Object System.Windows.Forms.Button
    $buttonOK.Text = 'OK'
    $buttonOK.Location = New-Object System.Drawing.Point(490, 542)
    $buttonOK.Size = New-Object System.Drawing.Size(90, 28)
    $buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($buttonOK)

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.Location = New-Object System.Drawing.Point(592, 542)
    $buttonCancel.Size = New-Object System.Drawing.Size(90, 28)
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($buttonCancel)

    $form.AcceptButton = $buttonOK
    $form.CancelButton = $buttonCancel

    & $updatePreview

    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        $previewBox.Image = $null
        if ($currentPreview) { $currentPreview.Dispose() }
        if ($originalPreview) { $originalPreview.Dispose() }
        foreach ($buttonIcon in $buttonIcons) {
            if ($buttonIcon) { $buttonIcon.Dispose() }
        }
        $buttonFont.Dispose()
        $form.Dispose()
        return $null
    }

    if ($script:transformKeys.Count -eq 0) {
        $previewBox.Image = $null
        if ($currentPreview) { $currentPreview.Dispose() }
        if ($originalPreview) { $originalPreview.Dispose() }
        foreach ($buttonIcon in $buttonIcons) {
            if ($buttonIcon) { $buttonIcon.Dispose() }
        }
        $buttonFont.Dispose()
        $form.Dispose()
        Show-Error 'Apply at least one transform before validating.'
        exit 1
    }

    $payload = Get-TransformConfig -Keys $script:transformKeys.ToArray()

    $previewBox.Image = $null
    if ($currentPreview) { $currentPreview.Dispose() }
    if ($originalPreview) { $originalPreview.Dispose() }
    foreach ($buttonIcon in $buttonIcons) {
        if ($buttonIcon) { $buttonIcon.Dispose() }
    }
    $buttonFont.Dispose()
    $form.Dispose()

    return $payload
}

function New-FFmpegArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)][string]$Extension,
        [Parameter(Mandatory = $true)][string]$Filter
    )

    $args = @(
        '-hide_banner',
        '-loglevel', 'error',
        '-y',
        '-i', $InputFile,
        '-frames:v', '1',
        '-vf', $Filter
    )

    switch ($Extension.ToLowerInvariant()) {
        '.jpg' {
            $args += @('-q:v', '2')
        }
        '.jpeg' {
            $args += @('-q:v', '2')
        }
        '.webp' {
            $args += @('-c:v', 'libwebp', '-quality', '90', '-compression_level', '4')
        }
        '.png' {
            $args += @('-compression_level', '6')
        }
        '.bmp' {
        }
        default {
            throw 'Unsupported output format. Only .png, .jpg, .jpeg, .webp and .bmp are supported.'
        }
    }

    $args += @($OutputFile)
    return ,$args
}

function New-TemporaryPreviewPng {
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$FfmpegPath
    )

    $previewPath = Join-Path ([System.IO.Path]::GetTempPath()) ('ffactions_preview_' + [Guid]::NewGuid().ToString('N') + '.png')
    $args = @(
        '-hide_banner',
        '-loglevel', 'error',
        '-y',
        '-i', $InputPath,
        '-frames:v', '1',
        '-update', '1',
        $previewPath
    )

    $result = Invoke-HiddenProcess -FilePath $FfmpegPath -Arguments $args
    if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $previewPath)) {
        if (Test-Path -LiteralPath $previewPath) {
            try { Remove-Item -LiteralPath $previewPath -Force -ErrorAction SilentlyContinue } catch {}
        }
        throw (Get-ShortErrorText -StdErr $result.StdErr)
    }

    return $previewPath
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
    if ($sourceExtension -notin @('.png', '.jpg', '.jpeg', '.webp', '.bmp')) {
        Show-Error 'Unsupported input format. Only .png, .jpg, .jpeg, .webp and .bmp are supported.'
        exit 1
    }

    $ffmpeg = Get-ToolPath 'ffmpeg.exe'
    if (-not (Test-Path -LiteralPath $ffmpeg)) {
        Show-Error 'ffmpeg.exe not found.'
        exit 1
    }

    $previewPath = $InputFile
    $temporaryPreview = $null
    if ($sourceExtension -eq '.webp') {
        $temporaryPreview = New-TemporaryPreviewPng -InputPath $InputFile -FfmpegPath $ffmpeg
        $previewPath = $temporaryPreview
    }

    try {
        $transform = Show-FlipWindow -ImagePath $previewPath
    }
    finally {
        if ($temporaryPreview -and (Test-Path -LiteralPath $temporaryPreview)) {
            try { Remove-Item -LiteralPath $temporaryPreview -Force -ErrorAction SilentlyContinue } catch {}
        }
    }

    if ($null -eq $transform) {
        exit 0
    }

    $inputDir = Split-Path -Parent $InputFile
    $inputBase = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $desiredOutput = Join-Path $inputDir ($inputBase + '_' + $transform.Label + $sourceExtension)
    $script:OutputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

    $ffmpegArgs = New-FFmpegArguments -InputFile $InputFile -OutputFile $script:OutputFile -Extension $sourceExtension -Filter $transform.Filter
    $result = Invoke-HiddenProcess -FilePath $ffmpeg -Arguments $ffmpegArgs

    if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $script:OutputFile)) {
        Remove-PartialOutput -Path $script:OutputFile
        Show-Error (Get-ShortErrorText -StdErr $result.StdErr)
        exit 1
    }

    exit 0
}
catch {
    $message = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($message)) { $message = 'Unknown image transform error.' }
    Show-Error $message
    exit 1
}
