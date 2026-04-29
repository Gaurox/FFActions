param(
    [string]$inputFile
)

#__FFCOMMON_INJECT_HERE__

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

function Show-ErrorAndExit {
    param([string]$Message)
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        "Resize Image",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit
}

function Try-ParsePositiveInt {
    param([string]$Text)
    $value = 0
    if ([int]::TryParse($Text, [ref]$value) -and $value -gt 0) {
        return $value
    }
    return $null
}

function Try-ParsePositiveDouble {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $styles = [System.Globalization.NumberStyles]::Float
    $cultures = @(
        [System.Globalization.CultureInfo]::CurrentCulture,
        [System.Globalization.CultureInfo]::InvariantCulture
    )

    foreach ($culture in $cultures) {
        $value = 0.0
        if ([double]::TryParse($Text.Trim(), $styles, $culture, [ref]$value) -and $value -gt 0) {
            return $value
        }
    }

    return $null
}

function Format-PercentText {
    param([double]$Value)
    $rounded = [Math]::Round($Value, 2)
    if ([Math]::Abs($rounded - [Math]::Round($rounded)) -lt 0.0000001) {
        return ([int][Math]::Round($rounded)).ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }
    return $rounded.ToString("0.##", [System.Globalization.CultureInfo]::InvariantCulture)
}

function Format-ScaleButtonText {
    param([double]$Scale)
    return ('x' + $Scale.ToString("0.##", [System.Globalization.CultureInfo]::CurrentCulture))
}

if ([string]::IsNullOrWhiteSpace($inputFile) -or -not (Test-Path -LiteralPath $inputFile)) {
    Show-ErrorAndExit "Input file not found."
}

$srcStream = $null
$srcImage = $null

