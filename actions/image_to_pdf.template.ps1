param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#__FFCOMMON_INJECT_HERE__

function Set-ControlDoubleBuffered {
    param([Parameter(Mandatory = $true)]$Control)

    $property = $Control.GetType().GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'Instance, NonPublic')
    if ($property) {
        $property.SetValue($Control, $true, $null)
    }
}

function Enable-ControlRedrawOptimizations {
    param([Parameter(Mandatory = $true)]$Control)

    Set-ControlDoubleBuffered -Control $Control

    $setStyleMethod = $Control.GetType().GetMethod('SetStyle', [System.Reflection.BindingFlags]'Instance, NonPublic')
    $updateStylesMethod = $Control.GetType().GetMethod('UpdateStyles', [System.Reflection.BindingFlags]'Instance, NonPublic')
    if ($null -eq $setStyleMethod -or $null -eq $updateStylesMethod) {
        return
    }

    $styles =
        [System.Windows.Forms.ControlStyles]::UserPaint -bor
        [System.Windows.Forms.ControlStyles]::AllPaintingInWmPaint -bor
        [System.Windows.Forms.ControlStyles]::OptimizedDoubleBuffer -bor
        [System.Windows.Forms.ControlStyles]::ResizeRedraw

    $setStyleMethod.Invoke($Control, @($styles, $true)) | Out-Null
    $updateStylesMethod.Invoke($Control, @()) | Out-Null
}

function Set-ToolbarIconButtonStyle {
    param([Parameter(Mandatory = $true)][System.Windows.Forms.Button]$Button)

    $Button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $Button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(196, 196, 196)
    $Button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(246, 246, 246)
    $Button.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(236, 236, 236)
    $Button.TextImageRelation = [System.Windows.Forms.TextImageRelation]::ImageAboveText
    $Button.ImageAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $Button.TextAlign = [System.Drawing.ContentAlignment]::BottomCenter
    $Button.Padding = New-Object System.Windows.Forms.Padding(0, 2, 0, 2)
    $Button.Font = New-Object System.Drawing.Font('Segoe UI', 7.0, [System.Drawing.FontStyle]::Regular)
}

function Set-CompactToolbarIconButtonStyle {
    param([Parameter(Mandatory = $true)][System.Windows.Forms.Button]$Button)

    Set-ToolbarIconButtonStyle -Button $Button
    $Button.Font = New-Object System.Drawing.Font('Segoe UI', 6.5, [System.Drawing.FontStyle]::Regular)
    $Button.Padding = New-Object System.Windows.Forms.Padding(0, 1, 0, 1)
}

function Get-FFActionsWindowIcon {
    $iconPath = Join-Path (Get-AppRoot) 'tools\icons\ffactions.ico'
    if (-not (Test-Path -LiteralPath $iconPath)) {
        return $null
    }

    try {
        return New-Object System.Drawing.Icon($iconPath)
    }
    catch {
        return $null
    }
}

function Get-ToolbarPngIconBitmap {
    param(
        [Parameter(Mandatory = $true)][string]$BaseName,
        [int[]]$PreferredSizes = @(30, 40, 16, 80)
    )

    $iconsDir = Join-Path (Get-AppRoot) 'tools\icons'
    foreach ($size in $PreferredSizes) {
        $iconPath = Join-Path $iconsDir ("{0}-{1}.png" -f $BaseName, $size)
        if (-not (Test-Path -LiteralPath $iconPath)) {
            continue
        }

        try {
            $stream = New-Object System.IO.FileStream($iconPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            try {
                $loadedImage = [System.Drawing.Image]::FromStream($stream)
                return New-Object System.Drawing.Bitmap($loadedImage)
            }
            finally {
                if ($null -ne $loadedImage) {
                    $loadedImage.Dispose()
                }
                $stream.Dispose()
            }
        }
        catch {
        }
    }

    return $null
}

function Get-ToolbarMenuIconBitmap {
    param(
        [Parameter(Mandatory = $true)][string]$IconFileName,
        [int]$Width = 24,
        [int]$Height = 20
    )

    $iconPath = Join-Path (Join-Path (Get-AppRoot) 'tools\icons\image.to.pdf.menu') $IconFileName
    if (-not (Test-Path -LiteralPath $iconPath)) {
        return $null
    }

    $icon = $null
    $sourceBitmap = $null
    $scaledBitmap = $null
    $graphics = $null

    try {
        $icon = New-Object System.Drawing.Icon($iconPath)
        $sourceBitmap = $icon.ToBitmap()
        $scaledBitmap = New-Object System.Drawing.Bitmap($Width, $Height)
        $graphics = [System.Drawing.Graphics]::FromImage($scaledBitmap)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.DrawImage($sourceBitmap, 0, 0, $Width, $Height)
        return $scaledBitmap
    }
    catch {
        if ($null -ne $scaledBitmap) {
            $scaledBitmap.Dispose()
        }
        return $null
    }
    finally {
        if ($null -ne $graphics) { $graphics.Dispose() }
        if ($null -ne $sourceBitmap) { $sourceBitmap.Dispose() }
        if ($null -ne $icon) { $icon.Dispose() }
    }
}

function Draw-PreviewHandleSegment {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Graphics]$Graphics,
        [Parameter(Mandatory = $true)][double]$X,
        [Parameter(Mandatory = $true)][double]$Y,
        [Parameter(Mandatory = $true)][double]$Width,
        [Parameter(Mandatory = $true)][double]$Height,
        [Parameter(Mandatory = $true)][System.Drawing.Brush]$FillBrush,
        [Parameter(Mandatory = $true)][System.Drawing.Pen]$BorderPen
    )

    if ($Width -le 0.0 -or $Height -le 0.0) {
        return
    }

    $rect = New-Object System.Drawing.RectangleF([float]$X, [float]$Y, [float]$Width, [float]$Height)
    $Graphics.FillRectangle($FillBrush, $rect)
    $Graphics.DrawRectangle($BorderPen, $rect.X, $rect.Y, $rect.Width, $rect.Height)
}

function Draw-CropPreviewHandle {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Graphics]$Graphics,
        [Parameter(Mandatory = $true)]$HandleRect,
        [Parameter(Mandatory = $true)][string]$HandleName,
        [Parameter(Mandatory = $true)][System.Drawing.Brush]$FillBrush,
        [Parameter(Mandatory = $true)][System.Drawing.Pen]$BorderPen
    )

    $x = [double]$HandleRect.X
    $y = [double]$HandleRect.Y
    $width = [double]$HandleRect.Width
    $height = [double]$HandleRect.Height
    $size = [Math]::Min($width, $height)
    $thickness = [Math]::Max(2.0, [Math]::Round($size * 0.32))
    $segmentLength = [Math]::Max($thickness + 4.0, [Math]::Round($size * 1.56))

    switch ($HandleName) {
        'TopLeft' {
            Draw-PreviewHandleSegment -Graphics $Graphics -X $x -Y $y -Width $segmentLength -Height $thickness -FillBrush $FillBrush -BorderPen $BorderPen
            Draw-PreviewHandleSegment -Graphics $Graphics -X $x -Y $y -Width $thickness -Height $segmentLength -FillBrush $FillBrush -BorderPen $BorderPen
        }
        'TopRight' {
            Draw-PreviewHandleSegment -Graphics $Graphics -X ($x + $width - $segmentLength) -Y $y -Width $segmentLength -Height $thickness -FillBrush $FillBrush -BorderPen $BorderPen
            Draw-PreviewHandleSegment -Graphics $Graphics -X ($x + $width - $thickness) -Y $y -Width $thickness -Height $segmentLength -FillBrush $FillBrush -BorderPen $BorderPen
        }
        'BottomRight' {
            Draw-PreviewHandleSegment -Graphics $Graphics -X ($x + $width - $segmentLength) -Y ($y + $height - $thickness) -Width $segmentLength -Height $thickness -FillBrush $FillBrush -BorderPen $BorderPen
            Draw-PreviewHandleSegment -Graphics $Graphics -X ($x + $width - $thickness) -Y ($y + $height - $segmentLength) -Width $thickness -Height $segmentLength -FillBrush $FillBrush -BorderPen $BorderPen
        }
        'BottomLeft' {
            Draw-PreviewHandleSegment -Graphics $Graphics -X $x -Y ($y + $height - $thickness) -Width $segmentLength -Height $thickness -FillBrush $FillBrush -BorderPen $BorderPen
            Draw-PreviewHandleSegment -Graphics $Graphics -X $x -Y ($y + $height - $segmentLength) -Width $thickness -Height $segmentLength -FillBrush $FillBrush -BorderPen $BorderPen
        }
        'Top' {
            Draw-PreviewHandleSegment -Graphics $Graphics -X ($x + (($width - $segmentLength) / 2.0)) -Y $y -Width $segmentLength -Height $thickness -FillBrush $FillBrush -BorderPen $BorderPen
        }
        'Right' {
            Draw-PreviewHandleSegment -Graphics $Graphics -X ($x + $width - $thickness) -Y ($y + (($height - $segmentLength) / 2.0)) -Width $thickness -Height $segmentLength -FillBrush $FillBrush -BorderPen $BorderPen
        }
        'Bottom' {
            Draw-PreviewHandleSegment -Graphics $Graphics -X ($x + (($width - $segmentLength) / 2.0)) -Y ($y + $height - $thickness) -Width $segmentLength -Height $thickness -FillBrush $FillBrush -BorderPen $BorderPen
        }
        'Left' {
            Draw-PreviewHandleSegment -Graphics $Graphics -X $x -Y ($y + (($height - $segmentLength) / 2.0)) -Width $thickness -Height $segmentLength -FillBrush $FillBrush -BorderPen $BorderPen
        }
        default {
            $Graphics.FillRectangle($FillBrush, $HandleRect.X, $HandleRect.Y, $HandleRect.Width, $HandleRect.Height)
            $Graphics.DrawRectangle($BorderPen, $HandleRect.X, $HandleRect.Y, $HandleRect.Width, $HandleRect.Height)
        }
    }
}

function New-CropIconBitmap {
    param(
        [int]$Width = 24,
        [int]$Height = 20
    )

    $menuBitmap = Get-ToolbarMenuIconBitmap -IconFileName 'Crop_icon.ico' -Width $Width -Height $Height
    if ($null -ne $menuBitmap) {
        return $menuBitmap
    }

    $fileBitmap = Get-ToolbarPngIconBitmap -BaseName 'icons8-crop'
    if ($null -ne $fileBitmap) {
        return $fileBitmap
    }

    $bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $orangePen = $null
    $blackPen = $null
    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $orangePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(214, 120, 24), 1.8)
        $blackPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, 70, 70), 1.4)

        $graphics.DrawLine($orangePen, 4, 2, 4, 16)
        $graphics.DrawLine($orangePen, 4, 9, 17, 9)
        $graphics.DrawLine($blackPen, 8, 4, 20, 4)
        $graphics.DrawLine($blackPen, 14, 4, 14, 18)
        $graphics.DrawLine($blackPen, 14, 9, 20, 9)
        $graphics.DrawLine($blackPen, 8, 14, 14, 14)
    }
    finally {
        if ($null -ne $orangePen) { $orangePen.Dispose() }
        if ($null -ne $blackPen) { $blackPen.Dispose() }
        $graphics.Dispose()
    }

    return $bitmap
}

