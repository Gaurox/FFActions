param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-Error([string]$Message) {
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        'FFActions - Error',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function Get-AppRoot {
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $exeDir = Split-Path -Parent $exePath
    return Split-Path -Parent $exeDir
}

function Get-ToolPath([string]$ToolName) {
    $appRoot = Get-AppRoot
    return Join-Path $appRoot "tools\ffmpeg\$ToolName"
}

function Quote-ProcessArgument {
    param([string]$Value)

    if ($null -eq $Value) { return '""' }
    if ($Value -eq '') { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }

    $escaped = $Value -replace '(\\*)"', '$1$1\\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function Join-ProcessArguments {
    param([object[]]$Arguments)

    $quoted = foreach ($arg in $Arguments) {
        Quote-ProcessArgument ([string]$arg)
    }

    return ($quoted -join ' ')
}

function Invoke-HiddenProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][object[]]$Arguments
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = Join-ProcessArguments -Arguments $Arguments
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

function Get-UniqueOutputPath([string]$DesiredPath) {
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

function Get-ShortErrorText {
    param([string]$StdErr)

    if (-not [string]::IsNullOrWhiteSpace($StdErr)) {
        $firstLines = ($StdErr -split "`r?`n" | Where-Object { $_.Trim() -ne '' } | Select-Object -First 12) -join "`r`n"
        if (-not [string]::IsNullOrWhiteSpace($firstLines)) {
            return $firstLines
        }
    }

    return 'FFmpeg failed during icon conversion.'
}

function Get-PreviewBackgroundBrush {
    param([string]$Background)

    switch ($Background) {
        'white' { return [System.Drawing.Brushes]::White }
        'black' { return [System.Drawing.Brushes]::Black }
        default { return $null }
    }
}

function New-PreviewBitmap {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Image]$SourceImage,
        [Parameter(Mandatory = $true)][int]$IconSize,
        [Parameter(Mandatory = $true)][string]$FitMode,
        [Parameter(Mandatory = $true)][string]$Background,
        [Parameter(Mandatory = $true)][bool]$Enabled
    )

    $canvasSize = 74
    $bitmap = New-Object System.Drawing.Bitmap($canvasSize, $canvasSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $cellBrushLight = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(242, 242, 242))
    $cellBrushDark = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(218, 218, 218))
    for ($y = 0; $y -lt $canvasSize; $y += 8) {
        for ($x = 0; $x -lt $canvasSize; $x += 8) {
            $brush = if ((($x + $y) / 8) % 2 -eq 0) { $cellBrushLight } else { $cellBrushDark }
            $graphics.FillRectangle($brush, $x, $y, 8, 8)
        }
    }
    $cellBrushLight.Dispose()
    $cellBrushDark.Dispose()

    $previewSize = [Math]::Min($IconSize, 64)
    $previewRect = New-Object System.Drawing.Rectangle(
        [int][Math]::Floor(($canvasSize - $previewSize) / 2),
        [int][Math]::Floor(($canvasSize - $previewSize) / 2),
        $previewSize,
        $previewSize
    )

    $backgroundBrush = Get-PreviewBackgroundBrush -Background $Background
    if ($backgroundBrush) {
        $graphics.FillRectangle($backgroundBrush, $previewRect)
    }

    $sourceRatio = $SourceImage.Width / [double]$SourceImage.Height
    $targetRatio = 1.0
    if ($FitMode -eq 'fill') {
        if ($sourceRatio -gt $targetRatio) {
            $cropHeight = $SourceImage.Height
            $cropWidth = [int][Math]::Round($cropHeight * $targetRatio)
            $cropX = [int][Math]::Floor(($SourceImage.Width - $cropWidth) / 2)
            $sourceRect = New-Object System.Drawing.Rectangle($cropX, 0, $cropWidth, $cropHeight)
        }
        else {
            $cropWidth = $SourceImage.Width
            $cropHeight = [int][Math]::Round($cropWidth / $targetRatio)
            $cropY = [int][Math]::Floor(($SourceImage.Height - $cropHeight) / 2)
            $sourceRect = New-Object System.Drawing.Rectangle(0, $cropY, $cropWidth, $cropHeight)
        }
        $destinationRect = $previewRect
    }
    else {
        if ($sourceRatio -gt $targetRatio) {
            $drawWidth = $previewSize
            $drawHeight = [int][Math]::Round($previewSize / $sourceRatio)
        }
        else {
            $drawHeight = $previewSize
            $drawWidth = [int][Math]::Round($previewSize * $sourceRatio)
        }
        $destinationRect = New-Object System.Drawing.Rectangle(
            [int]($previewRect.X + (($previewRect.Width - $drawWidth) / 2)),
            [int]($previewRect.Y + (($previewRect.Height - $drawHeight) / 2)),
            $drawWidth,
            $drawHeight
        )
        $sourceRect = New-Object System.Drawing.Rectangle(0, 0, $SourceImage.Width, $SourceImage.Height)
    }

    if ($Enabled) {
        $graphics.DrawImage($SourceImage, $destinationRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
    }
    else {
        $attributes = New-Object System.Drawing.Imaging.ImageAttributes
        $matrix = New-Object System.Drawing.Imaging.ColorMatrix
        $matrix.Matrix00 = 0.30
        $matrix.Matrix01 = 0.30
        $matrix.Matrix02 = 0.30
        $matrix.Matrix10 = 0.59
        $matrix.Matrix11 = 0.59
        $matrix.Matrix12 = 0.59
        $matrix.Matrix20 = 0.11
        $matrix.Matrix21 = 0.11
        $matrix.Matrix22 = 0.11
        $matrix.Matrix33 = 0.35
        $matrix.Matrix44 = 1.0
        $attributes.SetColorMatrix($matrix)
        $graphics.DrawImage($SourceImage, $destinationRect, $sourceRect.X, $sourceRect.Y, $sourceRect.Width, $sourceRect.Height, [System.Drawing.GraphicsUnit]::Pixel, $attributes)
        $attributes.Dispose()
    }

    $graphics.Dispose()

    return $bitmap
}