try {
    $srcStream = [System.IO.File]::Open($inputFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $srcImage = [System.Drawing.Image]::FromStream($srcStream, $false, $false)
    $origWidth = [int]$srcImage.Width
    $origHeight = [int]$srcImage.Height
}
catch {
    Show-ErrorAndExit "Failed to read image metadata."
}
finally {
    if ($srcImage) { $srcImage.Dispose() }
    if ($srcStream) { $srcStream.Dispose() }
}

if ($origWidth -le 0 -or $origHeight -le 0) {
    Show-ErrorAndExit "Invalid image dimensions."
}

$ratio = [double]$origWidth / [double]$origHeight
$script:updatingFields = $false
$script:activeEditField = $null

$form = New-Object System.Windows.Forms.Form
$form.Text = "Resize Image"
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ShowIcon = $false
$form.ClientSize = New-Object System.Drawing.Size(500, 388)
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$panelHeader = New-Object System.Windows.Forms.Panel
$panelHeader.Location = New-Object System.Drawing.Point(0, 0)
$panelHeader.Size = New-Object System.Drawing.Size(500, 78)
$panelHeader.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($panelHeader)

$labelTitle = New-Object System.Windows.Forms.Label
$labelTitle.Text = "Resize image"
$labelTitle.Location = New-Object System.Drawing.Point(20, 16)
$labelTitle.Size = New-Object System.Drawing.Size(220, 26)
$labelTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$panelHeader.Controls.Add($labelTitle)

$labelSubtitle = New-Object System.Windows.Forms.Label
$labelSubtitle.Text = "Adjust in pixels or percent and keep the original ratio automatically."
$labelSubtitle.Location = New-Object System.Drawing.Point(20, 44)
$labelSubtitle.Size = New-Object System.Drawing.Size(450, 20)
$labelSubtitle.ForeColor = [System.Drawing.Color]::FromArgb(90, 90, 90)
$panelHeader.Controls.Add($labelSubtitle)

$groupOriginal = New-Object System.Windows.Forms.GroupBox
$groupOriginal.Text = "Original size"
$groupOriginal.Location = New-Object System.Drawing.Point(18, 92)
$groupOriginal.Size = New-Object System.Drawing.Size(464, 60)
$form.Controls.Add($groupOriginal)

$labelOriginalValue = New-Object System.Windows.Forms.Label
$labelOriginalValue.Text = "$origWidth x $origHeight px"
$labelOriginalValue.Location = New-Object System.Drawing.Point(16, 24)
$labelOriginalValue.Size = New-Object System.Drawing.Size(220, 24)
$labelOriginalValue.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$groupOriginal.Controls.Add($labelOriginalValue)

$groupSize = New-Object System.Windows.Forms.GroupBox
$groupSize.Text = "New size"
$groupSize.Location = New-Object System.Drawing.Point(18, 166)
$groupSize.Size = New-Object System.Drawing.Size(464, 104)
$form.Controls.Add($groupSize)

$labelWidth = New-Object System.Windows.Forms.Label
$labelWidth.Text = "Width"
$labelWidth.Location = New-Object System.Drawing.Point(16, 27)
$labelWidth.Size = New-Object System.Drawing.Size(50, 23)
$groupSize.Controls.Add($labelWidth)

$textWidthPx = New-Object System.Windows.Forms.TextBox
$textWidthPx.Location = New-Object System.Drawing.Point(72, 24)
$textWidthPx.Size = New-Object System.Drawing.Size(90, 23)
$textWidthPx.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Right
$textWidthPx.Tag = 'widthPx'
$groupSize.Controls.Add($textWidthPx)

$labelWidthPx = New-Object System.Windows.Forms.Label
$labelWidthPx.Text = "px"
$labelWidthPx.Location = New-Object System.Drawing.Point(170, 27)
$labelWidthPx.Size = New-Object System.Drawing.Size(24, 23)
$groupSize.Controls.Add($labelWidthPx)

$textWidthPct = New-Object System.Windows.Forms.TextBox
$textWidthPct.Location = New-Object System.Drawing.Point(240, 24)
$textWidthPct.Size = New-Object System.Drawing.Size(70, 23)
$textWidthPct.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Right
$textWidthPct.Tag = 'widthPct'
$groupSize.Controls.Add($textWidthPct)

$labelWidthPct = New-Object System.Windows.Forms.Label
$labelWidthPct.Text = "%"
$labelWidthPct.Location = New-Object System.Drawing.Point(318, 27)
$labelWidthPct.Size = New-Object System.Drawing.Size(20, 23)
$groupSize.Controls.Add($labelWidthPct)

$labelHeight = New-Object System.Windows.Forms.Label
$labelHeight.Text = "Height"
$labelHeight.Location = New-Object System.Drawing.Point(16, 59)
$labelHeight.Size = New-Object System.Drawing.Size(50, 23)
$groupSize.Controls.Add($labelHeight)

$textHeightPx = New-Object System.Windows.Forms.TextBox
$textHeightPx.Location = New-Object System.Drawing.Point(72, 56)
$textHeightPx.Size = New-Object System.Drawing.Size(90, 23)
$textHeightPx.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Right
$textHeightPx.Tag = 'heightPx'
$groupSize.Controls.Add($textHeightPx)

$labelHeightPx = New-Object System.Windows.Forms.Label
$labelHeightPx.Text = "px"
$labelHeightPx.Location = New-Object System.Drawing.Point(170, 59)
$labelHeightPx.Size = New-Object System.Drawing.Size(24, 23)
$groupSize.Controls.Add($labelHeightPx)

$textHeightPct = New-Object System.Windows.Forms.TextBox
$textHeightPct.Location = New-Object System.Drawing.Point(240, 56)
$textHeightPct.Size = New-Object System.Drawing.Size(70, 23)
$textHeightPct.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Right
$textHeightPct.Tag = 'heightPct'
$groupSize.Controls.Add($textHeightPct)

$labelHeightPct = New-Object System.Windows.Forms.Label
$labelHeightPct.Text = "%"
$labelHeightPct.Location = New-Object System.Drawing.Point(318, 59)
$labelHeightPct.Size = New-Object System.Drawing.Size(20, 23)
$groupSize.Controls.Add($labelHeightPct)

$checkLockRatio = New-Object System.Windows.Forms.CheckBox
$checkLockRatio.Text = "Keep ratio"
$checkLockRatio.Checked = $true
$checkLockRatio.Location = New-Object System.Drawing.Point(362, 39)
$checkLockRatio.Size = New-Object System.Drawing.Size(90, 24)
$groupSize.Controls.Add($checkLockRatio)

$groupPresets = New-Object System.Windows.Forms.GroupBox
$groupPresets.Text = "Quick scale"
$groupPresets.Location = New-Object System.Drawing.Point(18, 278)
$groupPresets.Size = New-Object System.Drawing.Size(464, 62)
$form.Controls.Add($groupPresets)

$presetScales = @(0.5, 0.75, 1.5, 2.0, 4.0)
$presetButtons = New-Object System.Collections.Generic.List[System.Windows.Forms.Button]
$presetButtonWidth = 76
$presetButtonHeight = 28
$presetStartX = 16
$presetGap = 12

for ($i = 0; $i -lt $presetScales.Count; $i++) {
    $scale = [double]$presetScales[$i]
    $button = New-Object System.Windows.Forms.Button
    $button.Text = Format-ScaleButtonText $scale
    $button.Tag = $scale
    $button.Size = New-Object System.Drawing.Size($presetButtonWidth, $presetButtonHeight)
    $button.Location = New-Object System.Drawing.Point(($presetStartX + ($i * ($presetButtonWidth + $presetGap))), 22)
    $groupPresets.Controls.Add($button)
    [void]$presetButtons.Add($button)
}

$buttonReset = New-Object System.Windows.Forms.Button
$buttonReset.Text = "Reset"
$buttonReset.Size = New-Object System.Drawing.Size(86, 30)
$buttonReset.Location = New-Object System.Drawing.Point(18, 348)
$form.Controls.Add($buttonReset)

$buttonOK = New-Object System.Windows.Forms.Button
$buttonOK.Text = "OK"
$buttonOK.Size = New-Object System.Drawing.Size(96, 30)
$buttonOK.Location = New-Object System.Drawing.Point(286, 348)
$buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($buttonOK)

$buttonCancel = New-Object System.Windows.Forms.Button
$buttonCancel.Text = "Cancel"
$buttonCancel.Size = New-Object System.Drawing.Size(96, 30)
$buttonCancel.Location = New-Object System.Drawing.Point(388, 348)
$buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($buttonCancel)

$form.AcceptButton = $buttonOK
$form.CancelButton = $buttonCancel

function Set-AllFields {
    param(
        [int]$WidthPx,
        [int]$HeightPx
    )

    $script:updatingFields = $true

    if ($script:activeEditField -ne 'widthPx') {
        $textWidthPx.Text = $WidthPx.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }
    if ($script:activeEditField -ne 'heightPx') {
        $textHeightPx.Text = $HeightPx.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }
    if ($script:activeEditField -ne 'widthPct') {
        $textWidthPct.Text = Format-PercentText (([double]$WidthPx / [double]$origWidth) * 100.0)
    }
    if ($script:activeEditField -ne 'heightPct') {
        $textHeightPct.Text = Format-PercentText (([double]$HeightPx / [double]$origHeight) * 100.0)
    }

    $script:updatingFields = $false
}

function Set-FromWidthPx {
    param([int]$WidthPx)
    $heightPx = if ($checkLockRatio.Checked) {
        [Math]::Max(1, [int][Math]::Round([double]$WidthPx / $ratio))
    } else {
        $existingHeight = Try-ParsePositiveInt $textHeightPx.Text
        if ($null -eq $existingHeight) { $origHeight } else { $existingHeight }
    }
    Set-AllFields $WidthPx $heightPx
}

function Set-FromHeightPx {
    param([int]$HeightPx)
    $widthPx = if ($checkLockRatio.Checked) {
        [Math]::Max(1, [int][Math]::Round([double]$HeightPx * $ratio))
    } else {
        $existingWidth = Try-ParsePositiveInt $textWidthPx.Text
        if ($null -eq $existingWidth) { $origWidth } else { $existingWidth }
    }
    Set-AllFields $widthPx $HeightPx
}

function Set-FromWidthPct {
    param([double]$WidthPct)
    $widthPx = [Math]::Max(1, [int][Math]::Round(([double]$origWidth * $WidthPct) / 100.0))
    Set-FromWidthPx $widthPx
}

function Set-FromHeightPct {
    param([double]$HeightPct)
    $heightPx = [Math]::Max(1, [int][Math]::Round(([double]$origHeight * $HeightPct) / 100.0))
    Set-FromHeightPx $heightPx
}

function Apply-ScalePreset {
    param([double]$Scale)

    $widthPx = [Math]::Max(1, [int][Math]::Round([double]$origWidth * $Scale))
    $heightPx = [Math]::Max(1, [int][Math]::Round([double]$origHeight * $Scale))
    Set-AllFields $widthPx $heightPx
}

function Commit-Field {
    param([string]$FieldName)
    switch ($FieldName) {
        'widthPx' {
            $value = Try-ParsePositiveInt $textWidthPx.Text
            if ($null -ne $value) { Set-FromWidthPx $value }
        }
        'heightPx' {
            $value = Try-ParsePositiveInt $textHeightPx.Text
            if ($null -ne $value) { Set-FromHeightPx $value }
        }
        'widthPct' {
            $value = Try-ParsePositiveDouble $textWidthPct.Text
            if ($null -ne $value) { Set-FromWidthPct $value }
        }
        'heightPct' {
            $value = Try-ParsePositiveDouble $textHeightPct.Text
            if ($null -ne $value) { Set-FromHeightPct $value }
        }
    }
}

function Register-EditTracking {
    param([System.Windows.Forms.TextBox]$TextBox)

    $TextBox.Add_Enter({
        param($sender, $eventArgs)
        $script:activeEditField = [string]$sender.Tag
    })

    $TextBox.Add_Leave({
        param($sender, $eventArgs)
        $fieldName = [string]$sender.Tag
        if ($script:activeEditField -ne $fieldName) { return }
        $script:activeEditField = $null
        Commit-Field $fieldName
    })
}

function Register-PercentTypingBehavior {
    param([System.Windows.Forms.TextBox]$TextBox)

    $TextBox.Add_KeyPress({
        param($sender, $eventArgs)

        if ([char]::IsControl($eventArgs.KeyChar)) { return }
        if ([char]::IsDigit($eventArgs.KeyChar)) { return }

        $decimalSeparator = [System.Globalization.CultureInfo]::CurrentCulture.NumberFormat.NumberDecimalSeparator
        if ($eventArgs.KeyChar.ToString() -eq '.' -or $eventArgs.KeyChar.ToString() -eq ',') {
            $selectionStart = $sender.SelectionStart
            $selectionLength = $sender.SelectionLength
            $currentText = $sender.Text
            $nextText = $currentText.Remove($selectionStart, $selectionLength).Insert($selectionStart, $decimalSeparator)

            if ($nextText.IndexOf($decimalSeparator, [System.StringComparison]::Ordinal) -eq $selectionStart) {
                $sender.Text = $nextText
                $sender.SelectionStart = $selectionStart + $decimalSeparator.Length
            }

            $eventArgs.Handled = $true
            return
        }

        $eventArgs.Handled = $true
    })

    $TextBox.Add_TextChanged({
        param($sender, $eventArgs)

        if ($script:updatingFields) { return }
        if ($script:activeEditField -ne [string]$sender.Tag) { return }

        $sanitized = [regex]::Replace($sender.Text, '[^\d\.,]', '')
        if ($sanitized -ne $sender.Text) {
            $selectionStart = $sender.SelectionStart
            $script:updatingFields = $true
            $sender.Text = $sanitized
            $sender.SelectionStart = [Math]::Min($selectionStart, $sender.Text.Length)
            $script:updatingFields = $false
        }
    })
}

$textWidthPx.Add_TextChanged({
    param($sender, $eventArgs)
    if ($script:updatingFields) { return }
    if ($script:activeEditField -ne [string]$sender.Tag) { return }
    $value = Try-ParsePositiveInt $sender.Text
    if ($null -eq $value) { return }
    Set-FromWidthPx $value
})

$textHeightPx.Add_TextChanged({
    param($sender, $eventArgs)
    if ($script:updatingFields) { return }
    if ($script:activeEditField -ne [string]$sender.Tag) { return }
    $value = Try-ParsePositiveInt $sender.Text
    if ($null -eq $value) { return }
    Set-FromHeightPx $value
})

$textWidthPct.Add_TextChanged({
    param($sender, $eventArgs)
    if ($script:updatingFields) { return }
    if ($script:activeEditField -ne [string]$sender.Tag) { return }
    $value = Try-ParsePositiveDouble $sender.Text
    if ($null -eq $value) { return }
    Set-FromWidthPct $value
})

$textHeightPct.Add_TextChanged({
    param($sender, $eventArgs)
    if ($script:updatingFields) { return }
    if ($script:activeEditField -ne [string]$sender.Tag) { return }
    $value = Try-ParsePositiveDouble $sender.Text
    if ($null -eq $value) { return }
    Set-FromHeightPct $value
})

$checkLockRatio.Add_CheckedChanged({
    if (-not $checkLockRatio.Checked) { return }

    $widthPx = Try-ParsePositiveInt $textWidthPx.Text
    if ($null -ne $widthPx) {
        Set-FromWidthPx $widthPx
        return
    }

    $heightPx = Try-ParsePositiveInt $textHeightPx.Text
    if ($null -ne $heightPx) {
        Set-FromHeightPx $heightPx
        return
    }

    Set-AllFields $origWidth $origHeight
})

Register-EditTracking $textWidthPx
Register-EditTracking $textHeightPx
Register-EditTracking $textWidthPct
Register-EditTracking $textHeightPct
Register-PercentTypingBehavior $textWidthPct
Register-PercentTypingBehavior $textHeightPct

foreach ($presetButton in $presetButtons) {
    $presetButton.Add_Click({
        param($sender, $eventArgs)
        Apply-ScalePreset ([double]$sender.Tag)
    })
}

$buttonReset.Add_Click({
    $checkLockRatio.Checked = $true
    Set-AllFields $origWidth $origHeight
    $textWidthPx.Focus()
    $textWidthPx.SelectAll()
})

Set-AllFields $origWidth $origHeight

$form.Add_Shown({
    $textWidthPx.Focus()
    $textWidthPx.SelectAll()
})

$result = $form.ShowDialog()
if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
    exit
}