function New-ActionIconBitmap {
    param(
        [Parameter(Mandatory = $true)][string]$Mode,
        [int]$Width = 24,
        [int]$Height = 20
    )

    $menuIconName = $null
    $iconBaseName = $null
    switch ($Mode) {
        'AddImages' {
            $menuIconName = 'add.image_icon.ico'
            $iconBaseName = 'icons8-add-image'
        }
        'FitPage' {
            $menuIconName = 'fit.to.page_icon.ico'
        }
        'Center' {
            $menuIconName = 'center_icon.ico'
        }
        'Print' {
            $menuIconName = 'print_icon.ico'
            $iconBaseName = 'icons8-print'
        }
        'Export' {
            $menuIconName = 'export_icon.ico'
            $iconBaseName = 'icons8-export-pdf'
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($menuIconName)) {
        $menuBitmap = Get-ToolbarMenuIconBitmap -IconFileName $menuIconName -Width $Width -Height $Height
        if ($null -ne $menuBitmap) {
            return $menuBitmap
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($iconBaseName)) {
        $fileBitmap = Get-ToolbarPngIconBitmap -BaseName $iconBaseName
        if ($null -ne $fileBitmap) {
            return $fileBitmap
        }
    }

    $bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $orangePen = $null
    $grayPen = $null
    $orangeBrush = $null
    $grayBrush = $null
    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $orangePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(214, 120, 24), 1.4)
        $grayPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(110, 110, 110), 1.2)
        $orangeBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 245, 230))
        $grayBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)

        switch ($Mode) {
            'AddImages' {
                $graphics.FillRectangle($grayBrush, 3, 4, 12, 10)
                $graphics.DrawRectangle($grayPen, 3, 4, 12, 10)
                $graphics.DrawLine($grayPen, 5, 12, 8, 9)
                $graphics.DrawLine($grayPen, 8, 9, 11, 11)
                $graphics.DrawEllipse($grayPen, 5, 6, 2, 2)
                $graphics.DrawLine($orangePen, 18, 7, 18, 15)
                $graphics.DrawLine($orangePen, 14, 11, 22, 11)
            }
            'FitPage' {
                $graphics.DrawRectangle($grayPen, 6, 3, 12, 14)
                $graphics.DrawLine($orangePen, 2, 6, 6, 6)
                $graphics.DrawLine($orangePen, 2, 6, 4, 4)
                $graphics.DrawLine($orangePen, 2, 6, 4, 8)
                $graphics.DrawLine($orangePen, 22, 6, 18, 6)
                $graphics.DrawLine($orangePen, 22, 6, 20, 4)
                $graphics.DrawLine($orangePen, 22, 6, 20, 8)
                $graphics.DrawLine($orangePen, 2, 14, 6, 14)
                $graphics.DrawLine($orangePen, 2, 14, 4, 12)
                $graphics.DrawLine($orangePen, 2, 14, 4, 16)
                $graphics.DrawLine($orangePen, 22, 14, 18, 14)
                $graphics.DrawLine($orangePen, 22, 14, 20, 12)
                $graphics.DrawLine($orangePen, 22, 14, 20, 16)
            }
            'Center' {
                $graphics.DrawRectangle($grayPen, 5, 3, 14, 14)
                $graphics.DrawLine($orangePen, 12, 1, 12, 19)
                $graphics.DrawLine($orangePen, 9, 5, 12, 2)
                $graphics.DrawLine($orangePen, 15, 5, 12, 2)
                $graphics.DrawLine($orangePen, 9, 15, 12, 18)
                $graphics.DrawLine($orangePen, 15, 15, 12, 18)
            }
            'Print' {
                $graphics.DrawRectangle($grayPen, 6, 2, 10, 5)
                $graphics.DrawRectangle($grayPen, 4, 7, 14, 7)
                $graphics.DrawRectangle($grayPen, 7, 12, 8, 6)
                $graphics.DrawLine($orangePen, 16, 9, 20, 9)
                $graphics.DrawLine($orangePen, 18, 7, 20, 9)
                $graphics.DrawLine($orangePen, 18, 11, 20, 9)
            }
            'Export' {
                $graphics.DrawRectangle($grayPen, 5, 2, 10, 14)
                $graphics.DrawLine($grayPen, 12, 2, 15, 5)
                $graphics.DrawLine($grayPen, 12, 2, 12, 5)
                $graphics.DrawLine($grayPen, 12, 5, 15, 5)
                $graphics.DrawLine($orangePen, 18, 9, 10, 9)
                $graphics.DrawLine($orangePen, 14, 5, 10, 9)
                $graphics.DrawLine($orangePen, 14, 13, 10, 9)
            }
        }
    }
    finally {
        if ($null -ne $orangePen) { $orangePen.Dispose() }
        if ($null -ne $grayPen) { $grayPen.Dispose() }
        if ($null -ne $orangeBrush) { $orangeBrush.Dispose() }
        if ($null -ne $grayBrush) { $grayBrush.Dispose() }
        $graphics.Dispose()
    }

    return $bitmap
}

function New-LayerOrderIconBitmap {
    param(
        [Parameter(Mandatory = $true)][string]$Mode,
        [int]$Width = 24,
        [int]$Height = 20
    )

    $menuIconName = $null
    $iconBaseName = $null
    switch ($Mode) {
        'Back' {
            $menuIconName = 'send.to.back_icon.ico'
            $iconBaseName = 'icons8-send-to-back'
        }
        'BackOne' {
            $menuIconName = 'send.backward_icon.ico'
            $iconBaseName = 'icons8-send-to-back'
        }
        'ForwardOne' {
            $menuIconName = 'bring.forward_icon.ico'
            $iconBaseName = 'icons8-bring-forward'
        }
        'Front' {
            $menuIconName = 'Bring.to.front_icon.ico'
            $iconBaseName = 'icons8-bring-to-front'
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($menuIconName)) {
        $menuBitmap = Get-ToolbarMenuIconBitmap -IconFileName $menuIconName -Width $Width -Height $Height
        if ($null -ne $menuBitmap) {
            return $menuBitmap
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($iconBaseName)) {
        $fileBitmap = Get-ToolbarPngIconBitmap -BaseName $iconBaseName
        if ($null -ne $fileBitmap) {
            return $fileBitmap
        }
    }

    $bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $orangePen = $null
    $grayPen = $null
    $orangeBrush = $null
    $grayBrush = $null
    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $orangePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(214, 120, 24), 1.2)
        $grayPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120, 120, 120), 1.2)
        $orangeBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 245, 230))
        $grayBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)

        switch ($Mode) {
            'Back' {
                $graphics.FillRectangle($orangeBrush, 4, 6, 8, 8)
                $graphics.DrawRectangle($orangePen, 4, 6, 8, 8)
                $graphics.FillRectangle($grayBrush, 10, 2, 10, 10)
                $graphics.DrawRectangle($grayPen, 10, 2, 10, 10)
                $graphics.FillRectangle($grayBrush, 12, 10, 8, 8)
                $graphics.DrawRectangle($grayPen, 12, 10, 8, 8)
            }
            'BackOne' {
                $graphics.FillRectangle($orangeBrush, 6, 4, 10, 10)
                $graphics.DrawRectangle($orangePen, 6, 4, 10, 10)
                $graphics.FillRectangle($grayBrush, 10, 8, 10, 10)
                $graphics.DrawRectangle($grayPen, 10, 8, 10, 10)
            }
            'ForwardOne' {
                $graphics.FillRectangle($grayBrush, 6, 8, 10, 10)
                $graphics.DrawRectangle($grayPen, 6, 8, 10, 10)
                $graphics.FillRectangle($orangeBrush, 10, 4, 10, 10)
                $graphics.DrawRectangle($orangePen, 10, 4, 10, 10)
            }
            'Front' {
                $graphics.FillRectangle($grayBrush, 4, 6, 8, 8)
                $graphics.DrawRectangle($grayPen, 4, 6, 8, 8)
                $graphics.FillRectangle($grayBrush, 6, 2, 8, 8)
                $graphics.DrawRectangle($grayPen, 6, 2, 8, 8)
                $graphics.FillRectangle($orangeBrush, 12, 8, 10, 10)
                $graphics.DrawRectangle($orangePen, 12, 8, 10, 10)
            }
        }
    }
    finally {
        if ($null -ne $orangePen) { $orangePen.Dispose() }
        if ($null -ne $grayPen) { $grayPen.Dispose() }
        if ($null -ne $orangeBrush) { $orangeBrush.Dispose() }
        if ($null -ne $grayBrush) { $grayBrush.Dispose() }
        $graphics.Dispose()
    }

    return $bitmap
}

function Copy-PdfRect {
    param([Parameter(Mandatory = $true)]$Rect)

    return [PSCustomObject]@{
        X      = [double]$Rect.X
        Y      = [double]$Rect.Y
        Width  = [double]$Rect.Width
        Height = [double]$Rect.Height
    }
}

function Get-ImageItemRotationAngle {
    param([Parameter(Mandatory = $true)]$Item)

    if ($null -ne $Item.PSObject.Properties['RotationAngle']) {
        return [double]$Item.RotationAngle
    }

    return 0.0
}

function Get-ImageItemCrop {
    param([Parameter(Mandatory = $true)]$Item)

    if ($null -ne $Item.PSObject.Properties['Crop']) {
        return Get-NormalizedImageCrop -Crop $Item.Crop
    }

    return New-DefaultImageCrop
}

function Draw-PreviewImageItem {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Graphics]$Graphics,
        [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap,
        [Parameter(Mandatory = $true)]$PdfRect,
        [Parameter(Mandatory = $true)]$PreviewPageRect,
        [double]$RotationAngle = 0.0,
        $Crop = $null,
        [double]$Alpha = 1.0
    )

    $outerPreviewRect = Convert-PdfRectToPreviewRect -PdfRect $PdfRect -PreviewPageRect $PreviewPageRect
    $normalizedCrop = Get-NormalizedImageCrop -Crop $Crop
    $sourceRect = Get-BitmapSourceRectFromCrop -Bitmap $Bitmap -Crop $normalizedCrop
    $centerX = $outerPreviewRect.X + ($outerPreviewRect.Width / 2.0)
    $centerY = $outerPreviewRect.Y + ($outerPreviewRect.Height / 2.0)
    $state = $Graphics.Save()
    $imageAttributes = $null
    try {
        $Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $Graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $Graphics.TranslateTransform([float]$centerX, [float]$centerY)
        if ([Math]::Abs($RotationAngle) -gt 0.001) {
            $Graphics.RotateTransform([float]$RotationAngle)
        }
        $drawOffsetX = [float]($outerPreviewRect.X - $centerX)
        $drawOffsetY = [float]($outerPreviewRect.Y - $centerY)
        $destRect = New-Object System.Drawing.RectangleF($drawOffsetX, $drawOffsetY, [float]$outerPreviewRect.Width, [float]$outerPreviewRect.Height)
        if ($Alpha -lt 0.999) {
            $colorMatrix = New-Object System.Drawing.Imaging.ColorMatrix
            $colorMatrix.Matrix33 = [single]$Alpha
            $imageAttributes = New-Object System.Drawing.Imaging.ImageAttributes
            $imageAttributes.SetColorMatrix($colorMatrix, [System.Drawing.Imaging.ColorMatrixFlag]::Default, [System.Drawing.Imaging.ColorAdjustType]::Bitmap)
            $Graphics.DrawImage($Bitmap, [System.Drawing.Rectangle]::Round($destRect), $sourceRect.X, $sourceRect.Y, $sourceRect.Width, $sourceRect.Height, [System.Drawing.GraphicsUnit]::Pixel, $imageAttributes)
        }
        else {
            $Graphics.DrawImage($Bitmap, $destRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
        }
    }
    finally {
        if ($null -ne $imageAttributes) {
            $imageAttributes.Dispose()
        }
        $Graphics.Restore($state)
    }
}