function Show-IconWindow {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile
    )

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $sourceImage = $null
    try {
        $sourceImage = [System.Drawing.Image]::FromFile($InputFile)
    }
    catch {
        $sourceImage = $null
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFActions - Convert to icon'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(760, 430)
    $form.TopMost = $true

    $groupSizes = New-Object System.Windows.Forms.GroupBox
    $groupSizes.Text = 'Sizes'
    $groupSizes.Location = New-Object System.Drawing.Point(18, 16)
    $groupSizes.Size = New-Object System.Drawing.Size(180, 232)
    $form.Controls.Add($groupSizes)

    $sizeValues = @(16, 32, 48, 64, 128, 256)
    $defaultSizes = @(16, 32, 48, 256)
    $sizeChecks = @()
    for ($i = 0; $i -lt $sizeValues.Count; $i++) {
        $value = [int]$sizeValues[$i]
        $check = New-Object System.Windows.Forms.CheckBox
        $check.Text = "$value x $value"
        $check.Tag = $value
        $check.Location = New-Object System.Drawing.Point(18, (26 + ($i * 28)))
        $check.Size = New-Object System.Drawing.Size(120, 24)
        $check.Checked = $defaultSizes -contains $value
        $groupSizes.Controls.Add($check)
        $sizeChecks += $check
    }

    $groupFit = New-Object System.Windows.Forms.GroupBox
    $groupFit.Text = 'Fit mode'
    $groupFit.Location = New-Object System.Drawing.Point(216, 16)
    $groupFit.Size = New-Object System.Drawing.Size(186, 96)
    $form.Controls.Add($groupFit)

    $radioFit = New-Object System.Windows.Forms.RadioButton
    $radioFit.Text = 'Fit'
    $radioFit.Location = New-Object System.Drawing.Point(18, 28)
    $radioFit.Size = New-Object System.Drawing.Size(130, 24)
    $radioFit.Checked = $true
    $groupFit.Controls.Add($radioFit)

    $radioFill = New-Object System.Windows.Forms.RadioButton
    $radioFill.Text = 'Fill'
    $radioFill.Location = New-Object System.Drawing.Point(18, 58)
    $radioFill.Size = New-Object System.Drawing.Size(130, 24)
    $groupFit.Controls.Add($radioFill)

    $groupBackground = New-Object System.Windows.Forms.GroupBox
    $groupBackground.Text = 'Background'
    $groupBackground.Location = New-Object System.Drawing.Point(216, 128)
    $groupBackground.Size = New-Object System.Drawing.Size(186, 120)
    $form.Controls.Add($groupBackground)

    $radioTransparent = New-Object System.Windows.Forms.RadioButton
    $radioTransparent.Text = 'Transparent'
    $radioTransparent.Location = New-Object System.Drawing.Point(18, 28)
    $radioTransparent.Size = New-Object System.Drawing.Size(140, 24)
    $radioTransparent.Checked = $true
    $groupBackground.Controls.Add($radioTransparent)

    $radioWhite = New-Object System.Windows.Forms.RadioButton
    $radioWhite.Text = 'White'
    $radioWhite.Location = New-Object System.Drawing.Point(18, 58)
    $radioWhite.Size = New-Object System.Drawing.Size(140, 24)
    $groupBackground.Controls.Add($radioWhite)

    $radioBlack = New-Object System.Windows.Forms.RadioButton
    $radioBlack.Text = 'Black'
    $radioBlack.Location = New-Object System.Drawing.Point(18, 88)
    $radioBlack.Size = New-Object System.Drawing.Size(140, 24)
    $groupBackground.Controls.Add($radioBlack)

    $groupPreview = New-Object System.Windows.Forms.GroupBox
    $groupPreview.Text = 'Preview'
    $groupPreview.Location = New-Object System.Drawing.Point(420, 16)
    $groupPreview.Size = New-Object System.Drawing.Size(322, 344)
    $form.Controls.Add($groupPreview)

    $previewTiles = @()
    for ($i = 0; $i -lt $sizeValues.Count; $i++) {
        $value = [int]$sizeValues[$i]
        $tile = New-Object System.Windows.Forms.Panel
        $tile.Tag = $value
        $tile.Size = New-Object System.Drawing.Size(90, 126)
        $tile.Location = New-Object System.Drawing.Point((16 + (($i % 3) * 100)), (28 + ([Math]::Floor($i / 3) * 150)))
        $tile.BorderStyle = [System.Windows.Forms.BorderStyle]::None
        $tile.Add_Paint({
            param($sender, $eventArgs)
            $tileInfo = $previewTiles | Where-Object { $_.Panel -eq $sender } | Select-Object -First 1
            $isChecked = $tileInfo -and [bool]$tileInfo.CheckBox.Checked
            $pen = if ($isChecked) {
                New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(0, 120, 215), 2)
            }
            else {
                New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(150, 150, 150), 1)
            }
            $rectangle = New-Object System.Drawing.Rectangle(0, 0, ($sender.Width - 1), ($sender.Height - 1))
            $eventArgs.Graphics.DrawRectangle($pen, $rectangle)
            $pen.Dispose()
        })
        $groupPreview.Controls.Add($tile)

        $picture = New-Object System.Windows.Forms.PictureBox
        $picture.Location = New-Object System.Drawing.Point(7, 8)
        $picture.Size = New-Object System.Drawing.Size(74, 74)
        $picture.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::CenterImage
        $tile.Controls.Add($picture)

        $label = New-Object System.Windows.Forms.Label
        $label.Text = "$value x $value"
        $label.Location = New-Object System.Drawing.Point(5, 88)
        $label.Size = New-Object System.Drawing.Size(78, 18)
        $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $tile.Controls.Add($label)

        $stateLabel = New-Object System.Windows.Forms.Label
        $stateLabel.Location = New-Object System.Drawing.Point(5, 106)
        $stateLabel.Size = New-Object System.Drawing.Size(78, 16)
        $stateLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $tile.Controls.Add($stateLabel)

        $previewTiles += [PSCustomObject]@{
            Size       = $value
            Panel      = $tile
            PictureBox = $picture
            Label      = $label
            StateLabel = $stateLabel
            CheckBox   = $sizeChecks[$i]
        }
    }

    $labelHint = New-Object System.Windows.Forms.Label
    $labelHint.Location = New-Object System.Drawing.Point(20, 274)
    $labelHint.Size = New-Object System.Drawing.Size(380, 48)
    $labelHint.Text = 'The ICO file will be created next to the original image.'
    $form.Controls.Add($labelHint)

    $buttonOK = New-Object System.Windows.Forms.Button
    $buttonOK.Text = 'OK'
    $buttonOK.Location = New-Object System.Drawing.Point(556, 382)
    $buttonOK.Size = New-Object System.Drawing.Size(90, 28)
    $buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($buttonOK)

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.Location = New-Object System.Drawing.Point(652, 382)
    $buttonCancel.Size = New-Object System.Drawing.Size(90, 28)
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($buttonCancel)

    $form.AcceptButton = $buttonOK
    $form.CancelButton = $buttonCancel

    function Get-SelectedBackground {
        if ($radioWhite.Checked) { return 'white' }
        if ($radioBlack.Checked) { return 'black' }
        return 'transparent'
    }

    function Update-Preview {
        $fitMode = if ($radioFill.Checked) { 'fill' } else { 'fit' }
        $background = Get-SelectedBackground

        foreach ($tileInfo in $previewTiles) {
            $isChecked = [bool]$tileInfo.CheckBox.Checked
            $oldImage = $tileInfo.PictureBox.Image
            if ($sourceImage) {
                $tileInfo.PictureBox.Image = New-PreviewBitmap -SourceImage $sourceImage -IconSize $tileInfo.Size -FitMode $fitMode -Background $background -Enabled $isChecked
            }
            else {
                $tileInfo.PictureBox.Image = $null
            }
            if ($oldImage) { $oldImage.Dispose() }

            $tileInfo.Panel.BackColor = if ($isChecked) {
                [System.Drawing.SystemColors]::Window
            }
            else {
                [System.Drawing.Color]::FromArgb(238, 238, 238)
            }
            $tileInfo.Label.ForeColor = if ($isChecked) {
                [System.Drawing.SystemColors]::ControlText
            }
            else {
                [System.Drawing.SystemColors]::GrayText
            }
            $tileInfo.StateLabel.Text = if ($isChecked) { 'Included' } else { 'Skipped' }
            $tileInfo.StateLabel.ForeColor = if ($isChecked) {
                [System.Drawing.Color]::FromArgb(0, 120, 215)
            }
            else {
                [System.Drawing.SystemColors]::GrayText
            }
            $tileInfo.Panel.Invalidate()
        }
    }

    foreach ($check in $sizeChecks) {
        $check.Add_CheckedChanged({ Update-Preview })
    }
    $radioFit.Add_CheckedChanged({ Update-Preview })
    $radioFill.Add_CheckedChanged({ Update-Preview })
    $radioTransparent.Add_CheckedChanged({ Update-Preview })
    $radioWhite.Add_CheckedChanged({ Update-Preview })
    $radioBlack.Add_CheckedChanged({ Update-Preview })
    $form.Add_FormClosed({
        foreach ($tileInfo in $previewTiles) {
            if ($tileInfo.PictureBox.Image) {
                $tileInfo.PictureBox.Image.Dispose()
                $tileInfo.PictureBox.Image = $null
            }
        }
        if ($sourceImage) {
            $sourceImage.Dispose()
        }
    })

    Update-Preview

    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        $form.Dispose()
        return $null
    }

    $selectedSizes = @($sizeChecks | Where-Object { $_.Checked } | ForEach-Object { [int]$_.Tag })
    if ($selectedSizes.Count -eq 0) {
        $form.Dispose()
        Show-Error 'Select at least one icon size.'
        exit 1
    }

    $background = Get-SelectedBackground

    $payload = [PSCustomObject]@{
        Sizes      = @($selectedSizes | Sort-Object)
        FitMode    = if ($radioFill.Checked) { 'fill' } else { 'fit' }
        Background = $background
    }

    $form.Dispose()
    return $payload
}