$newWidth = Try-ParsePositiveInt $textWidthPx.Text
$newHeight = Try-ParsePositiveInt $textHeightPx.Text

if ($null -eq $newWidth -or $null -eq $newHeight) {
    Show-ErrorAndExit "Width and height must be positive values."
}

$inputDir = Split-Path -Parent $inputFile
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($inputFile)
$extension = [System.IO.Path]::GetExtension($inputFile)
$outputFile = Join-Path $inputDir ($baseName + "_resize_" + $newWidth + "x" + $newHeight + $extension)

$index = 1
while (Test-Path -LiteralPath $outputFile) {
    $outputFile = Join-Path $inputDir ($baseName + "_resize_" + $newWidth + "x" + $newHeight + "_" + $index + $extension)
    $index++
}

$inStream = $null
$inputImage = $null
$bitmap = $null
$graphics = $null

try {
    $inStream = [System.IO.File]::Open($inputFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $inputImage = [System.Drawing.Image]::FromStream($inStream, $false, $false)

    $bitmap = New-Object System.Drawing.Bitmap($newWidth, $newHeight)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.DrawImage($inputImage, 0, 0, $newWidth, $newHeight)

    $imageFormat = $inputImage.RawFormat
    $bitmap.Save($outputFile, $imageFormat)
}
catch {
    Show-ErrorAndExit "Resize failed."
}
finally {
    if ($graphics) { $graphics.Dispose() }
    if ($bitmap) { $bitmap.Dispose() }
    if ($inputImage) { $inputImage.Dispose() }
    if ($inStream) { $inStream.Dispose() }
}