function Get-PdfRectAlignmentReferences {
    param([Parameter(Mandatory = $true)]$Rect)

    return [PSCustomObject]@{
        Left    = [double]$Rect.X
        CenterX = [double]$Rect.X + ([double]$Rect.Width / 2.0)
        Right   = [double]$Rect.X + [double]$Rect.Width
        Top     = [double]$Rect.Y
        CenterY = [double]$Rect.Y + ([double]$Rect.Height / 2.0)
        Bottom  = [double]$Rect.Y + [double]$Rect.Height
    }
}

function Get-NormalizedRotationAngle {
    param([Parameter(Mandatory = $true)][double]$Angle)

    $normalized = $Angle % 360.0
    if ($normalized -lt 0.0) {
        $normalized += 360.0
    }

    return $normalized
}

function Get-SnappedRotationAngle {
    param(
        [Parameter(Mandatory = $true)][double]$Angle,
        [Parameter(Mandatory = $true)][double]$ToleranceDegrees
    )

    $normalized = Get-NormalizedRotationAngle -Angle $Angle
    $targets = @(0.0, 90.0, 180.0, 270.0, 360.0)
    $bestTarget = $null
    $bestDelta = $null

    foreach ($target in $targets) {
        $delta = [Math]::Abs($normalized - $target)
        if ($null -eq $bestDelta -or $delta -lt $bestDelta) {
            $bestDelta = $delta
            $bestTarget = $target
        }
    }

    if ($bestDelta -le $ToleranceDegrees) {
        if ($bestTarget -ge 360.0) {
            $bestTarget = 0.0
        }

        return $bestTarget
    }

    return $Angle
}

function Apply-SnapToPdfRect {
    param(
        [Parameter(Mandatory = $true)]$PdfRect,
        [Parameter(Mandatory = $true)][System.Collections.Generic.List[object]]$AllItems,
        [Parameter(Mandatory = $true)][int]$ActiveIndex,
        [Parameter(Mandatory = $true)]$PreviewPageRect,
        [Parameter(Mandatory = $true)][double]$TolerancePreview,
        [string]$PageFormat = 'A4',
        [double]$PageWidthMillimeters = 0.0,
        [double]$PageHeightMillimeters = 0.0,
        [switch]$ResizeMode
    )

    $candidate = Copy-PdfRect -Rect $PdfRect
    $candidateRefs = Get-PdfRectAlignmentReferences -Rect $candidate
    $bestDeltaXPreview = $null
    $bestDeltaYPReview = $null
    $guideX = $null
    $guideY = $null
    $tolerancePdf = $TolerancePreview / [double]$PreviewPageRect.Scale

    for ($index = 0; $index -lt $AllItems.Count; $index++) {
        if ($index -eq $ActiveIndex) {
            continue
        }

        $otherItem = $AllItems[$index]
        if ($null -eq $otherItem -or $null -eq $otherItem.PdfRect) {
            continue
        }

        $otherRefs = Get-PdfRectAlignmentReferences -Rect $otherItem.PdfRect
        foreach ($candidateKey in @('Left', 'CenterX', 'Right')) {
            foreach ($otherKey in @('Left', 'CenterX', 'Right')) {
                $deltaPdf = [double]$otherRefs.$otherKey - [double]$candidateRefs.$candidateKey
                if ([Math]::Abs($deltaPdf) -le $tolerancePdf) {
                    $deltaPreview = $deltaPdf * [double]$PreviewPageRect.Scale
                    if ($null -eq $bestDeltaXPreview -or [Math]::Abs($deltaPreview) -lt [Math]::Abs($bestDeltaXPreview)) {
                        $bestDeltaXPreview = $deltaPreview
                        $guideX = [double]$otherRefs.$otherKey
                    }
                }
            }
        }

        foreach ($candidateKey in @('Top', 'CenterY', 'Bottom')) {
            foreach ($otherKey in @('Top', 'CenterY', 'Bottom')) {
                $deltaPdf = [double]$otherRefs.$otherKey - [double]$candidateRefs.$candidateKey
                if ([Math]::Abs($deltaPdf) -le $tolerancePdf) {
                    $deltaPreview = $deltaPdf * [double]$PreviewPageRect.Scale
                    if ($null -eq $bestDeltaYPReview -or [Math]::Abs($deltaPreview) -lt [Math]::Abs($bestDeltaYPReview)) {
                        $bestDeltaYPReview = $deltaPreview
                        $guideY = [double]$otherRefs.$otherKey
                    }
                }
            }
        }
    }

    $deltaXPdf = 0.0
    $deltaYPdf = 0.0
    if ($null -ne $bestDeltaXPreview) {
        $deltaXPdf = $bestDeltaXPreview / [double]$PreviewPageRect.Scale
    }
    if ($null -ne $bestDeltaYPReview) {
        $deltaYPdf = $bestDeltaYPReview / [double]$PreviewPageRect.Scale
    }

    $snappedRect = [PSCustomObject]@{
        X      = [double]$candidate.X + $deltaXPdf
        Y      = [double]$candidate.Y + $deltaYPdf
        Width  = [double]$candidate.Width
        Height = [double]$candidate.Height
    }

    $snappedRect = Clamp-PdfImageRectToPage -ImageRect $snappedRect -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters

    return [PSCustomObject]@{
        Rect   = $snappedRect
        GuideX = $guideX
        GuideY = $guideY
    }
}

function Move-ImageItemToIndex {
    param(
        [Parameter(Mandatory = $true)][System.Collections.Generic.List[object]]$Items,
        [Parameter(Mandatory = $true)][int]$SourceIndex,
        [Parameter(Mandatory = $true)][int]$TargetIndex
    )

    if ($SourceIndex -lt 0 -or $SourceIndex -ge $Items.Count) {
        return $SourceIndex
    }

    if ($TargetIndex -lt 0) {
        $TargetIndex = 0
    }
    elseif ($TargetIndex -ge $Items.Count) {
        $TargetIndex = $Items.Count - 1
    }

    if ($SourceIndex -eq $TargetIndex) {
        return $SourceIndex
    }

    $item = $Items[$SourceIndex]
    $Items.RemoveAt($SourceIndex)
    $Items.Insert($TargetIndex, $item)
    return $TargetIndex
}

function Swap-ImageItems {
    param(
        [Parameter(Mandatory = $true)][System.Collections.Generic.List[object]]$Items,
        [Parameter(Mandatory = $true)][int]$FirstIndex,
        [Parameter(Mandatory = $true)][int]$SecondIndex
    )

    if ($FirstIndex -lt 0 -or $FirstIndex -ge $Items.Count) {
        return $FirstIndex
    }

    if ($SecondIndex -lt 0 -or $SecondIndex -ge $Items.Count) {
        return $FirstIndex
    }

    if ($FirstIndex -eq $SecondIndex) {
        return $FirstIndex
    }

    $firstItem = $Items[$FirstIndex]
    $Items[$FirstIndex] = $Items[$SecondIndex]
    $Items[$SecondIndex] = $firstItem
    return $SecondIndex
}