function Get-BackgroundColor {
    param([string]$Background)

    switch ($Background) {
        'white' { return 'white' }
        'black' { return 'black' }
        default { return '0x00000000' }
    }
}

function New-IconPngArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)][int]$Size,
        [Parameter(Mandatory = $true)][string]$FitMode,
        [Parameter(Mandatory = $true)][string]$Background
    )

    $bg = Get-BackgroundColor -Background $Background
    if ($FitMode -eq 'fill') {
        $filter = "scale=${Size}:${Size}:force_original_aspect_ratio=increase,crop=${Size}:${Size},setsar=1,format=rgba"
    }
    else {
        $filter = "scale=${Size}:${Size}:force_original_aspect_ratio=decrease,pad=${Size}:${Size}:(ow-iw)/2:(oh-ih)/2:color=${bg},setsar=1,format=rgba"
    }

    return @(
        '-hide_banner',
        '-loglevel', 'error',
        '-y',
        '-i', $InputFile,
        '-frames:v', '1',
        '-vf', $filter,
        '-update', '1',
        $OutputFile
    )
}

function New-IconArguments {
    param(
        [Parameter(Mandatory = $true)][string[]]$PngFiles,
        [Parameter(Mandatory = $true)][string]$OutputFile
    )

    $args = @('-hide_banner', '-loglevel', 'error', '-y')
    foreach ($png in $PngFiles) {
        $args += @('-i', $png)
    }
    for ($i = 0; $i -lt $PngFiles.Count; $i++) {
        $args += @('-map', "$i`:v")
    }
    $args += @($OutputFile)
    return ,$args
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

    $iconConfig = Show-IconWindow -InputFile $InputFile
    if ($null -eq $iconConfig) {
        exit 0
    }

    $inputDir = Split-Path -Parent $InputFile
    $inputBase = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $desiredOutput = Join-Path $inputDir ($inputBase + '_icon.ico')
    $script:OutputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ('ffactions_icon_' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        $pngFiles = @()
        foreach ($size in $iconConfig.Sizes) {
            $pngFile = Join-Path $tempDir ("icon_${size}.png")
            $pngArgs = New-IconPngArguments -InputFile $InputFile -OutputFile $pngFile -Size $size -FitMode $iconConfig.FitMode -Background $iconConfig.Background
            $pngResult = Invoke-HiddenProcess -FilePath $ffmpeg -Arguments $pngArgs
            if ($pngResult.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $pngFile)) {
                Show-Error (Get-ShortErrorText -StdErr $pngResult.StdErr)
                exit 1
            }
            $pngFiles += $pngFile
        }

        $iconArgs = New-IconArguments -PngFiles $pngFiles -OutputFile $script:OutputFile
        $iconResult = Invoke-HiddenProcess -FilePath $ffmpeg -Arguments $iconArgs
        if ($iconResult.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $script:OutputFile)) {
            Remove-PartialOutput -Path $script:OutputFile
            Show-Error (Get-ShortErrorText -StdErr $iconResult.StdErr)
            exit 1
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempDir) {
            try { Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}
        }
    }

    exit 0
}
catch {
    $message = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($message)) { $message = 'Unknown icon conversion error.' }
    Show-Error $message
    exit 1
}