function Show-ImageToPdfWindow {
    param(
        [Parameter(Mandatory = $true)][System.Collections.Generic.List[object]]$ImageItems,
        [string]$InitialPageFormat = 'A4'
    )

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $script:ImageToPdfItems = $ImageItems
    $script:ActiveImageIndex = 0
    $script:ImageToPdfInteractionMode = 'None'
    $script:ImageToPdfPointerStart = $null
    $script:ImageToPdfRectStart = $null
    $script:ImageToPdfResizeHandle = $null
    $script:ImageToPdfResizeHandleSize = 10
    $script:ImageToPdfRotationHandleDiameter = 12
    $script:ImageToPdfCropMode = $false
    $script:ImageToPdfCropHandle = $null
    $script:ImageToPdfCropStart = $null
    $script:ImageToPdfCropFullRectStart = $null
    $script:ImageToPdfCropHandleSize = 10
    $script:ImageToPdfSnapEnabled = $true
    $script:ImageToPdfSnapTolerancePreview = 8.0
    $script:ImageToPdfRotationSnapToleranceDegrees = 4.0
    $script:ImageToPdfSnapGuideX = $null
    $script:ImageToPdfSnapGuideY = $null
    $script:ImageToPdfMaxImages = 10
    $script:ImageToPdfPageFormat = if ([string]::IsNullOrWhiteSpace($InitialPageFormat)) { 'A4' } else { $InitialPageFormat.ToUpperInvariant() }
    $script:ImageToPdfPageWidthCm = 21.0
    $script:ImageToPdfPageHeightCm = 29.7
    $script:ImageToPdfLockAspectRatio = $true

    switch ($script:ImageToPdfPageFormat) {
        'A3' {
            $script:ImageToPdfPageWidthCm = 29.7
            $script:ImageToPdfPageHeightCm = 42.0
        }
        default {
            $script:ImageToPdfPageFormat = 'A4'
        }
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFActions - Image to PDF'
    $form.StartPosition = 'CenterScreen'
    $form.MinimumSize = New-Object System.Drawing.Size(960, 720)
    $form.ClientSize = New-Object System.Drawing.Size(1120, 780)
    $form.ShowIcon = $false
    $form.ShowInTaskbar = $true
    $windowIcon = Get-FFActionsWindowIcon
    if ($null -ne $windowIcon) {
        $form.Icon = $windowIcon
    }
    Enable-ControlRedrawOptimizations -Control $form

    $previewPanel = New-Object System.Windows.Forms.Panel
    $previewPanel.Location = New-Object System.Drawing.Point(12, 12)
    $previewPanel.Size = New-Object System.Drawing.Size(860, 700)
    $previewPanel.Anchor = 'Top,Bottom,Left,Right'
    $previewPanel.BackColor = [System.Drawing.Color]::FromArgb(236, 236, 236)
    $previewPanel.AllowDrop = $true
    Enable-ControlRedrawOptimizations -Control $previewPanel
    $form.Controls.Add($previewPanel)

    $buttonExport = New-Object System.Windows.Forms.Button
    $buttonExport.Text = 'Export'
    $buttonExport.Location = New-Object System.Drawing.Point(890, 24)
    $buttonExport.Size = New-Object System.Drawing.Size(92, 54)
    $buttonExport.Anchor = 'Top,Right'
    $form.Controls.Add($buttonExport)

    $buttonPrint = New-Object System.Windows.Forms.Button
    $buttonPrint.Text = 'Print'
    $buttonPrint.Location = New-Object System.Drawing.Point(988, 24)
    $buttonPrint.Size = New-Object System.Drawing.Size(92, 54)
    $buttonPrint.Anchor = 'Top,Right'
    $form.Controls.Add($buttonPrint)

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.Location = New-Object System.Drawing.Point(890, 88)
    $buttonCancel.Size = New-Object System.Drawing.Size(190, 34)
    $buttonCancel.Anchor = 'Top,Right'
    $form.Controls.Add($buttonCancel)

    $labelActive = New-Object System.Windows.Forms.Label
    $labelActive.Location = New-Object System.Drawing.Point(890, 130)
    $labelActive.Size = New-Object System.Drawing.Size(190, 20)
    $labelActive.Anchor = 'Top,Right'
    $form.Controls.Add($labelActive)

    $buttonAddImages = New-Object System.Windows.Forms.Button
    $buttonAddImages.Text = 'Add Images...'
    $buttonAddImages.Location = New-Object System.Drawing.Point(890, 160)
    $buttonAddImages.Size = New-Object System.Drawing.Size(190, 54)
    $buttonAddImages.Anchor = 'Top,Right'
    $form.Controls.Add($buttonAddImages)

    $buttonFitToPage = New-Object System.Windows.Forms.Button
    $buttonFitToPage.Text = 'Fit to page'
    $buttonFitToPage.Location = New-Object System.Drawing.Point(890, 220)
    $buttonFitToPage.Size = New-Object System.Drawing.Size(92, 54)
    $buttonFitToPage.Anchor = 'Top,Right'
    $form.Controls.Add($buttonFitToPage)

    $buttonCenter = New-Object System.Windows.Forms.Button
    $buttonCenter.Text = 'Center'
    $buttonCenter.Location = New-Object System.Drawing.Point(988, 220)
    $buttonCenter.Size = New-Object System.Drawing.Size(92, 54)
    $buttonCenter.Anchor = 'Top,Right'
    $form.Controls.Add($buttonCenter)

    $buttonCrop = New-Object System.Windows.Forms.Button
    $buttonCrop.Text = 'Crop'
    $buttonCrop.Location = New-Object System.Drawing.Point(890, 280)
    $buttonCrop.Size = New-Object System.Drawing.Size(190, 54)
    $buttonCrop.Anchor = 'Top,Right'
    $form.Controls.Add($buttonCrop)

    $checkBoxLockAspectRatio = New-Object System.Windows.Forms.CheckBox
    $checkBoxLockAspectRatio.Text = 'Lock aspect ratio'
    $checkBoxLockAspectRatio.Location = New-Object System.Drawing.Point(890, 340)
    $checkBoxLockAspectRatio.Size = New-Object System.Drawing.Size(190, 24)
    $checkBoxLockAspectRatio.Anchor = 'Top,Right'
    $checkBoxLockAspectRatio.Checked = $script:ImageToPdfLockAspectRatio
    $form.Controls.Add($checkBoxLockAspectRatio)

    $labelPageFormat = New-Object System.Windows.Forms.Label
    $labelPageFormat.Text = 'Page size'
    $labelPageFormat.Location = New-Object System.Drawing.Point(890, 370)
    $labelPageFormat.Size = New-Object System.Drawing.Size(190, 18)
    $labelPageFormat.Anchor = 'Top,Right'
    $form.Controls.Add($labelPageFormat)

    $radioPageA4 = New-Object System.Windows.Forms.RadioButton
    $radioPageA4.Text = 'A4'
    $radioPageA4.Location = New-Object System.Drawing.Point(890, 390)
    $radioPageA4.Size = New-Object System.Drawing.Size(50, 22)
    $radioPageA4.Anchor = 'Top,Right'
    $radioPageA4.Checked = ($script:ImageToPdfPageFormat -eq 'A4')
    $form.Controls.Add($radioPageA4)

    $radioPageA3 = New-Object System.Windows.Forms.RadioButton
    $radioPageA3.Text = 'A3'
    $radioPageA3.Location = New-Object System.Drawing.Point(944, 390)
    $radioPageA3.Size = New-Object System.Drawing.Size(50, 22)
    $radioPageA3.Anchor = 'Top,Right'
    $radioPageA3.Checked = ($script:ImageToPdfPageFormat -eq 'A3')
    $form.Controls.Add($radioPageA3)

    $radioPageCustom = New-Object System.Windows.Forms.RadioButton
    $radioPageCustom.Text = 'Custom'
    $radioPageCustom.Location = New-Object System.Drawing.Point(998, 390)
    $radioPageCustom.Size = New-Object System.Drawing.Size(82, 22)
    $radioPageCustom.Anchor = 'Top,Right'
    $radioPageCustom.Checked = ($script:ImageToPdfPageFormat -eq 'CUSTOM')
    $form.Controls.Add($radioPageCustom)

    $labelPageWidth = New-Object System.Windows.Forms.Label
    $labelPageWidth.Text = 'Width (cm)'
    $labelPageWidth.Location = New-Object System.Drawing.Point(890, 418)
    $labelPageWidth.Size = New-Object System.Drawing.Size(90, 18)
    $labelPageWidth.Anchor = 'Top,Right'
    $form.Controls.Add($labelPageWidth)

    $textPageWidth = New-Object System.Windows.Forms.TextBox
    $textPageWidth.Location = New-Object System.Drawing.Point(986, 415)
    $textPageWidth.Size = New-Object System.Drawing.Size(94, 23)
    $textPageWidth.Anchor = 'Top,Right'
    $form.Controls.Add($textPageWidth)

    $labelPageHeight = New-Object System.Windows.Forms.Label
    $labelPageHeight.Text = 'Height (cm)'
    $labelPageHeight.Location = New-Object System.Drawing.Point(890, 448)
    $labelPageHeight.Size = New-Object System.Drawing.Size(90, 18)
    $labelPageHeight.Anchor = 'Top,Right'
    $form.Controls.Add($labelPageHeight)

    $textPageHeight = New-Object System.Windows.Forms.TextBox
    $textPageHeight.Location = New-Object System.Drawing.Point(986, 445)
    $textPageHeight.Size = New-Object System.Drawing.Size(94, 23)
    $textPageHeight.Anchor = 'Top,Right'
    $form.Controls.Add($textPageHeight)

    $buttonSendToBack = New-Object System.Windows.Forms.Button
    $buttonSendToBack.Text = 'Back'
    $buttonSendToBack.Location = New-Object System.Drawing.Point(890, 480)
    $buttonSendToBack.Size = New-Object System.Drawing.Size(46, 46)
    $buttonSendToBack.Anchor = 'Top,Right'
    $form.Controls.Add($buttonSendToBack)

    $buttonStepBack = New-Object System.Windows.Forms.Button
    $buttonStepBack.Text = '-1'
    $buttonStepBack.Location = New-Object System.Drawing.Point(938, 480)
    $buttonStepBack.Size = New-Object System.Drawing.Size(46, 46)
    $buttonStepBack.Anchor = 'Top,Right'
    $form.Controls.Add($buttonStepBack)

    $buttonStepForward = New-Object System.Windows.Forms.Button
    $buttonStepForward.Text = '+1'
    $buttonStepForward.Location = New-Object System.Drawing.Point(986, 480)
    $buttonStepForward.Size = New-Object System.Drawing.Size(46, 46)
    $buttonStepForward.Anchor = 'Top,Right'
    $form.Controls.Add($buttonStepForward)

    $buttonBringToFront = New-Object System.Windows.Forms.Button
    $buttonBringToFront.Text = 'Front'
    $buttonBringToFront.Location = New-Object System.Drawing.Point(1034, 480)
    $buttonBringToFront.Size = New-Object System.Drawing.Size(46, 46)
    $buttonBringToFront.Anchor = 'Top,Right'
    $form.Controls.Add($buttonBringToFront)

    $checkBoxSnap = New-Object System.Windows.Forms.CheckBox
    $checkBoxSnap.Text = 'Snap'
    $checkBoxSnap.Location = New-Object System.Drawing.Point(890, 532)
    $checkBoxSnap.Size = New-Object System.Drawing.Size(190, 24)
    $checkBoxSnap.Anchor = 'Top,Right'
    $checkBoxSnap.Checked = $script:ImageToPdfSnapEnabled
    $form.Controls.Add($checkBoxSnap)

    $labelHelp = New-Object System.Windows.Forms.Label
    $labelHelp.Location = New-Object System.Drawing.Point(890, 564)
    $labelHelp.Size = New-Object System.Drawing.Size(190, 190)
    $labelHelp.Anchor = 'Top,Right'
    $labelHelp.Text = "Click an image to select it.`r`nDrag moves only the active image.`r`nCorner handles resize the image.`r`nThe top handle rotates around the center.`r`nCrop mode uses side and corner handles.`r`nFit to page adapts the active image.`r`nExport uses the same position, size, angle, crop, and page format."
    $form.Controls.Add($labelHelp)

    $cropIcon = New-CropIconBitmap
    $backIcon = New-LayerOrderIconBitmap -Mode 'Back'
    $backOneIcon = New-LayerOrderIconBitmap -Mode 'BackOne'
    $forwardOneIcon = New-LayerOrderIconBitmap -Mode 'ForwardOne'
    $frontIcon = New-LayerOrderIconBitmap -Mode 'Front'
    $addImagesIcon = New-ActionIconBitmap -Mode 'AddImages'
    $fitPageIcon = New-ActionIconBitmap -Mode 'FitPage'
    $centerIcon = New-ActionIconBitmap -Mode 'Center'
    $printIcon = New-ActionIconBitmap -Mode 'Print'
    $exportIcon = New-ActionIconBitmap -Mode 'Export'

    foreach ($iconButton in @($buttonExport, $buttonPrint, $buttonAddImages, $buttonFitToPage, $buttonCenter, $buttonCrop)) {
        Set-ToolbarIconButtonStyle -Button $iconButton
    }
    foreach ($iconButton in @($buttonSendToBack, $buttonStepBack, $buttonStepForward, $buttonBringToFront)) {
        Set-CompactToolbarIconButtonStyle -Button $iconButton
    }
    $buttonExport.Image = $exportIcon
    $buttonPrint.Image = $printIcon
    $buttonAddImages.Image = $addImagesIcon
    $buttonFitToPage.Image = $fitPageIcon
    $buttonCenter.Image = $centerIcon
    $buttonCrop.Image = $cropIcon
    $buttonSendToBack.Image = $backIcon
    $buttonStepBack.Image = $backOneIcon
    $buttonStepForward.Image = $forwardOneIcon
    $buttonBringToFront.Image = $frontIcon

    function Format-CentimeterValue {
        param([Parameter(Mandatory = $true)][double]$Value)

        return $Value.ToString('0.##', [System.Globalization.CultureInfo]::InvariantCulture)
    }

    function Try-ParseCentimeterValue {
        param(
            [Parameter(Mandatory = $true)][string]$Text,
            [ref]$Value
        )

        $normalizedText = if ($null -eq $Text) { '' } else { $Text.Trim().Replace(',', '.') }
        if ([string]::IsNullOrWhiteSpace($normalizedText)) {
            return $false
        }

        $parsedValue = 0.0
        if (-not [double]::TryParse($normalizedText, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsedValue)) {
            return $false
        }

        if ($parsedValue -le 0.0) {
            return $false
        }

        $Value.Value = $parsedValue
        return $true
    }

    function Get-CurrentPageWidthMillimeters {
        if ($script:ImageToPdfPageFormat -ne 'CUSTOM') {
            return 0.0
        }

        return [double]$script:ImageToPdfPageWidthCm * 10.0
    }

    function Get-CurrentPageHeightMillimeters {
        if ($script:ImageToPdfPageFormat -ne 'CUSTOM') {
            return 0.0
        }

        return [double]$script:ImageToPdfPageHeightCm * 10.0
    }

    function Update-PageSizeControls {
        $textPageWidth.Text = Format-CentimeterValue -Value $script:ImageToPdfPageWidthCm
        $textPageHeight.Text = Format-CentimeterValue -Value $script:ImageToPdfPageHeightCm

        $isCustom = ($script:ImageToPdfPageFormat -eq 'CUSTOM')
        $textPageWidth.Enabled = $isCustom
        $textPageHeight.Enabled = $isCustom
    }

    function Set-PagePreset {
        param([Parameter(Mandatory = $true)][string]$Format)

        switch ($Format.ToUpperInvariant()) {
            'A3' {
                $script:ImageToPdfPageFormat = 'A3'
                $script:ImageToPdfPageWidthCm = 29.7
                $script:ImageToPdfPageHeightCm = 42.0
            }
            'CUSTOM' {
                $script:ImageToPdfPageFormat = 'CUSTOM'
                if ($script:ImageToPdfPageWidthCm -le 0.0) {
                    $script:ImageToPdfPageWidthCm = 21.0
                }
                if ($script:ImageToPdfPageHeightCm -le 0.0) {
                    $script:ImageToPdfPageHeightCm = 29.7
                }
            }
            default {
                $script:ImageToPdfPageFormat = 'A4'
                $script:ImageToPdfPageWidthCm = 21.0
                $script:ImageToPdfPageHeightCm = 29.7
            }
        }

        Update-PageSizeControls
    }

    function Try-ApplyCustomPageSizeFromInputs {
        if ($script:ImageToPdfPageFormat -ne 'CUSTOM') {
            return
        }

        $widthCm = 0.0
        $heightCm = 0.0
        if (-not (Try-ParseCentimeterValue -Text $textPageWidth.Text -Value ([ref]$widthCm))) {
            return
        }
        if (-not (Try-ParseCentimeterValue -Text $textPageHeight.Text -Value ([ref]$heightCm))) {
            return
        }

        $script:ImageToPdfPageWidthCm = $widthCm
        $script:ImageToPdfPageHeightCm = $heightCm
        $script:ImageToPdfSnapGuideX = $null
        $script:ImageToPdfSnapGuideY = $null
        $previewPanel.Invalidate()
    }

    Update-PageSizeControls

    function Update-ActiveImageLabel {
        if ($script:ActiveImageIndex -lt 0 -or $script:ActiveImageIndex -ge $script:ImageToPdfItems.Count) {
            $labelActive.Text = 'Active image: none'
            return
        }

        $cropSuffix = ''
        if ($script:ImageToPdfCropMode) {
            $cropSuffix = ' (Crop mode)'
        }
        $labelActive.Text = ('Active image: {0}/{1}{2}' -f ($script:ActiveImageIndex + 1), $script:ImageToPdfItems.Count, $cropSuffix)
    }

    function Show-AddImagesSummary {
        param(
            [Parameter(Mandatory = $true)][int]$AddedCount,
            [Parameter(Mandatory = $true)][int]$DuplicateCount,
            [Parameter(Mandatory = $true)][int]$InvalidCount,
            [Parameter(Mandatory = $true)][bool]$LimitReached
        )

        $messages = New-Object System.Collections.Generic.List[string]
        if ($DuplicateCount -gt 0) {
            $messages.Add(('{0} duplicate image(s) ignored.' -f $DuplicateCount))
        }
        if ($InvalidCount -gt 0) {
            $messages.Add(('{0} invalid or unsupported file(s) ignored.' -f $InvalidCount))
        }
        if ($LimitReached) {
            $messages.Add(('This version supports up to {0} images per PDF page.' -f $script:ImageToPdfMaxImages))
        }

        if ($messages.Count -gt 0) {
            [System.Windows.Forms.MessageBox]::Show(
                ($messages -join "`r`n"),
                'FFActions - Image to PDF',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        }
    }

    function Show-PrintDialogForCurrentLayout {
        if ($script:ImageToPdfItems.Count -le 0) {
            return
        }

        $printDocument = $null
        $printDialog = $null
        $originalAcceptButton = $form.AcceptButton
        $originalCancelButton = $form.CancelButton

        try {
            # Prevent Enter/Escape from triggering Export/Cancel on the main form
            # when the Windows print dialog closes and returns focus.
            $form.AcceptButton = $null
            $form.CancelButton = $null

            if ([System.Drawing.Printing.PrinterSettings]::InstalledPrinters.Count -le 0) {
                [System.Windows.Forms.MessageBox]::Show(
                    'No printer is installed on this computer.',
                    'FFActions - Image to PDF',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                ) | Out-Null
                return
            }

            $printDocument = New-Object System.Drawing.Printing.PrintDocument
            $printDocument.DocumentName = 'FFActions Image to PDF'
            $pageLayout = Get-PdfPageLayout -PageFormat $script:ImageToPdfPageFormat -PageWidthMillimeters (Get-CurrentPageWidthMillimeters) -PageHeightMillimeters (Get-CurrentPageHeightMillimeters)
            $paperWidth = [int][Math]::Round(([double]$pageLayout.WidthPoints / 72.0) * 100.0)
            $paperHeight = [int][Math]::Round(([double]$pageLayout.HeightPoints / 72.0) * 100.0)
            if ($paperWidth -gt 0 -and $paperHeight -gt 0) {
                $printDocument.DefaultPageSettings.PaperSize = New-Object System.Drawing.Printing.PaperSize('FFActions page', $paperWidth, $paperHeight)
            }
            $printDocument.DefaultPageSettings.Margins = New-Object System.Drawing.Printing.Margins(0, 0, 0, 0)
            $printDocument.OriginAtMargins = $false

            $printDocument.Add_PrintPage({
                param($sender, $e)

                $graphics = $e.Graphics
                $graphics.PageUnit = [System.Drawing.GraphicsUnit]::Display
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

                $pageBounds = $e.PageBounds
                $pageScaleX = [double]$pageBounds.Width / [double]$pageLayout.WidthPoints
                $pageScaleY = [double]$pageBounds.Height / [double]$pageLayout.HeightPoints
                $pageScale = [Math]::Min($pageScaleX, $pageScaleY)
                $drawWidth = [double]$pageLayout.WidthPoints * $pageScale
                $drawHeight = [double]$pageLayout.HeightPoints * $pageScale
                $printPageRect = [PSCustomObject]@{
                    X      = [double]$pageBounds.X + (([double]$pageBounds.Width - $drawWidth) / 2.0)
                    Y      = [double]$pageBounds.Y + (([double]$pageBounds.Height - $drawHeight) / 2.0)
                    Width  = $drawWidth
                    Height = $drawHeight
                    Scale  = $pageScale
                }

                $pageBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
                try {
                    $graphics.FillRectangle($pageBrush, [float]$printPageRect.X, [float]$printPageRect.Y, [float]$printPageRect.Width, [float]$printPageRect.Height)
                }
                finally {
                    $pageBrush.Dispose()
                }

                foreach ($item in $script:ImageToPdfItems) {
                    Draw-PreviewImageItem `
                        -Graphics $graphics `
                        -Bitmap $item.Bitmap `
                        -PdfRect $item.PdfRect `
                        -PreviewPageRect $printPageRect `
                        -RotationAngle (Get-ImageItemRotationAngle -Item $item) `
                        -Crop (Get-ImageItemCrop -Item $item)
                }

                $e.HasMorePages = $false
            })

            $printDialog = New-Object System.Windows.Forms.PrintDialog
            $printDialog.UseEXDialog = $false
            $printDialog.AllowPrintToFile = $false
            $printDialog.Document = $printDocument

            if ($printDialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK) {
                return
            }

            $selectedPrinterName = $printDocument.PrinterSettings.PrinterName
            if ([string]::IsNullOrWhiteSpace($selectedPrinterName)) {
                throw 'No printer was selected.'
            }

            $printDocument.Print()
        }
        catch {
            $message = $_.Exception.Message
            if ([string]::IsNullOrWhiteSpace($message)) {
                $message = 'Unable to print the current document.'
            }

            [System.Windows.Forms.MessageBox]::Show(
                $message,
                'FFActions - Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
        finally {
            $form.AcceptButton = $originalAcceptButton
            $form.CancelButton = $originalCancelButton

            if ($null -ne $printDialog) {
                $printDialog.Dispose()
            }
            if ($null -ne $printDocument) {
                $printDocument.Dispose()
            }
        }
    }

    function Add-ImagesToPreview {
        param(
            [Parameter(Mandatory = $true)][string[]]$FilePaths
        )

        $addedCount = 0
        $duplicateCount = 0
        $invalidCount = 0
        $limitReached = $false
        $supportedExtensions = @('.png', '.jpg', '.jpeg', '.bmp')

        foreach ($selectedPath in $FilePaths) {
            if ($script:ImageToPdfItems.Count -ge $script:ImageToPdfMaxImages) {
                $limitReached = $true
                break
            }

            if ([string]::IsNullOrWhiteSpace($selectedPath)) {
                $invalidCount++
                continue
            }

            if (-not (Test-Path -LiteralPath $selectedPath)) {
                $invalidCount++
                continue
            }

            $alreadyExists = $false
            foreach ($existingItem in $script:ImageToPdfItems) {
                if ([string]::Equals($existingItem.SourcePath, $selectedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $alreadyExists = $true
                    break
                }
            }

            if ($alreadyExists) {
                $duplicateCount++
                continue
            }

            $extension = [System.IO.Path]::GetExtension($selectedPath).ToLowerInvariant()
            if ($extension -notin $supportedExtensions) {
                $invalidCount++
                continue
            }

            $bitmap = $null
            try {
                $bitmap = New-NormalizedImageBitmap -InputFile $selectedPath
                if ($null -eq $bitmap) {
                    $invalidCount++
                    continue
                }

                $initialRect = New-AddedPdfImageRect -Bitmap $bitmap -ExistingImageCount $script:ImageToPdfItems.Count -PageFormat $script:ImageToPdfPageFormat -PageWidthMillimeters (Get-CurrentPageWidthMillimeters) -PageHeightMillimeters (Get-CurrentPageHeightMillimeters)
                $newItem = [PSCustomObject]@{
                    SourcePath     = $selectedPath
                    Bitmap         = $bitmap
                    PdfRect        = Copy-PdfRect -Rect $initialRect
                    InitialPdfRect = Copy-PdfRect -Rect $initialRect
                    RotationAngle  = 0.0
                    Crop           = New-DefaultImageCrop
                }

                $script:ImageToPdfItems.Add($newItem)
                $script:ActiveImageIndex = $script:ImageToPdfItems.Count - 1
                $bitmap = $null
                $addedCount++
            }
            finally {
                if ($null -ne $bitmap) {
                    $bitmap.Dispose()
                }
            }
        }

        Update-ActiveImageLabel
        $previewPanel.Invalidate()
        Show-AddImagesSummary -AddedCount $addedCount -DuplicateCount $duplicateCount -InvalidCount $invalidCount -LimitReached $limitReached
    }

    Update-ActiveImageLabel

    $previewPanel.Add_Paint({
        param($sender, $e)

        $graphics = $e.Graphics
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.Clear($previewPanel.BackColor)

        $pageRect = Get-PreviewPageRect -CanvasWidth $previewPanel.ClientSize.Width -CanvasHeight $previewPanel.ClientSize.Height -PageFormat $script:ImageToPdfPageFormat -PageWidthMillimeters (Get-CurrentPageWidthMillimeters) -PageHeightMillimeters (Get-CurrentPageHeightMillimeters)

        $shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(30, 0, 0, 0))
        $pageBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $pageBorderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(190, 190, 190), 1)
        $activeBorderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(52, 120, 246), 2)
        $snapGuidePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120, 52, 120, 246), 1)
        $snapGuidePen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
        $handleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        try {
            $graphics.FillRectangle($shadowBrush, [float]($pageRect.X + 6), [float]($pageRect.Y + 6), [float]$pageRect.Width, [float]$pageRect.Height)
            $graphics.FillRectangle($pageBrush, [float]$pageRect.X, [float]$pageRect.Y, [float]$pageRect.Width, [float]$pageRect.Height)
            $graphics.DrawRectangle($pageBorderPen, [float]$pageRect.X, [float]$pageRect.Y, [float]$pageRect.Width, [float]$pageRect.Height)

            for ($index = 0; $index -lt $script:ImageToPdfItems.Count; $index++) {
                $item = $script:ImageToPdfItems[$index]
                $rotationAngle = Get-ImageItemRotationAngle -Item $item
                $crop = Get-ImageItemCrop -Item $item
                if ($index -eq $script:ActiveImageIndex -and $script:ImageToPdfCropMode) {
                    $fullPdfRect = Get-FullImagePdfRectFromVisibleRectAndCrop -VisiblePdfRect $item.PdfRect -Crop $crop
                    Draw-PreviewImageItem -Graphics $graphics -Bitmap $item.Bitmap -PdfRect $fullPdfRect -PreviewPageRect $pageRect -RotationAngle $rotationAngle -Crop (New-DefaultImageCrop) -Alpha 0.25
                    Draw-PreviewImageItem -Graphics $graphics -Bitmap $item.Bitmap -PdfRect $item.PdfRect -PreviewPageRect $pageRect -RotationAngle $rotationAngle -Crop $crop -Alpha 1.0
                }
                else {
                    Draw-PreviewImageItem -Graphics $graphics -Bitmap $item.Bitmap -PdfRect $item.PdfRect -PreviewPageRect $pageRect -RotationAngle $rotationAngle -Crop $crop
                }
            }

            if ($script:ActiveImageIndex -ge 0 -and $script:ActiveImageIndex -lt $script:ImageToPdfItems.Count) {
                $activeItem = $script:ImageToPdfItems[$script:ActiveImageIndex]
                $rotationAngle = Get-ImageItemRotationAngle -Item $activeItem
                $crop = Get-ImageItemCrop -Item $activeItem
                if ($script:ImageToPdfCropMode) {
                    $fullPdfRect = Get-FullImagePdfRectFromVisibleRectAndCrop -VisiblePdfRect $activeItem.PdfRect -Crop $crop
                    $fullBorderPoints = Get-RotatedPreviewPointsForPdfRect -PdfRect $fullPdfRect -RotationAngle $rotationAngle -PreviewPageRect $pageRect
                    $graphics.DrawPolygon($pageBorderPen, $fullBorderPoints)
                    $borderPoints = Get-RotatedPreviewPointsForPdfRect -PdfRect $activeItem.PdfRect -RotationAngle $rotationAngle -PreviewPageRect $pageRect
                    $graphics.DrawPolygon($activeBorderPen, $borderPoints)
                    $cropHandleRects = Get-PreviewCropHandleRects `
                        -FullPdfRect $fullPdfRect `
                        -Crop $crop `
                        -RotationAngle $rotationAngle `
                        -PreviewPageRect $pageRect `
                        -HandleSize $script:ImageToPdfCropHandleSize
                    foreach ($handleName in @('TopLeft', 'Top', 'TopRight', 'Right', 'BottomRight', 'Bottom', 'BottomLeft', 'Left')) {
                        $handleRect = $cropHandleRects.$handleName
                        Draw-CropPreviewHandle `
                            -Graphics $graphics `
                            -HandleRect $handleRect `
                            -HandleName $handleName `
                            -FillBrush $handleBrush `
                            -BorderPen $activeBorderPen
                    }
                }
                else {
                    $borderPoints = Get-RotatedPreviewPointsForPdfRect -PdfRect $activeItem.PdfRect -RotationAngle $rotationAngle -PreviewPageRect $pageRect
                    $graphics.DrawPolygon($activeBorderPen, $borderPoints)
                    $handleRects = Get-PreviewResizeHandleRects -PdfRect $activeItem.PdfRect -RotationAngle $rotationAngle -PreviewPageRect $pageRect -HandleSize $script:ImageToPdfResizeHandleSize
                    foreach ($handleName in @('TopLeft', 'Top', 'TopRight', 'Right', 'BottomRight', 'Bottom', 'BottomLeft', 'Left')) {
                        $handleRect = $handleRects.$handleName
                        $graphics.FillRectangle($handleBrush, $handleRect.X, $handleRect.Y, $handleRect.Width, $handleRect.Height)
                        $graphics.DrawRectangle($activeBorderPen, $handleRect.X, $handleRect.Y, $handleRect.Width, $handleRect.Height)
                    }
                    $rotationHandle = Get-PreviewRotationHandleInfo `
                        -PdfRect $activeItem.PdfRect `
                        -RotationAngle $rotationAngle `
                        -PreviewPageRect $pageRect `
                        -HandleDiameterPreview $script:ImageToPdfRotationHandleDiameter
                    $graphics.DrawLine($activeBorderPen, $rotationHandle.AxisStart, $rotationHandle.HandleCenter)
                    $graphics.FillEllipse($handleBrush, $rotationHandle.HandleBounds)
                    $graphics.DrawEllipse($activeBorderPen, $rotationHandle.HandleBounds)
                }
            }

            if ($null -ne $script:ImageToPdfSnapGuideX) {
                $guidePreviewX = [float]($pageRect.X + ([double]$script:ImageToPdfSnapGuideX * [double]$pageRect.Scale))
                $graphics.DrawLine($snapGuidePen, $guidePreviewX, [float]$pageRect.Y, $guidePreviewX, [float]($pageRect.Y + $pageRect.Height))
            }

            if ($null -ne $script:ImageToPdfSnapGuideY) {
                $guidePreviewY = [float]($pageRect.Y + ([double]$script:ImageToPdfSnapGuideY * [double]$pageRect.Scale))
                $graphics.DrawLine($snapGuidePen, [float]$pageRect.X, $guidePreviewY, [float]($pageRect.X + $pageRect.Width), $guidePreviewY)
            }
        }
        finally {
            $shadowBrush.Dispose()
            $pageBrush.Dispose()
            $pageBorderPen.Dispose()
            $activeBorderPen.Dispose()
            $snapGuidePen.Dispose()
            $handleBrush.Dispose()
        }
    })

    $previewPanel.Add_MouseDown({
        param($sender, $e)

        if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) {
            return
        }

        $pageRect = Get-PreviewPageRect -CanvasWidth $previewPanel.ClientSize.Width -CanvasHeight $previewPanel.ClientSize.Height -PageFormat $script:ImageToPdfPageFormat -PageWidthMillimeters (Get-CurrentPageWidthMillimeters) -PageHeightMillimeters (Get-CurrentPageHeightMillimeters)
        $script:ImageToPdfInteractionMode = 'None'
        $script:ImageToPdfResizeHandle = $null
        $script:ImageToPdfCropHandle = $null
        $script:ImageToPdfSnapGuideX = $null
        $script:ImageToPdfSnapGuideY = $null

        if ($script:ImageToPdfCropMode) {
            if ($script:ActiveImageIndex -lt 0 -or $script:ActiveImageIndex -ge $script:ImageToPdfItems.Count) {
                $script:ImageToPdfCropMode = $false
                $script:ImageToPdfCropFullRectStart = $null
                Update-ActiveImageLabel
                $previewPanel.Invalidate()
                return
            }

            $activeItem = $script:ImageToPdfItems[$script:ActiveImageIndex]
            $rotationAngle = Get-ImageItemRotationAngle -Item $activeItem
            $crop = Get-ImageItemCrop -Item $activeItem
            $fullPdfRect = Get-FullImagePdfRectFromVisibleRectAndCrop -VisiblePdfRect $activeItem.PdfRect -Crop $crop
            $cropHandle = Get-PreviewCropHandleHit `
                -FullPdfRect $fullPdfRect `
                -Crop $crop `
                -RotationAngle $rotationAngle `
                -PreviewPageRect $pageRect `
                -PreviewX $e.X `
                -PreviewY $e.Y `
                -HandleSize $script:ImageToPdfCropHandleSize

            if ($null -ne $cropHandle) {
                $script:ImageToPdfPointerStart = New-Object System.Drawing.Point($e.X, $e.Y)
                $script:ImageToPdfRectStart = Copy-PdfRect -Rect $activeItem.PdfRect
                $script:ImageToPdfCropStart = Get-NormalizedImageCrop -Crop $crop
                $script:ImageToPdfCropFullRectStart = Copy-PdfRect -Rect $fullPdfRect
                $script:ImageToPdfCropHandle = $cropHandle
                $script:ImageToPdfInteractionMode = 'Crop'
                if ($cropHandle -in @('Left', 'Right')) {
                    $previewPanel.Cursor = [System.Windows.Forms.Cursors]::SizeWE
                }
                elseif ($cropHandle -in @('Top', 'Bottom')) {
                    $previewPanel.Cursor = [System.Windows.Forms.Cursors]::SizeNS
                }
                elseif ($cropHandle -in @('TopLeft', 'BottomRight')) {
                    $previewPanel.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
                }
                else {
                    $previewPanel.Cursor = [System.Windows.Forms.Cursors]::SizeNESW
                }
                Update-ActiveImageLabel
                $previewPanel.Invalidate()
                return
            }

            if (-not (Test-PreviewPointInRotatedPdfRect `
                -PdfRect $fullPdfRect `
                -RotationAngle $rotationAngle `
                -PreviewPageRect $pageRect `
                -PreviewX $e.X `
                -PreviewY $e.Y)) {
                $script:ImageToPdfCropMode = $false
                $script:ImageToPdfCropFullRectStart = $null
                Update-ActiveImageLabel
                $previewPanel.Invalidate()
            }

            return
        }

        if ($script:ActiveImageIndex -ge 0 -and $script:ActiveImageIndex -lt $script:ImageToPdfItems.Count) {
            $activeItem = $script:ImageToPdfItems[$script:ActiveImageIndex]
            $rotationAngle = Get-ImageItemRotationAngle -Item $activeItem

            if (Test-PreviewRotationHandleHit `
                -PdfRect $activeItem.PdfRect `
                -RotationAngle $rotationAngle `
                -PreviewPageRect $pageRect `
                -PreviewX $e.X `
                -PreviewY $e.Y) {
                $script:ImageToPdfPointerStart = New-Object System.Drawing.Point($e.X, $e.Y)
                $script:ImageToPdfRectStart = Copy-PdfRect -Rect $activeItem.PdfRect
                $script:ImageToPdfInteractionMode = 'Rotate'
                $previewPanel.Cursor = [System.Windows.Forms.Cursors]::Hand
                Update-ActiveImageLabel
                $previewPanel.Invalidate()
                return
            }

            $activeHandleHit = Get-PreviewResizeHandleHit `
                -PdfRect $activeItem.PdfRect `
                -RotationAngle $rotationAngle `
                -PreviewPageRect $pageRect `
                -PreviewX $e.X `
                -PreviewY $e.Y `
                -HandleSize $script:ImageToPdfResizeHandleSize
            if ($null -ne $activeHandleHit) {
                $script:ImageToPdfPointerStart = New-Object System.Drawing.Point($e.X, $e.Y)
                $script:ImageToPdfRectStart = Copy-PdfRect -Rect $activeItem.PdfRect
                $script:ImageToPdfResizeHandle = $activeHandleHit
                $script:ImageToPdfInteractionMode = 'Resize'
                if ($script:ImageToPdfResizeHandle -in @('TopLeft', 'BottomRight')) {
                    $previewPanel.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
                }
                elseif ($script:ImageToPdfResizeHandle -in @('Top', 'Bottom')) {
                    $previewPanel.Cursor = [System.Windows.Forms.Cursors]::SizeNS
                }
                elseif ($script:ImageToPdfResizeHandle -in @('Left', 'Right')) {
                    $previewPanel.Cursor = [System.Windows.Forms.Cursors]::SizeWE
                }
                else {
                    $previewPanel.Cursor = [System.Windows.Forms.Cursors]::SizeNESW
                }
                Update-ActiveImageLabel
                $previewPanel.Invalidate()
                return
            }
        }

        $hitIndex = Get-TopmostImageIndexAtPreviewPoint `
            -ImageItems $script:ImageToPdfItems.ToArray() `
            -PreviewPageRect $pageRect `
            -PreviewX $e.X `
            -PreviewY $e.Y

        if ($hitIndex -lt 0) {
            return
        }

        $script:ActiveImageIndex = $hitIndex
        $activeItem = $script:ImageToPdfItems[$script:ActiveImageIndex]
        $script:ImageToPdfPointerStart = New-Object System.Drawing.Point($e.X, $e.Y)
        $script:ImageToPdfRectStart = Copy-PdfRect -Rect $activeItem.PdfRect
        $script:ImageToPdfInteractionMode = 'Drag'
        $previewPanel.Cursor = [System.Windows.Forms.Cursors]::SizeAll
        Update-ActiveImageLabel
        $previewPanel.Invalidate()
    })

    $previewPanel.Add_MouseMove({
        param($sender, $e)

        $pageRect = Get-PreviewPageRect -CanvasWidth $previewPanel.ClientSize.Width -CanvasHeight $previewPanel.ClientSize.Height -PageFormat $script:ImageToPdfPageFormat -PageWidthMillimeters (Get-CurrentPageWidthMillimeters) -PageHeightMillimeters (Get-CurrentPageHeightMillimeters)
        $hitIndex = Get-TopmostImageIndexAtPreviewPoint `
            -ImageItems $script:ImageToPdfItems.ToArray() `
            -PreviewPageRect $pageRect `
            -PreviewX $e.X `
            -PreviewY $e.Y

        if ($script:ImageToPdfInteractionMode -eq 'None') {
            $script:ImageToPdfSnapGuideX = $null
            $script:ImageToPdfSnapGuideY = $null
            if ($script:ActiveImageIndex -ge 0 -and $script:ActiveImageIndex -lt $script:ImageToPdfItems.Count) {
                $activeItem = $script:ImageToPdfItems[$script:ActiveImageIndex]
                $rotationAngle = Get-ImageItemRotationAngle -Item $activeItem
                $crop = Get-ImageItemCrop -Item $activeItem

                if ($script:ImageToPdfCropMode) {
                    $fullPdfRect = Get-FullImagePdfRectFromVisibleRectAndCrop -VisiblePdfRect $activeItem.PdfRect -Crop $crop
                    $cropHandle = Get-PreviewCropHandleHit `
                        -FullPdfRect $fullPdfRect `
                        -Crop $crop `
                        -RotationAngle $rotationAngle `
                        -PreviewPageRect $pageRect `
                        -PreviewX $e.X `
                        -PreviewY $e.Y `
                        -HandleSize $script:ImageToPdfCropHandleSize
                    if ($null -ne $cropHandle) {
                        if ($cropHandle -in @('Left', 'Right')) {
                            $previewPanel.Cursor = [System.Windows.Forms.Cursors]::SizeWE
                        }
                        elseif ($cropHandle -in @('Top', 'Bottom')) {
                            $previewPanel.Cursor = [System.Windows.Forms.Cursors]::SizeNS
                        }
                        elseif ($cropHandle -in @('TopLeft', 'BottomRight')) {
                            $previewPanel.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
                        }
                        else {
                            $previewPanel.Cursor = [System.Windows.Forms.Cursors]::SizeNESW
                        }
                    }
                    else {
                        $previewPanel.Cursor = [System.Windows.Forms.Cursors]::Default
                    }
                    return
                }

                if (Test-PreviewRotationHandleHit `
                    -PdfRect $activeItem.PdfRect `
                    -RotationAngle $rotationAngle `
                    -PreviewPageRect $pageRect `
                    -PreviewX $e.X `
                    -PreviewY $e.Y) {
                    $previewPanel.Cursor = [System.Windows.Forms.Cursors]::Hand
                    return
                }

                $activeHandle = Get-PreviewResizeHandleHit `
                    -PdfRect $activeItem.PdfRect `
                    -RotationAngle $rotationAngle `
                    -PreviewPageRect $pageRect `
                    -PreviewX $e.X `
                    -PreviewY $e.Y `
                    -HandleSize $script:ImageToPdfResizeHandleSize
                if ($null -ne $activeHandle) {
                    if ($activeHandle -in @('TopLeft', 'BottomRight')) {
                        $previewPanel.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
                    }
                    elseif ($activeHandle -in @('Top', 'Bottom')) {
                        $previewPanel.Cursor = [System.Windows.Forms.Cursors]::SizeNS
                    }
                    elseif ($activeHandle -in @('Left', 'Right')) {
                        $previewPanel.Cursor = [System.Windows.Forms.Cursors]::SizeWE
                    }
                    else {
                        $previewPanel.Cursor = [System.Windows.Forms.Cursors]::SizeNESW
                    }
                    return
                }
            }

            if ($hitIndex -ge 0) {
                $previewPanel.Cursor = [System.Windows.Forms.Cursors]::SizeAll
            }
            else {
                $previewPanel.Cursor = [System.Windows.Forms.Cursors]::Default
            }
            return
        }

        if ($script:ImageToPdfInteractionMode -eq 'Crop') {
            $cropState = Update-ImageCropFromPreviewHandle `
                -OriginalCrop $script:ImageToPdfCropStart `
                -Handle $script:ImageToPdfCropHandle `
                -FullPdfRect $script:ImageToPdfCropFullRectStart `
                -RotationAngle (Get-ImageItemRotationAngle -Item $script:ImageToPdfItems[$script:ActiveImageIndex]) `
                -CurrentPreviewX $e.X `
                -CurrentPreviewY $e.Y `
                -PreviewPageRect $pageRect
            $script:ImageToPdfItems[$script:ActiveImageIndex].Crop = $cropState.Crop
            $script:ImageToPdfItems[$script:ActiveImageIndex].PdfRect = $cropState.PdfRect
            $script:ImageToPdfSnapGuideX = $null
            $script:ImageToPdfSnapGuideY = $null
        }
        elseif ($script:ImageToPdfInteractionMode -eq 'Rotate') {
            $rotationAngle = Get-RotationAngleFromPreviewPoint `
                -PdfRect $script:ImageToPdfRectStart `
                -PreviewPageRect $pageRect `
                -PreviewX $e.X `
                -PreviewY $e.Y
            if ($script:ImageToPdfSnapEnabled) {
                $rotationAngle = Get-SnappedRotationAngle -Angle $rotationAngle -ToleranceDegrees $script:ImageToPdfRotationSnapToleranceDegrees
            }
            $script:ImageToPdfItems[$script:ActiveImageIndex].RotationAngle = $rotationAngle
            $script:ImageToPdfSnapGuideX = $null
            $script:ImageToPdfSnapGuideY = $null
        }
        elseif ($script:ImageToPdfInteractionMode -eq 'Resize') {
            $resizeRect = Resize-PdfRectFromPreviewHandle `
                -OriginalPdfRect $script:ImageToPdfRectStart `
                -Handle $script:ImageToPdfResizeHandle `
                -RotationAngle (Get-ImageItemRotationAngle -Item $script:ImageToPdfItems[$script:ActiveImageIndex]) `
                -CurrentPreviewX $e.X `
                -CurrentPreviewY $e.Y `
                -PreviewPageRect $pageRect `
                -PageFormat $script:ImageToPdfPageFormat `
                -PageWidthMillimeters (Get-CurrentPageWidthMillimeters) `
                -PageHeightMillimeters (Get-CurrentPageHeightMillimeters) `
                -LockAspectRatio $script:ImageToPdfLockAspectRatio
            if ($script:ImageToPdfSnapEnabled) {
                $snapResult = Apply-SnapToPdfRect `
                    -PdfRect $resizeRect `
                    -AllItems $script:ImageToPdfItems `
                    -ActiveIndex $script:ActiveImageIndex `
                    -PreviewPageRect $pageRect `
                    -TolerancePreview $script:ImageToPdfSnapTolerancePreview `
                    -PageFormat $script:ImageToPdfPageFormat `
                    -PageWidthMillimeters (Get-CurrentPageWidthMillimeters) `
                    -PageHeightMillimeters (Get-CurrentPageHeightMillimeters) `
                    -ResizeMode
                $script:ImageToPdfItems[$script:ActiveImageIndex].PdfRect = $snapResult.Rect
                $script:ImageToPdfSnapGuideX = $snapResult.GuideX
                $script:ImageToPdfSnapGuideY = $snapResult.GuideY
            }
            else {
                $script:ImageToPdfItems[$script:ActiveImageIndex].PdfRect = $resizeRect
                $script:ImageToPdfSnapGuideX = $null
                $script:ImageToPdfSnapGuideY = $null
            }
        }
        else {
            $deltaX = $e.X - $script:ImageToPdfPointerStart.X
            $deltaY = $e.Y - $script:ImageToPdfPointerStart.Y
            $movedRect = Move-PdfRectByPreviewDelta `
                -PdfRect $script:ImageToPdfRectStart `
                -DeltaPixelsX $deltaX `
                -DeltaPixelsY $deltaY `
                -PreviewPageRect $pageRect `
                -PageFormat $script:ImageToPdfPageFormat `
                -PageWidthMillimeters (Get-CurrentPageWidthMillimeters) `
                -PageHeightMillimeters (Get-CurrentPageHeightMillimeters)
            if ($script:ImageToPdfSnapEnabled) {
                $snapResult = Apply-SnapToPdfRect `
                    -PdfRect $movedRect `
                    -AllItems $script:ImageToPdfItems `
                    -ActiveIndex $script:ActiveImageIndex `
                    -PreviewPageRect $pageRect `
                    -TolerancePreview $script:ImageToPdfSnapTolerancePreview `
                    -PageFormat $script:ImageToPdfPageFormat `
                    -PageWidthMillimeters (Get-CurrentPageWidthMillimeters) `
                    -PageHeightMillimeters (Get-CurrentPageHeightMillimeters)
                $script:ImageToPdfItems[$script:ActiveImageIndex].PdfRect = $snapResult.Rect
                $script:ImageToPdfSnapGuideX = $snapResult.GuideX
                $script:ImageToPdfSnapGuideY = $snapResult.GuideY
            }
            else {
                $script:ImageToPdfItems[$script:ActiveImageIndex].PdfRect = $movedRect
                $script:ImageToPdfSnapGuideX = $null
                $script:ImageToPdfSnapGuideY = $null
            }
        }

        $previewPanel.Invalidate()
    })

    $previewPanel.Add_MouseUp({
        $script:ImageToPdfInteractionMode = 'None'
        $script:ImageToPdfResizeHandle = $null
        $script:ImageToPdfCropHandle = $null
        $script:ImageToPdfCropFullRectStart = $null
        $script:ImageToPdfSnapGuideX = $null
        $script:ImageToPdfSnapGuideY = $null
        $previewPanel.Cursor = [System.Windows.Forms.Cursors]::Default
    })

    $previewPanel.Add_MouseLeave({
        if ($script:ImageToPdfInteractionMode -eq 'None') {
            $previewPanel.Cursor = [System.Windows.Forms.Cursors]::Default
        }
    })

    $previewPanel.Add_DragEnter({
        param($sender, $e)

        if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
            $e.Effect = [System.Windows.Forms.DragDropEffects]::Copy
        }
        else {
            $e.Effect = [System.Windows.Forms.DragDropEffects]::None
        }
    })

    $previewPanel.Add_DragDrop({
        param($sender, $e)

        if (-not $e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
            return
        }

        $droppedFiles = $e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
        if ($null -eq $droppedFiles) {
            return
        }

        Add-ImagesToPreview -FilePaths ([string[]]$droppedFiles)
    })

    $buttonAddImages.Add_Click({
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Multiselect = $true
        $dialog.CheckFileExists = $true
        $dialog.Title = 'Add Images'
        $dialog.Filter = 'Supported images (*.png;*.jpg;*.jpeg;*.bmp)|*.png;*.jpg;*.jpeg;*.bmp|PNG (*.png)|*.png|JPEG (*.jpg;*.jpeg)|*.jpg;*.jpeg|Bitmap (*.bmp)|*.bmp'

        if ($script:ImageToPdfItems.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($script:ImageToPdfItems[0].SourcePath)) {
            try {
                $dialog.InitialDirectory = Split-Path -Parent $script:ImageToPdfItems[0].SourcePath
            }
            catch {
            }
        }

        try {
            if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
                return
            }

            Add-ImagesToPreview -FilePaths ([string[]]$dialog.FileNames)
        }
        finally {
            $dialog.Dispose()
        }
    })

    $buttonFitToPage.Add_Click({
        if ($script:ImageToPdfCropMode) {
            return
        }
        $activeBitmap = $script:ImageToPdfItems[$script:ActiveImageIndex].Bitmap
        $newInitialRect = New-InitialPdfImageRect -Bitmap $activeBitmap -PageFormat $script:ImageToPdfPageFormat -PageWidthMillimeters (Get-CurrentPageWidthMillimeters) -PageHeightMillimeters (Get-CurrentPageHeightMillimeters)
        $script:ImageToPdfItems[$script:ActiveImageIndex].InitialPdfRect = Copy-PdfRect -Rect $newInitialRect
        $script:ImageToPdfItems[$script:ActiveImageIndex].PdfRect = Copy-PdfRect -Rect $newInitialRect
        $previewPanel.Invalidate()
    })

    $buttonCenter.Add_Click({
        if ($script:ImageToPdfCropMode) {
            return
        }
        $script:ImageToPdfItems[$script:ActiveImageIndex].PdfRect = Center-PdfImageRectOnPage `
            -ImageRect $script:ImageToPdfItems[$script:ActiveImageIndex].PdfRect `
            -PageFormat $script:ImageToPdfPageFormat `
            -PageWidthMillimeters (Get-CurrentPageWidthMillimeters) `
            -PageHeightMillimeters (Get-CurrentPageHeightMillimeters)
        $previewPanel.Invalidate()
    })

    $radioPageA4.Add_CheckedChanged({
        if (-not $radioPageA4.Checked) {
            return
        }

        Set-PagePreset -Format 'A4'
        $script:ImageToPdfSnapGuideX = $null
        $script:ImageToPdfSnapGuideY = $null
        $previewPanel.Invalidate()
    })

    $radioPageA3.Add_CheckedChanged({
        if (-not $radioPageA3.Checked) {
            return
        }

        Set-PagePreset -Format 'A3'
        $script:ImageToPdfSnapGuideX = $null
        $script:ImageToPdfSnapGuideY = $null
        $previewPanel.Invalidate()
    })

    $radioPageCustom.Add_CheckedChanged({
        if (-not $radioPageCustom.Checked) {
            return
        }

        Set-PagePreset -Format 'CUSTOM'
        $script:ImageToPdfSnapGuideX = $null
        $script:ImageToPdfSnapGuideY = $null
        $previewPanel.Invalidate()
    })

    $buttonCrop.Add_Click({
        if ($script:ActiveImageIndex -lt 0 -or $script:ActiveImageIndex -ge $script:ImageToPdfItems.Count) {
            return
        }

        $script:ImageToPdfCropMode = -not $script:ImageToPdfCropMode
        $script:ImageToPdfInteractionMode = 'None'
        $script:ImageToPdfResizeHandle = $null
        $script:ImageToPdfCropHandle = $null
        $script:ImageToPdfCropFullRectStart = $null
        $script:ImageToPdfSnapGuideX = $null
        $script:ImageToPdfSnapGuideY = $null
        Update-ActiveImageLabel
        $previewPanel.Invalidate()
    })

    $checkBoxSnap.Add_CheckedChanged({
        $script:ImageToPdfSnapEnabled = $checkBoxSnap.Checked
        $script:ImageToPdfSnapGuideX = $null
        $script:ImageToPdfSnapGuideY = $null
        $previewPanel.Invalidate()
    })

    $checkBoxLockAspectRatio.Add_CheckedChanged({
        $script:ImageToPdfLockAspectRatio = $checkBoxLockAspectRatio.Checked
    })

    $textPageWidth.Add_TextChanged({
        Try-ApplyCustomPageSizeFromInputs
    })

    $textPageHeight.Add_TextChanged({
        Try-ApplyCustomPageSizeFromInputs
    })

    $buttonSendToBack.Add_Click({
        if ($script:ImageToPdfCropMode -or $script:ActiveImageIndex -lt 0) {
            return
        }

        $script:ActiveImageIndex = Move-ImageItemToIndex -Items $script:ImageToPdfItems -SourceIndex $script:ActiveImageIndex -TargetIndex 0
        Update-ActiveImageLabel
        $previewPanel.Invalidate()
    })

    $buttonStepBack.Add_Click({
        if ($script:ImageToPdfCropMode -or $script:ActiveImageIndex -le 0) {
            return
        }

        $script:ActiveImageIndex = Swap-ImageItems -Items $script:ImageToPdfItems -FirstIndex $script:ActiveImageIndex -SecondIndex ($script:ActiveImageIndex - 1)
        Update-ActiveImageLabel
        $previewPanel.Invalidate()
    })

    $buttonStepForward.Add_Click({
        if ($script:ImageToPdfCropMode -or $script:ActiveImageIndex -lt 0 -or $script:ActiveImageIndex -ge ($script:ImageToPdfItems.Count - 1)) {
            return
        }

        $script:ActiveImageIndex = Swap-ImageItems -Items $script:ImageToPdfItems -FirstIndex $script:ActiveImageIndex -SecondIndex ($script:ActiveImageIndex + 1)
        Update-ActiveImageLabel
        $previewPanel.Invalidate()
    })

    $buttonBringToFront.Add_Click({
        if ($script:ImageToPdfCropMode -or $script:ActiveImageIndex -lt 0) {
            return
        }

        $script:ActiveImageIndex = Move-ImageItemToIndex -Items $script:ImageToPdfItems -SourceIndex $script:ActiveImageIndex -TargetIndex ($script:ImageToPdfItems.Count - 1)
        Update-ActiveImageLabel
        $previewPanel.Invalidate()
    })

    $buttonPrint.Add_Click({
        Show-PrintDialogForCurrentLayout
    })

    $buttonExport.Add_Click({
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })

    $buttonCancel.Add_Click({
        $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.Close()
    })

    $form.AcceptButton = $buttonExport
    $form.CancelButton = $buttonCancel
    $form.KeyPreview = $true
    $form.Add_Shown({
        $previewPanel.Invalidate()
        $previewPanel.Update()
    })
    $form.Add_SizeChanged({
        if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
            return
        }

        $previewPanel.Invalidate()
        $previewPanel.Update()
    })
    $previewPanel.Add_SizeChanged({
        $previewPanel.Invalidate()
        $previewPanel.Update()
    })
    $form.Add_KeyDown({
        param($sender, $e)

        if (-not $script:ImageToPdfCropMode) {
            return
        }

        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Escape -or $e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            $script:ImageToPdfCropMode = $false
            $script:ImageToPdfInteractionMode = 'None'
            $script:ImageToPdfResizeHandle = $null
            $script:ImageToPdfCropHandle = $null
            $script:ImageToPdfCropFullRectStart = $null
            $script:ImageToPdfSnapGuideX = $null
            $script:ImageToPdfSnapGuideY = $null
            Update-ActiveImageLabel
            $previewPanel.Invalidate()
            $e.SuppressKeyPress = $true
        }
    })

    $result = $form.ShowDialog()
    $finalItems = $null
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $finalItems = $script:ImageToPdfItems
    }

    $form.Dispose()
    if ($null -ne $windowIcon) {
        $windowIcon.Dispose()
    }
    return ,$finalItems
}

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
    if ($sourceExtension -notin @('.png', '.jpg', '.jpeg', '.bmp')) {
        Show-Error 'Unsupported input format. Only .png, .jpg, .jpeg and .bmp are supported.'
        exit 1
    }

    $imageItems = New-Object System.Collections.Generic.List[object]
    try {
        $bitmap = New-NormalizedImageBitmap -InputFile $InputFile
        if ($null -eq $bitmap) {
            Show-Error 'Unable to load the source image.'
            exit 1
        }

        $initialRect = New-InitialPdfImageRect -Bitmap $bitmap -PageFormat 'A4'
        $imageItems.Add([PSCustomObject]@{
            SourcePath     = $InputFile
            Bitmap         = $bitmap
            PdfRect        = Copy-PdfRect -Rect $initialRect
            InitialPdfRect = Copy-PdfRect -Rect $initialRect
            RotationAngle  = 0.0
            Crop           = New-DefaultImageCrop
        })

        $finalItems = Show-ImageToPdfWindow -ImageItems $imageItems -InitialPageFormat 'A4'
        if ($null -eq $finalItems) {
            exit 0
        }

        $inputDir = Split-Path -Parent $InputFile
        if ($finalItems.Count -eq 1) {
            $inputBase = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
            $desiredOutput = Join-Path $inputDir ("{0}_image_to_pdf.pdf" -f $inputBase)
        }
        else {
            $desiredOutput = Join-Path $inputDir 'selected_images_to_pdf.pdf'
        }

        $script:OutputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput
        $exportPageWidthMillimeters = if ($script:ImageToPdfPageFormat -eq 'CUSTOM') { [double]$script:ImageToPdfPageWidthCm * 10.0 } else { 0.0 }
        $exportPageHeightMillimeters = if ($script:ImageToPdfPageFormat -eq 'CUSTOM') { [double]$script:ImageToPdfPageHeightCm * 10.0 } else { 0.0 }
        Save-ImageItemsToPdf -ImageItems $finalItems.ToArray() -OutputFile $script:OutputFile -PageFormat $script:ImageToPdfPageFormat -PageWidthMillimeters $exportPageWidthMillimeters -PageHeightMillimeters $exportPageHeightMillimeters

        foreach ($item in $imageItems) {
            $item.Bitmap = $null
        }

        if (-not (Test-Path -LiteralPath $script:OutputFile)) {
            Remove-PartialOutput -Path $script:OutputFile
            Show-Error 'The PDF file could not be created.'
            exit 1
        }

        exit 0
    }
    finally {
        foreach ($item in $imageItems) {
            if ($null -ne $item.Bitmap) {
                $item.Bitmap.Dispose()
            }
        }
    }
}
catch {
    Remove-PartialOutput -Path $script:OutputFile
    $message = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = 'Unknown image to PDF conversion error.'
    }
    Show-Error $message
    exit 1
}
