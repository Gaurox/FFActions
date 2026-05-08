if (-not (Get-Command -Name 'Get-PdfAppRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-PdfAppRoot {
    $scriptRoot = $script:PSScriptRoot
    if (-not [string]::IsNullOrWhiteSpace($scriptRoot)) {
        return Split-Path -Parent $scriptRoot
    }

    $scriptPath = $script:PSCommandPath
    if ([string]::IsNullOrWhiteSpace($scriptPath) -and $MyInvocation.MyCommand.Path) {
        $scriptPath = $MyInvocation.MyCommand.Path
    }

    if (-not [string]::IsNullOrWhiteSpace($scriptPath)) {
        $scriptDir = Split-Path -Parent $scriptPath
        return Split-Path -Parent $scriptDir
    }

    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $exeDir = Split-Path -Parent $exePath
    return Split-Path -Parent $exeDir
}
}

if (-not (Get-Command -Name 'Get-PdfToolsDirectory' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-PdfToolsDirectory {
    return Join-Path (Get-PdfAppRoot) 'tools\pdf'
}
}

if (-not (Get-Command -Name 'Get-PdfRuntimeAssemblyNames' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-PdfRuntimeAssemblyNames {
    return @(
        'System.Buffers.dll',
        'System.Runtime.CompilerServices.Unsafe.dll',
        'System.Numerics.Vectors.dll',
        'System.Memory.dll',
        'System.Threading.Tasks.Extensions.dll',
        'Microsoft.Bcl.AsyncInterfaces.dll',
        'Microsoft.Extensions.DependencyInjection.Abstractions.dll',
        'Microsoft.Extensions.Logging.Abstractions.dll',
        'System.Security.Cryptography.Pkcs.dll',
        'PdfSharp.System.dll',
        'PdfSharp.Shared.dll',
        'PdfSharp.Cryptography.dll',
        'PdfSharp-gdi.dll'
    )
}
}

if (-not (Get-Command -Name 'Import-PdfRuntime' -CommandType Function -ErrorAction SilentlyContinue)) {
function Import-PdfRuntime {
    if ('PdfSharp.Pdf.PdfDocument' -as [type]) {
        return
    }

    $pdfDir = Get-PdfToolsDirectory
    if (-not (Test-Path -LiteralPath $pdfDir)) {
        throw "PDF runtime folder not found: $pdfDir"
    }

    $missingFiles = New-Object System.Collections.Generic.List[string]
    foreach ($assemblyName in (Get-PdfRuntimeAssemblyNames)) {
        $assemblyPath = Join-Path $pdfDir $assemblyName
        if (-not (Test-Path -LiteralPath $assemblyPath)) {
            $missingFiles.Add($assemblyName)
        }
    }

    if ($missingFiles.Count -gt 0) {
        throw ('Missing PDF runtime file(s): ' + ($missingFiles -join ', '))
    }

    foreach ($assemblyName in (Get-PdfRuntimeAssemblyNames)) {
        $assemblyPath = Join-Path $pdfDir $assemblyName
        Add-Type -Path $assemblyPath
    }

    if (-not ('PdfSharp.Pdf.PdfDocument' -as [type])) {
        throw 'Unable to load the PDF runtime.'
    }
}
}

if (-not (Get-Command -Name 'Get-ImageExifRotateFlipType' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-ImageExifRotateFlipType {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Image]$Image
    )

    $orientationId = 274
    if ($Image.PropertyIdList -notcontains $orientationId) {
        return [System.Drawing.RotateFlipType]::RotateNoneFlipNone
    }

    try {
        $property = $Image.GetPropertyItem($orientationId)
        if ($null -eq $property -or $null -eq $property.Value -or $property.Value.Length -lt 2) {
            return [System.Drawing.RotateFlipType]::RotateNoneFlipNone
        }

        $orientation = [System.BitConverter]::ToUInt16($property.Value, 0)
        switch ($orientation) {
            2 { return [System.Drawing.RotateFlipType]::RotateNoneFlipX }
            3 { return [System.Drawing.RotateFlipType]::Rotate180FlipNone }
            4 { return [System.Drawing.RotateFlipType]::Rotate180FlipX }
            5 { return [System.Drawing.RotateFlipType]::Rotate90FlipX }
            6 { return [System.Drawing.RotateFlipType]::Rotate90FlipNone }
            7 { return [System.Drawing.RotateFlipType]::Rotate270FlipX }
            8 { return [System.Drawing.RotateFlipType]::Rotate270FlipNone }
            default { return [System.Drawing.RotateFlipType]::RotateNoneFlipNone }
        }
    }
    catch {
        return [System.Drawing.RotateFlipType]::RotateNoneFlipNone
    }
}
}

if (-not (Get-Command -Name 'New-NormalizedImageBitmap' -CommandType Function -ErrorAction SilentlyContinue)) {
function New-NormalizedImageBitmap {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile
    )

    $sourceImage = $null

    try {
        $sourceImage = [System.Drawing.Image]::FromFile($InputFile)
        $rotateFlipType = Get-ImageExifRotateFlipType -Image $sourceImage
        if ($rotateFlipType -ne [System.Drawing.RotateFlipType]::RotateNoneFlipNone) {
            $sourceImage.RotateFlip($rotateFlipType)
        }

        $normalizedBitmap = New-Object System.Drawing.Bitmap($sourceImage.Width, $sourceImage.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = $null
        try {
            $normalizedBitmap.SetResolution($sourceImage.HorizontalResolution, $sourceImage.VerticalResolution)
            $graphics = [System.Drawing.Graphics]::FromImage($normalizedBitmap)
            $graphics.DrawImage($sourceImage, 0, 0, $sourceImage.Width, $sourceImage.Height)
            return $normalizedBitmap
        }
        finally {
            if ($null -ne $graphics) {
                $graphics.Dispose()
            }
        }
    }
    finally {
        if ($null -ne $sourceImage) {
            $sourceImage.Dispose()
        }
    }
}
}

if (-not (Get-Command -Name 'Get-PdfPageLayout' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-PdfPageLayout {
    param(
        [string]$PageFormat = 'A4',
        [double]$PageWidthMillimeters = 0.0,
        [double]$PageHeightMillimeters = 0.0
    )

    Import-PdfRuntime

    if ($PageWidthMillimeters -gt 0.0 -and $PageHeightMillimeters -gt 0.0) {
        $normalizedPageFormat = 'CUSTOM'
        $widthMillimeters = $PageWidthMillimeters
        $heightMillimeters = $PageHeightMillimeters
    }
    else {
        $normalizedPageFormat = if ([string]::IsNullOrWhiteSpace($PageFormat)) { 'A4' } else { $PageFormat.ToUpperInvariant() }
        switch ($normalizedPageFormat) {
            'A3' {
                $widthMillimeters = 297.0
                $heightMillimeters = 420.0
            }
            default {
                $widthMillimeters = 210.0
                $heightMillimeters = 297.0
                $normalizedPageFormat = 'A4'
            }
        }
    }

    return [PSCustomObject]@{
        Format            = $normalizedPageFormat
        WidthMillimeters  = $widthMillimeters
        HeightMillimeters = $heightMillimeters
        WidthPoints       = [PdfSharp.Drawing.XUnit]::FromMillimeter($widthMillimeters).Point
        HeightPoints      = [PdfSharp.Drawing.XUnit]::FromMillimeter($heightMillimeters).Point
    }
}
}

if (-not (Get-Command -Name 'Get-PdfImagePlacement' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-PdfImagePlacement {
    param(
        [Parameter(Mandatory = $true)][double]$PageWidthPoints,
        [Parameter(Mandatory = $true)][double]$PageHeightPoints,
        [Parameter(Mandatory = $true)][double]$ImageWidthPixels,
        [Parameter(Mandatory = $true)][double]$ImageHeightPixels
    )

    if ($PageWidthPoints -le 0 -or $PageHeightPoints -le 0) {
        throw 'Invalid PDF page size.'
    }

    if ($ImageWidthPixels -le 0 -or $ImageHeightPixels -le 0) {
        throw 'Invalid image size.'
    }

    $scaleX = $PageWidthPoints / $ImageWidthPixels
    $scaleY = $PageHeightPoints / $ImageHeightPixels
    $scale = [System.Math]::Min($scaleX, $scaleY)

    $drawWidth = $ImageWidthPixels * $scale
    $drawHeight = $ImageHeightPixels * $scale
    $drawX = ($PageWidthPoints - $drawWidth) / 2.0
    $drawY = ($PageHeightPoints - $drawHeight) / 2.0

    return [PSCustomObject]@{
        X      = $drawX
        Y      = $drawY
        Width  = $drawWidth
        Height = $drawHeight
    }
}
}

if (-not (Get-Command -Name 'Get-PdfImagePlacementWithinBounds' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-PdfImagePlacementWithinBounds {
    param(
        [Parameter(Mandatory = $true)][double]$BoundsX,
        [Parameter(Mandatory = $true)][double]$BoundsY,
        [Parameter(Mandatory = $true)][double]$BoundsWidth,
        [Parameter(Mandatory = $true)][double]$BoundsHeight,
        [Parameter(Mandatory = $true)][double]$ImageWidthPixels,
        [Parameter(Mandatory = $true)][double]$ImageHeightPixels
    )

    if ($BoundsWidth -le 0 -or $BoundsHeight -le 0) {
        throw 'Invalid PDF bounds size.'
    }

    $placement = Get-PdfImagePlacement `
        -PageWidthPoints $BoundsWidth `
        -PageHeightPoints $BoundsHeight `
        -ImageWidthPixels $ImageWidthPixels `
        -ImageHeightPixels $ImageHeightPixels

    return [PSCustomObject]@{
        X      = $BoundsX + [double]$placement.X
        Y      = $BoundsY + [double]$placement.Y
        Width  = [double]$placement.Width
        Height = [double]$placement.Height
    }
}
}

if (-not (Get-Command -Name 'New-InitialPdfImageRect' -CommandType Function -ErrorAction SilentlyContinue)) {
function New-InitialPdfImageRect {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap,
        [string]$PageFormat = 'A4',
        [double]$PageWidthMillimeters = 0.0,
        [double]$PageHeightMillimeters = 0.0
    )

    $page = Get-PdfPageLayout -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters
    return Get-PdfImagePlacement `
        -PageWidthPoints $page.WidthPoints `
        -PageHeightPoints $page.HeightPoints `
        -ImageWidthPixels $Bitmap.Width `
        -ImageHeightPixels $Bitmap.Height
}
}

if (-not (Get-Command -Name 'New-InitialPdfImageRectsForTwoBitmaps' -CommandType Function -ErrorAction SilentlyContinue)) {
function New-InitialPdfImageRectsForTwoBitmaps {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$FirstBitmap,
        [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$SecondBitmap,
        [string]$PageFormat = 'A4',
        [double]$PageWidthMillimeters = 0.0,
        [double]$PageHeightMillimeters = 0.0
    )

    $page = Get-PdfPageLayout -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters
    $outerMargin = 18.0
    $gap = 12.0
    $slotWidth = ($page.WidthPoints - ($outerMargin * 2.0) - $gap) / 2.0
    $slotHeight = $page.HeightPoints - ($outerMargin * 2.0)

    if ($slotWidth -le 0 -or $slotHeight -le 0) {
        throw 'Invalid initial layout size for two images.'
    }

    $leftRect = Get-PdfImagePlacementWithinBounds `
        -BoundsX $outerMargin `
        -BoundsY $outerMargin `
        -BoundsWidth $slotWidth `
        -BoundsHeight $slotHeight `
        -ImageWidthPixels $FirstBitmap.Width `
        -ImageHeightPixels $FirstBitmap.Height

    $rightRect = Get-PdfImagePlacementWithinBounds `
        -BoundsX ($outerMargin + $slotWidth + $gap) `
        -BoundsY $outerMargin `
        -BoundsWidth $slotWidth `
        -BoundsHeight $slotHeight `
        -ImageWidthPixels $SecondBitmap.Width `
        -ImageHeightPixels $SecondBitmap.Height

    return @($leftRect, $rightRect)
}
}

if (-not (Get-Command -Name 'New-AddedPdfImageRect' -CommandType Function -ErrorAction SilentlyContinue)) {
function New-AddedPdfImageRect {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap,
        [Parameter(Mandatory = $true)][int]$ExistingImageCount,
        [string]$PageFormat = 'A4',
        [double]$PageWidthMillimeters = 0.0,
        [double]$PageHeightMillimeters = 0.0
    )

    $initialRect = New-InitialPdfImageRect -Bitmap $Bitmap -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters
    if ($ExistingImageCount -le 0) {
        return $initialRect
    }

    $scaleFactor = 0.60
    $scaledRect = [PSCustomObject]@{
        X      = [double]$initialRect.X
        Y      = [double]$initialRect.Y
        Width  = [double]$initialRect.Width
        Height = [double]$initialRect.Height
    }

    $scaledRect = Scale-PdfImageRect -ImageRect $scaledRect -ScaleFactor $scaleFactor -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters
    return Center-PdfImageRectOnPage -ImageRect $scaledRect -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters
}
}

if (-not (Get-Command -Name 'Center-PdfImageRectOnPage' -CommandType Function -ErrorAction SilentlyContinue)) {
function Center-PdfImageRectOnPage {
    param(
        [Parameter(Mandatory = $true)]$ImageRect,
        [string]$PageFormat = 'A4',
        [double]$PageWidthMillimeters = 0.0,
        [double]$PageHeightMillimeters = 0.0
    )

    $page = Get-PdfPageLayout -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters

    $width = [double]$ImageRect.Width
    $height = [double]$ImageRect.Height

    if ($width -le 0 -or $height -le 0) {
        throw 'Invalid image rect size.'
    }

    if ($width -gt $page.WidthPoints) { $width = $page.WidthPoints }
    if ($height -gt $page.HeightPoints) { $height = $page.HeightPoints }

    return [PSCustomObject]@{
        X      = ($page.WidthPoints - $width) / 2.0
        Y      = ($page.HeightPoints - $height) / 2.0
        Width  = $width
        Height = $height
    }
}
}

if (-not (Get-Command -Name 'Scale-PdfImageRect' -CommandType Function -ErrorAction SilentlyContinue)) {
function Scale-PdfImageRect {
    param(
        [Parameter(Mandatory = $true)]$ImageRect,
        [Parameter(Mandatory = $true)][double]$ScaleFactor,
        [string]$PageFormat = 'A4',
        [double]$PageWidthMillimeters = 0.0,
        [double]$PageHeightMillimeters = 0.0
    )

    if ($ScaleFactor -le 0) {
        throw 'Scale factor must be greater than zero.'
    }

    $currentWidth = [double]$ImageRect.Width
    $currentHeight = [double]$ImageRect.Height
    if ($currentWidth -le 0 -or $currentHeight -le 0) {
        throw 'Invalid image rect size.'
    }

    $page = Get-PdfPageLayout -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters
    $centerX = [double]$ImageRect.X + ($currentWidth / 2.0)
    $centerY = [double]$ImageRect.Y + ($currentHeight / 2.0)

    $newWidth = $currentWidth * $ScaleFactor
    $newHeight = $currentHeight * $ScaleFactor

    $minimumSize = 12.0
    if ($newWidth -lt $minimumSize) { $newWidth = $minimumSize }
    if ($newHeight -lt $minimumSize) { $newHeight = $minimumSize }

    $maxScaleX = $page.WidthPoints / $currentWidth
    $maxScaleY = $page.HeightPoints / $currentHeight
    $maxScale = [System.Math]::Min($maxScaleX, $maxScaleY)

    if ($ScaleFactor -gt $maxScale) {
        $newWidth = $currentWidth * $maxScale
        $newHeight = $currentHeight * $maxScale
    }

    $scaledRect = [PSCustomObject]@{
        X      = $centerX - ($newWidth / 2.0)
        Y      = $centerY - ($newHeight / 2.0)
        Width  = $newWidth
        Height = $newHeight
    }

    return Clamp-PdfImageRectToPage -ImageRect $scaledRect -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters
}
}

if (-not (Get-Command -Name 'New-DefaultImageCrop' -CommandType Function -ErrorAction SilentlyContinue)) {
function New-DefaultImageCrop {
    return [PSCustomObject]@{
        Left   = 0.0
        Top    = 0.0
        Right  = 1.0
        Bottom = 1.0
    }
}
}

if (-not (Get-Command -Name 'Get-NormalizedImageCrop' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-NormalizedImageCrop {
    param($Crop)

    if ($null -eq $Crop) {
        return New-DefaultImageCrop
    }

    return [PSCustomObject]@{
        Left   = [Math]::Max(0.0, [Math]::Min(1.0, [double]$Crop.Left))
        Top    = [Math]::Max(0.0, [Math]::Min(1.0, [double]$Crop.Top))
        Right  = [Math]::Max(0.0, [Math]::Min(1.0, [double]$Crop.Right))
        Bottom = [Math]::Max(0.0, [Math]::Min(1.0, [double]$Crop.Bottom))
    }
}
}

if (-not (Get-Command -Name 'Test-IsDefaultImageCrop' -CommandType Function -ErrorAction SilentlyContinue)) {
function Test-IsDefaultImageCrop {
    param($Crop)

    $normalized = Get-NormalizedImageCrop -Crop $Crop
    return (
        [Math]::Abs([double]$normalized.Left - 0.0) -lt 0.0001 -and
        [Math]::Abs([double]$normalized.Top - 0.0) -lt 0.0001 -and
        [Math]::Abs([double]$normalized.Right - 1.0) -lt 0.0001 -and
        [Math]::Abs([double]$normalized.Bottom - 1.0) -lt 0.0001
    )
}
}

if (-not (Get-Command -Name 'Get-PdfCropRectWithinImageRect' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-PdfCropRectWithinImageRect {
    param(
        [Parameter(Mandatory = $true)]$PdfRect,
        [Parameter(Mandatory = $true)]$Crop
    )

    $normalized = Get-NormalizedImageCrop -Crop $Crop
    $left = [double]$PdfRect.X + ([double]$PdfRect.Width * [double]$normalized.Left)
    $top = [double]$PdfRect.Y + ([double]$PdfRect.Height * [double]$normalized.Top)
    $width = [double]$PdfRect.Width * ([double]$normalized.Right - [double]$normalized.Left)
    $height = [double]$PdfRect.Height * ([double]$normalized.Bottom - [double]$normalized.Top)

    return [PSCustomObject]@{
        X      = $left
        Y      = $top
        Width  = $width
        Height = $height
    }
}
}

if (-not (Get-Command -Name 'Get-FullImagePdfRectFromVisibleRectAndCrop' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-FullImagePdfRectFromVisibleRectAndCrop {
    param(
        [Parameter(Mandatory = $true)]$VisiblePdfRect,
        [Parameter(Mandatory = $true)]$Crop
    )

    $normalized = Get-NormalizedImageCrop -Crop $Crop
    $cropWidthRatio = [double]$normalized.Right - [double]$normalized.Left
    $cropHeightRatio = [double]$normalized.Bottom - [double]$normalized.Top

    if ($cropWidthRatio -le 0.0001 -or $cropHeightRatio -le 0.0001) {
        throw 'Invalid crop ratios.'
    }

    $fullWidth = [double]$VisiblePdfRect.Width / $cropWidthRatio
    $fullHeight = [double]$VisiblePdfRect.Height / $cropHeightRatio
    $fullX = [double]$VisiblePdfRect.X - ($fullWidth * [double]$normalized.Left)
    $fullY = [double]$VisiblePdfRect.Y - ($fullHeight * [double]$normalized.Top)

    return [PSCustomObject]@{
        X      = $fullX
        Y      = $fullY
        Width  = $fullWidth
        Height = $fullHeight
    }
}
}

if (-not (Get-Command -Name 'Get-BitmapSourceRectFromCrop' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-BitmapSourceRectFromCrop {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap,
        [Parameter(Mandatory = $true)]$Crop
    )

    $normalized = Get-NormalizedImageCrop -Crop $Crop
    $left = [Math]::Floor($Bitmap.Width * [double]$normalized.Left)
    $top = [Math]::Floor($Bitmap.Height * [double]$normalized.Top)
    $right = [Math]::Ceiling($Bitmap.Width * [double]$normalized.Right)
    $bottom = [Math]::Ceiling($Bitmap.Height * [double]$normalized.Bottom)

    $left = [Math]::Max(0, [Math]::Min($Bitmap.Width - 1, $left))
    $top = [Math]::Max(0, [Math]::Min($Bitmap.Height - 1, $top))
    $right = [Math]::Max($left + 1, [Math]::Min($Bitmap.Width, $right))
    $bottom = [Math]::Max($top + 1, [Math]::Min($Bitmap.Height, $bottom))

    return New-Object System.Drawing.Rectangle($left, $top, ($right - $left), ($bottom - $top))
}
}

if (-not (Get-Command -Name 'New-CroppedBitmap' -CommandType Function -ErrorAction SilentlyContinue)) {
function New-CroppedBitmap {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap,
        [Parameter(Mandatory = $true)]$Crop
    )

    $sourceRect = Get-BitmapSourceRectFromCrop -Bitmap $Bitmap -Crop $Crop
    $croppedBitmap = New-Object System.Drawing.Bitmap($sourceRect.Width, $sourceRect.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = $null

    try {
        $croppedBitmap.SetResolution($Bitmap.HorizontalResolution, $Bitmap.VerticalResolution)
        $graphics = [System.Drawing.Graphics]::FromImage($croppedBitmap)
        $graphics.DrawImage(
            $Bitmap,
            (New-Object System.Drawing.Rectangle(0, 0, $croppedBitmap.Width, $croppedBitmap.Height)),
            $sourceRect,
            [System.Drawing.GraphicsUnit]::Pixel
        )
        return $croppedBitmap
    }
    finally {
        if ($null -ne $graphics) {
            $graphics.Dispose()
        }
    }
}
}

if (-not (Get-Command -Name 'Get-TopmostImageIndexAtPreviewPoint' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-TopmostImageIndexAtPreviewPoint {
    param(
        [Parameter(Mandatory = $true)][object[]]$ImageItems,
        [Parameter(Mandatory = $true)]$PreviewPageRect,
        [Parameter(Mandatory = $true)][double]$PreviewX,
        [Parameter(Mandatory = $true)][double]$PreviewY
    )

    for ($index = $ImageItems.Count - 1; $index -ge 0; $index--) {
        $item = $ImageItems[$index]
        if ($null -eq $item -or $null -eq $item.PdfRect) {
            continue
        }

        $rotationAngle = 0.0
        if ($null -ne $item.PSObject.Properties['RotationAngle']) {
            $rotationAngle = [double]$item.RotationAngle
        }

        if (Test-PreviewPointInRotatedPdfRect `
            -PdfRect $item.PdfRect `
            -RotationAngle $rotationAngle `
            -PreviewPageRect $PreviewPageRect `
            -PreviewX $PreviewX `
            -PreviewY $PreviewY) {
            return $index
        }
    }

    return -1
}
}

if (-not (Get-Command -Name 'Clamp-PdfImageRectToPage' -CommandType Function -ErrorAction SilentlyContinue)) {
function Clamp-PdfImageRectToPage {
    param(
        [Parameter(Mandatory = $true)]$ImageRect,
        [string]$PageFormat = 'A4',
        [double]$PageWidthMillimeters = 0.0,
        [double]$PageHeightMillimeters = 0.0
    )

    $page = Get-PdfPageLayout -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters

    $x = [double]$ImageRect.X
    $y = [double]$ImageRect.Y
    $w = [double]$ImageRect.Width
    $h = [double]$ImageRect.Height

    if ($w -gt $page.WidthPoints) { $w = $page.WidthPoints }
    if ($h -gt $page.HeightPoints) { $h = $page.HeightPoints }

    if ($x -lt 0) { $x = 0 }
    if ($y -lt 0) { $y = 0 }
    if (($x + $w) -gt $page.WidthPoints) { $x = $page.WidthPoints - $w }
    if (($y + $h) -gt $page.HeightPoints) { $y = $page.HeightPoints - $h }

    return [PSCustomObject]@{
        X      = $x
        Y      = $y
        Width  = $w
        Height = $h
    }
}
}

if (-not (Get-Command -Name 'Get-PreviewPageRect' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-PreviewPageRect {
    param(
        [Parameter(Mandatory = $true)][int]$CanvasWidth,
        [Parameter(Mandatory = $true)][int]$CanvasHeight,
        [string]$PageFormat = 'A4',
        [double]$PageWidthMillimeters = 0.0,
        [double]$PageHeightMillimeters = 0.0
    )

    $page = Get-PdfPageLayout -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters
    $padding = 24.0

    $availableWidth = [Math]::Max(1.0, $CanvasWidth - ($padding * 2.0))
    $availableHeight = [Math]::Max(1.0, $CanvasHeight - ($padding * 2.0))

    $scaleX = $availableWidth / $page.WidthPoints
    $scaleY = $availableHeight / $page.HeightPoints
    $scale = [Math]::Min($scaleX, $scaleY)

    $pageWidth = $page.WidthPoints * $scale
    $pageHeight = $page.HeightPoints * $scale
    $pageX = ($CanvasWidth - $pageWidth) / 2.0
    $pageY = ($CanvasHeight - $pageHeight) / 2.0

    return [PSCustomObject]@{
        X      = $pageX
        Y      = $pageY
        Width  = $pageWidth
        Height = $pageHeight
        Scale  = $scale
    }
}
}

if (-not (Get-Command -Name 'Convert-PdfRectToPreviewRect' -CommandType Function -ErrorAction SilentlyContinue)) {
function Convert-PdfRectToPreviewRect {
    param(
        [Parameter(Mandatory = $true)]$PdfRect,
        [Parameter(Mandatory = $true)]$PreviewPageRect
    )

    return New-Object System.Drawing.RectangleF(
        [float]($PreviewPageRect.X + ($PdfRect.X * $PreviewPageRect.Scale)),
        [float]($PreviewPageRect.Y + ($PdfRect.Y * $PreviewPageRect.Scale)),
        [float]($PdfRect.Width * $PreviewPageRect.Scale),
        [float]($PdfRect.Height * $PreviewPageRect.Scale)
    )
}
}

if (-not (Get-Command -Name 'Convert-PreviewPointToPdfPoint' -CommandType Function -ErrorAction SilentlyContinue)) {
function Convert-PreviewPointToPdfPoint {
    param(
        [Parameter(Mandatory = $true)][double]$PreviewX,
        [Parameter(Mandatory = $true)][double]$PreviewY,
        [Parameter(Mandatory = $true)]$PreviewPageRect
    )

    return [PSCustomObject]@{
        X = ($PreviewX - [double]$PreviewPageRect.X) / [double]$PreviewPageRect.Scale
        Y = ($PreviewY - [double]$PreviewPageRect.Y) / [double]$PreviewPageRect.Scale
    }
}
}

if (-not (Get-Command -Name 'Get-RotatedPdfPoint' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-RotatedPdfPoint {
    param(
        [Parameter(Mandatory = $true)][double]$PointX,
        [Parameter(Mandatory = $true)][double]$PointY,
        [Parameter(Mandatory = $true)][double]$CenterX,
        [Parameter(Mandatory = $true)][double]$CenterY,
        [Parameter(Mandatory = $true)][double]$AngleDegrees
    )

    $radians = $AngleDegrees * [Math]::PI / 180.0
    $cos = [Math]::Cos($radians)
    $sin = [Math]::Sin($radians)
    $dx = $PointX - $CenterX
    $dy = $PointY - $CenterY

    return [PSCustomObject]@{
        X = $CenterX + ($dx * $cos) - ($dy * $sin)
        Y = $CenterY + ($dx * $sin) + ($dy * $cos)
    }
}
}

if (-not (Get-Command -Name 'Get-RotatedPreviewPointsForPdfRect' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-RotatedPreviewPointsForPdfRect {
    param(
        [Parameter(Mandatory = $true)]$PdfRect,
        [Parameter(Mandatory = $true)][double]$RotationAngle,
        [Parameter(Mandatory = $true)]$PreviewPageRect
    )

    $left = [double]$PdfRect.X
    $top = [double]$PdfRect.Y
    $right = $left + [double]$PdfRect.Width
    $bottom = $top + [double]$PdfRect.Height
    $centerX = $left + ([double]$PdfRect.Width / 2.0)
    $centerY = $top + ([double]$PdfRect.Height / 2.0)

    $topLeft = Get-RotatedPdfPoint -PointX $left -PointY $top -CenterX $centerX -CenterY $centerY -AngleDegrees $RotationAngle
    $topRight = Get-RotatedPdfPoint -PointX $right -PointY $top -CenterX $centerX -CenterY $centerY -AngleDegrees $RotationAngle
    $bottomRight = Get-RotatedPdfPoint -PointX $right -PointY $bottom -CenterX $centerX -CenterY $centerY -AngleDegrees $RotationAngle
    $bottomLeft = Get-RotatedPdfPoint -PointX $left -PointY $bottom -CenterX $centerX -CenterY $centerY -AngleDegrees $RotationAngle

    $points = @($topLeft, $topRight, $bottomRight, $bottomLeft)
    $previewPoints = New-Object 'System.Drawing.PointF[]' 4
    for ($i = 0; $i -lt 4; $i++) {
        $previewPoints[$i] = New-Object System.Drawing.PointF(
            [float]($PreviewPageRect.X + ($points[$i].X * $PreviewPageRect.Scale)),
            [float]($PreviewPageRect.Y + ($points[$i].Y * $PreviewPageRect.Scale))
        )
    }

    return $previewPoints
}
}

if (-not (Get-Command -Name 'Test-PreviewPointInRotatedPdfRect' -CommandType Function -ErrorAction SilentlyContinue)) {
function Test-PreviewPointInRotatedPdfRect {
    param(
        [Parameter(Mandatory = $true)]$PdfRect,
        [Parameter(Mandatory = $true)][double]$RotationAngle,
        [Parameter(Mandatory = $true)]$PreviewPageRect,
        [Parameter(Mandatory = $true)][double]$PreviewX,
        [Parameter(Mandatory = $true)][double]$PreviewY
    )

    $pdfPoint = Convert-PreviewPointToPdfPoint -PreviewX $PreviewX -PreviewY $PreviewY -PreviewPageRect $PreviewPageRect
    $centerX = [double]$PdfRect.X + ([double]$PdfRect.Width / 2.0)
    $centerY = [double]$PdfRect.Y + ([double]$PdfRect.Height / 2.0)
    $localPoint = Get-RotatedPdfPoint -PointX $pdfPoint.X -PointY $pdfPoint.Y -CenterX $centerX -CenterY $centerY -AngleDegrees (-1.0 * $RotationAngle)

    return (
        $localPoint.X -ge [double]$PdfRect.X -and
        $localPoint.X -le ([double]$PdfRect.X + [double]$PdfRect.Width) -and
        $localPoint.Y -ge [double]$PdfRect.Y -and
        $localPoint.Y -le ([double]$PdfRect.Y + [double]$PdfRect.Height)
    )
}
}

if (-not (Get-Command -Name 'Get-PreviewResizeHandleRects' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-PreviewResizeHandleRects {
    param(
        [Parameter(Mandatory = $true)]$PdfRect,
        [double]$RotationAngle = 0.0,
        [Parameter(Mandatory = $true)]$PreviewPageRect,
        [int]$HandleSize = 10
    )
    $half = $HandleSize / 2.0
    $points = Get-RotatedPreviewPointsForPdfRect -PdfRect $PdfRect -RotationAngle $RotationAngle -PreviewPageRect $PreviewPageRect
    $leftMidX = ($points[0].X + $points[3].X) / 2.0
    $leftMidY = ($points[0].Y + $points[3].Y) / 2.0
    $topMidX = ($points[0].X + $points[1].X) / 2.0
    $topMidY = ($points[0].Y + $points[1].Y) / 2.0
    $rightMidX = ($points[1].X + $points[2].X) / 2.0
    $rightMidY = ($points[1].Y + $points[2].Y) / 2.0
    $bottomMidX = ($points[2].X + $points[3].X) / 2.0
    $bottomMidY = ($points[2].Y + $points[3].Y) / 2.0

    return [PSCustomObject]@{
        TopLeft = New-Object System.Drawing.RectangleF(
            [float]($points[0].X - $half),
            [float]($points[0].Y - $half),
            [float]$HandleSize,
            [float]$HandleSize
        )
        Top = New-Object System.Drawing.RectangleF(
            [float]($topMidX - $half),
            [float]($topMidY - $half),
            [float]$HandleSize,
            [float]$HandleSize
        )
        TopRight = New-Object System.Drawing.RectangleF(
            [float]($points[1].X - $half),
            [float]($points[1].Y - $half),
            [float]$HandleSize,
            [float]$HandleSize
        )
        Right = New-Object System.Drawing.RectangleF(
            [float]($rightMidX - $half),
            [float]($rightMidY - $half),
            [float]$HandleSize,
            [float]$HandleSize
        )
        BottomLeft = New-Object System.Drawing.RectangleF(
            [float]($points[3].X - $half),
            [float]($points[3].Y - $half),
            [float]$HandleSize,
            [float]$HandleSize
        )
        BottomRight = New-Object System.Drawing.RectangleF(
            [float]($points[2].X - $half),
            [float]($points[2].Y - $half),
            [float]$HandleSize,
            [float]$HandleSize
        )
        Bottom = New-Object System.Drawing.RectangleF(
            [float]($bottomMidX - $half),
            [float]($bottomMidY - $half),
            [float]$HandleSize,
            [float]$HandleSize
        )
        Left = New-Object System.Drawing.RectangleF(
            [float]($leftMidX - $half),
            [float]($leftMidY - $half),
            [float]$HandleSize,
            [float]$HandleSize
        )
    }
}
}

if (-not (Get-Command -Name 'Get-PreviewResizeHandleHit' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-PreviewResizeHandleHit {
    param(
        [Parameter(Mandatory = $true)]$PdfRect,
        [double]$RotationAngle = 0.0,
        [Parameter(Mandatory = $true)]$PreviewPageRect,
        [Parameter(Mandatory = $true)][double]$PreviewX,
        [Parameter(Mandatory = $true)][double]$PreviewY,
        [int]$HandleSize = 10
    )

    $handles = Get-PreviewResizeHandleRects -PdfRect $PdfRect -RotationAngle $RotationAngle -PreviewPageRect $PreviewPageRect -HandleSize $HandleSize
    foreach ($name in @('TopLeft', 'Top', 'TopRight', 'Right', 'BottomRight', 'Bottom', 'BottomLeft', 'Left')) {
        if ($handles.$name.Contains([float]$PreviewX, [float]$PreviewY)) {
            return $name
        }
    }

    return $null
}
}

if (-not (Get-Command -Name 'Get-PreviewRotationHandleInfo' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-PreviewRotationHandleInfo {
    param(
        [Parameter(Mandatory = $true)]$PdfRect,
        [double]$RotationAngle = 0.0,
        [Parameter(Mandatory = $true)]$PreviewPageRect,
        [double]$AxisLengthPreview = 22.0,
        [double]$HandleDiameterPreview = 12.0
    )

    $centerPdfX = [double]$PdfRect.X + ([double]$PdfRect.Width / 2.0)
    $centerPdfY = [double]$PdfRect.Y + ([double]$PdfRect.Height / 2.0)
    $topCenterPdfX = $centerPdfX
    $topCenterPdfY = [double]$PdfRect.Y
    $axisLengthPdf = $AxisLengthPreview / [double]$PreviewPageRect.Scale
    $handleRadiusPreview = $HandleDiameterPreview / 2.0

    $axisStartPdf = Get-RotatedPdfPoint -PointX $topCenterPdfX -PointY $topCenterPdfY -CenterX $centerPdfX -CenterY $centerPdfY -AngleDegrees $RotationAngle
    $handleCenterPdf = Get-RotatedPdfPoint -PointX $topCenterPdfX -PointY ($topCenterPdfY - $axisLengthPdf) -CenterX $centerPdfX -CenterY $centerPdfY -AngleDegrees $RotationAngle

    $axisStartPreview = New-Object System.Drawing.PointF(
        [float]($PreviewPageRect.X + ($axisStartPdf.X * $PreviewPageRect.Scale)),
        [float]($PreviewPageRect.Y + ($axisStartPdf.Y * $PreviewPageRect.Scale))
    )
    $handleCenterPreview = New-Object System.Drawing.PointF(
        [float]($PreviewPageRect.X + ($handleCenterPdf.X * $PreviewPageRect.Scale)),
        [float]($PreviewPageRect.Y + ($handleCenterPdf.Y * $PreviewPageRect.Scale))
    )

    return [PSCustomObject]@{
        AxisStart = $axisStartPreview
        HandleCenter = $handleCenterPreview
        HandleBounds = New-Object System.Drawing.RectangleF(
            [float]($handleCenterPreview.X - $handleRadiusPreview),
            [float]($handleCenterPreview.Y - $handleRadiusPreview),
            [float]$HandleDiameterPreview,
            [float]$HandleDiameterPreview
        )
    }
}
}

if (-not (Get-Command -Name 'Get-PreviewCropHandleRects' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-PreviewCropHandleRects {
    param(
        [Parameter(Mandatory = $true)]$FullPdfRect,
        [Parameter(Mandatory = $true)]$Crop,
        [double]$RotationAngle = 0.0,
        [Parameter(Mandatory = $true)]$PreviewPageRect,
        [int]$HandleSize = 10
    )

    $cropRect = Get-PdfCropRectWithinImageRect -PdfRect $FullPdfRect -Crop $Crop
    $points = Get-RotatedPreviewPointsForPdfRect -PdfRect $cropRect -RotationAngle $RotationAngle -PreviewPageRect $PreviewPageRect
    $half = $HandleSize / 2.0

    $leftMidX = ($points[0].X + $points[3].X) / 2.0
    $leftMidY = ($points[0].Y + $points[3].Y) / 2.0
    $topMidX = ($points[0].X + $points[1].X) / 2.0
    $topMidY = ($points[0].Y + $points[1].Y) / 2.0
    $rightMidX = ($points[1].X + $points[2].X) / 2.0
    $rightMidY = ($points[1].Y + $points[2].Y) / 2.0
    $bottomMidX = ($points[2].X + $points[3].X) / 2.0
    $bottomMidY = ($points[2].Y + $points[3].Y) / 2.0

    return [PSCustomObject]@{
        Left = New-Object System.Drawing.RectangleF([float]($leftMidX - $half), [float]($leftMidY - $half), [float]$HandleSize, [float]$HandleSize)
        Top = New-Object System.Drawing.RectangleF([float]($topMidX - $half), [float]($topMidY - $half), [float]$HandleSize, [float]$HandleSize)
        Right = New-Object System.Drawing.RectangleF([float]($rightMidX - $half), [float]($rightMidY - $half), [float]$HandleSize, [float]$HandleSize)
        Bottom = New-Object System.Drawing.RectangleF([float]($bottomMidX - $half), [float]($bottomMidY - $half), [float]$HandleSize, [float]$HandleSize)
        TopLeft = New-Object System.Drawing.RectangleF([float]($points[0].X - $half), [float]($points[0].Y - $half), [float]$HandleSize, [float]$HandleSize)
        TopRight = New-Object System.Drawing.RectangleF([float]($points[1].X - $half), [float]($points[1].Y - $half), [float]$HandleSize, [float]$HandleSize)
        BottomRight = New-Object System.Drawing.RectangleF([float]($points[2].X - $half), [float]($points[2].Y - $half), [float]$HandleSize, [float]$HandleSize)
        BottomLeft = New-Object System.Drawing.RectangleF([float]($points[3].X - $half), [float]($points[3].Y - $half), [float]$HandleSize, [float]$HandleSize)
    }
}
}

if (-not (Get-Command -Name 'Get-PreviewCropHandleHit' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-PreviewCropHandleHit {
    param(
        [Parameter(Mandatory = $true)]$FullPdfRect,
        [Parameter(Mandatory = $true)]$Crop,
        [double]$RotationAngle = 0.0,
        [Parameter(Mandatory = $true)]$PreviewPageRect,
        [Parameter(Mandatory = $true)][double]$PreviewX,
        [Parameter(Mandatory = $true)][double]$PreviewY,
        [int]$HandleSize = 10
    )

    $handles = Get-PreviewCropHandleRects -FullPdfRect $FullPdfRect -Crop $Crop -RotationAngle $RotationAngle -PreviewPageRect $PreviewPageRect -HandleSize $HandleSize
    foreach ($name in @('TopLeft', 'TopRight', 'BottomRight', 'BottomLeft', 'Left', 'Top', 'Right', 'Bottom')) {
        if ($handles.$name.Contains([float]$PreviewX, [float]$PreviewY)) {
            return $name
        }
    }

    return $null
}
}

if (-not (Get-Command -Name 'Update-ImageCropFromPreviewHandle' -CommandType Function -ErrorAction SilentlyContinue)) {
function Update-ImageCropFromPreviewHandle {
    param(
        [Parameter(Mandatory = $true)]$OriginalCrop,
        [Parameter(Mandatory = $true)][string]$Handle,
        [Parameter(Mandatory = $true)]$FullPdfRect,
        [double]$RotationAngle = 0.0,
        [Parameter(Mandatory = $true)][double]$CurrentPreviewX,
        [Parameter(Mandatory = $true)][double]$CurrentPreviewY,
        [Parameter(Mandatory = $true)]$PreviewPageRect
    )

    $crop = Get-NormalizedImageCrop -Crop $OriginalCrop
    $pdfPoint = Convert-PreviewPointToPdfPoint -PreviewX $CurrentPreviewX -PreviewY $CurrentPreviewY -PreviewPageRect $PreviewPageRect
    $centerX = [double]$FullPdfRect.X + ([double]$FullPdfRect.Width / 2.0)
    $centerY = [double]$FullPdfRect.Y + ([double]$FullPdfRect.Height / 2.0)
    $localPoint = Get-RotatedPdfPoint -PointX $pdfPoint.X -PointY $pdfPoint.Y -CenterX $centerX -CenterY $centerY -AngleDegrees (-1.0 * $RotationAngle)

    $normalizedX = ($localPoint.X - [double]$FullPdfRect.X) / [double]$FullPdfRect.Width
    $normalizedY = ($localPoint.Y - [double]$FullPdfRect.Y) / [double]$FullPdfRect.Height
    $minimumVisible = 0.05

    switch ($Handle) {
        'Left' {
            $crop.Left = [Math]::Max(0.0, [Math]::Min(([double]$crop.Right - $minimumVisible), $normalizedX))
        }
        'Top' {
            $crop.Top = [Math]::Max(0.0, [Math]::Min(([double]$crop.Bottom - $minimumVisible), $normalizedY))
        }
        'Right' {
            $crop.Right = [Math]::Min(1.0, [Math]::Max(([double]$crop.Left + $minimumVisible), $normalizedX))
        }
        'Bottom' {
            $crop.Bottom = [Math]::Min(1.0, [Math]::Max(([double]$crop.Top + $minimumVisible), $normalizedY))
        }
        'TopLeft' {
            $crop.Left = [Math]::Max(0.0, [Math]::Min(([double]$crop.Right - $minimumVisible), $normalizedX))
            $crop.Top = [Math]::Max(0.0, [Math]::Min(([double]$crop.Bottom - $minimumVisible), $normalizedY))
        }
        'TopRight' {
            $crop.Right = [Math]::Min(1.0, [Math]::Max(([double]$crop.Left + $minimumVisible), $normalizedX))
            $crop.Top = [Math]::Max(0.0, [Math]::Min(([double]$crop.Bottom - $minimumVisible), $normalizedY))
        }
        'BottomRight' {
            $crop.Right = [Math]::Min(1.0, [Math]::Max(([double]$crop.Left + $minimumVisible), $normalizedX))
            $crop.Bottom = [Math]::Min(1.0, [Math]::Max(([double]$crop.Top + $minimumVisible), $normalizedY))
        }
        'BottomLeft' {
            $crop.Left = [Math]::Max(0.0, [Math]::Min(([double]$crop.Right - $minimumVisible), $normalizedX))
            $crop.Bottom = [Math]::Min(1.0, [Math]::Max(([double]$crop.Top + $minimumVisible), $normalizedY))
        }
        default {
            throw 'Unknown crop handle.'
        }
    }

    return [PSCustomObject]@{
        Crop = $crop
        PdfRect = Get-PdfCropRectWithinImageRect -PdfRect $FullPdfRect -Crop $crop
    }
}
}

if (-not (Get-Command -Name 'Test-PreviewRotationHandleHit' -CommandType Function -ErrorAction SilentlyContinue)) {
function Test-PreviewRotationHandleHit {
    param(
        [Parameter(Mandatory = $true)]$PdfRect,
        [double]$RotationAngle = 0.0,
        [Parameter(Mandatory = $true)]$PreviewPageRect,
        [Parameter(Mandatory = $true)][double]$PreviewX,
        [Parameter(Mandatory = $true)][double]$PreviewY
    )

    $info = Get-PreviewRotationHandleInfo -PdfRect $PdfRect -RotationAngle $RotationAngle -PreviewPageRect $PreviewPageRect
    return $info.HandleBounds.Contains([float]$PreviewX, [float]$PreviewY)
}
}

if (-not (Get-Command -Name 'Get-RotationAngleFromPreviewPoint' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-RotationAngleFromPreviewPoint {
    param(
        [Parameter(Mandatory = $true)]$PdfRect,
        [Parameter(Mandatory = $true)]$PreviewPageRect,
        [Parameter(Mandatory = $true)][double]$PreviewX,
        [Parameter(Mandatory = $true)][double]$PreviewY
    )

    $centerPreviewX = [double]$PreviewPageRect.X + (([double]$PdfRect.X + ([double]$PdfRect.Width / 2.0)) * [double]$PreviewPageRect.Scale)
    $centerPreviewY = [double]$PreviewPageRect.Y + (([double]$PdfRect.Y + ([double]$PdfRect.Height / 2.0)) * [double]$PreviewPageRect.Scale)
    $dx = $PreviewX - $centerPreviewX
    $dy = $PreviewY - $centerPreviewY

    return ([Math]::Atan2($dy, $dx) * 180.0 / [Math]::PI) + 90.0
}
}

if (-not (Get-Command -Name 'Move-PdfRectByPreviewDelta' -CommandType Function -ErrorAction SilentlyContinue)) {
function Move-PdfRectByPreviewDelta {
    param(
        [Parameter(Mandatory = $true)]$PdfRect,
        [Parameter(Mandatory = $true)][double]$DeltaPixelsX,
        [Parameter(Mandatory = $true)][double]$DeltaPixelsY,
        [Parameter(Mandatory = $true)]$PreviewPageRect,
        [string]$PageFormat = 'A4',
        [double]$PageWidthMillimeters = 0.0,
        [double]$PageHeightMillimeters = 0.0
    )

    $deltaPdfX = $DeltaPixelsX / $PreviewPageRect.Scale
    $deltaPdfY = $DeltaPixelsY / $PreviewPageRect.Scale

    $movedRect = [PSCustomObject]@{
        X      = ([double]$PdfRect.X + $deltaPdfX)
        Y      = ([double]$PdfRect.Y + $deltaPdfY)
        Width  = [double]$PdfRect.Width
        Height = [double]$PdfRect.Height
    }

    return Clamp-PdfImageRectToPage -ImageRect $movedRect -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters
}
}

if (-not (Get-Command -Name 'Resize-PdfRectFromPreviewHandle' -CommandType Function -ErrorAction SilentlyContinue)) {
function Resize-PdfRectFromPreviewHandle {
    param(
        [Parameter(Mandatory = $true)]$OriginalPdfRect,
        [Parameter(Mandatory = $true)][string]$Handle,
        [double]$RotationAngle = 0.0,
        [Parameter(Mandatory = $true)][double]$CurrentPreviewX,
        [Parameter(Mandatory = $true)][double]$CurrentPreviewY,
        [Parameter(Mandatory = $true)]$PreviewPageRect,
        [string]$PageFormat = 'A4',
        [double]$PageWidthMillimeters = 0.0,
        [double]$PageHeightMillimeters = 0.0,
        [bool]$LockAspectRatio = $true
    )

    $page = Get-PdfPageLayout -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters
    $originalX = [double]$OriginalPdfRect.X
    $originalY = [double]$OriginalPdfRect.Y
    $originalWidth = [double]$OriginalPdfRect.Width
    $originalHeight = [double]$OriginalPdfRect.Height

    if ($originalWidth -le 0 -or $originalHeight -le 0) {
        throw 'Invalid image rect size.'
    }

    $minimumSize = 12.0

    $currentPdfPoint = Convert-PreviewPointToPdfPoint -PreviewX $CurrentPreviewX -PreviewY $CurrentPreviewY -PreviewPageRect $PreviewPageRect
    $centerX = $originalX + ($originalWidth / 2.0)
    $centerY = $originalY + ($originalHeight / 2.0)
    $localPdfPoint = Get-RotatedPdfPoint `
        -PointX $currentPdfPoint.X `
        -PointY $currentPdfPoint.Y `
        -CenterX $centerX `
        -CenterY $centerY `
        -AngleDegrees (-1.0 * $RotationAngle)
    $currentPdfX = [double]$localPdfPoint.X
    $currentPdfY = [double]$localPdfPoint.Y

    switch ($Handle) {
        'TopLeft' {
            $anchorX = $originalX + $originalWidth
            $anchorY = $originalY + $originalHeight
            $maxWidth = $anchorX
            $maxHeight = $anchorY
            $proposedWidth = $anchorX - $currentPdfX
            $proposedHeight = $anchorY - $currentPdfY
        }
        'TopRight' {
            $anchorX = $originalX
            $anchorY = $originalY + $originalHeight
            $maxWidth = $page.WidthPoints - $anchorX
            $maxHeight = $anchorY
            $proposedWidth = $currentPdfX - $anchorX
            $proposedHeight = $anchorY - $currentPdfY
        }
        'BottomLeft' {
            $anchorX = $originalX + $originalWidth
            $anchorY = $originalY
            $maxWidth = $anchorX
            $maxHeight = $page.HeightPoints - $anchorY
            $proposedWidth = $anchorX - $currentPdfX
            $proposedHeight = $currentPdfY - $anchorY
        }
        'BottomRight' {
            $anchorX = $originalX
            $anchorY = $originalY
            $maxWidth = $page.WidthPoints - $anchorX
            $maxHeight = $page.HeightPoints - $anchorY
            $proposedWidth = $currentPdfX - $anchorX
            $proposedHeight = $currentPdfY - $anchorY
        }
        'Left' {
            $anchorX = $originalX + $originalWidth
            $proposedWidth = $anchorX - $currentPdfX
        }
        'Top' {
            $anchorY = $originalY + $originalHeight
            $proposedHeight = $anchorY - $currentPdfY
        }
        'Right' {
            $anchorX = $originalX
            $proposedWidth = $currentPdfX - $anchorX
        }
        'Bottom' {
            $anchorY = $originalY
            $proposedHeight = $currentPdfY - $anchorY
        }
        default {
            throw 'Unknown resize handle.'
        }
    }

    if ($Handle -in @('Left', 'Right', 'Top', 'Bottom')) {
        if ($LockAspectRatio) {
            $scale = 1.0
            if ($Handle -in @('Left', 'Right')) {
                $proposedWidth = [Math]::Max($minimumSize, $proposedWidth)
                $scale = $proposedWidth / $originalWidth
            }
            else {
                $proposedHeight = [Math]::Max($minimumSize, $proposedHeight)
                $scale = $proposedHeight / $originalHeight
            }

            $maxScaleX = $page.WidthPoints / $originalWidth
            $maxScaleY = $page.HeightPoints / $originalHeight
            $minScaleX = $minimumSize / $originalWidth
            $minScaleY = $minimumSize / $originalHeight
            $scale = [Math]::Max($scale, [Math]::Max($minScaleX, $minScaleY))
            $scale = [Math]::Min($scale, [Math]::Min($maxScaleX, $maxScaleY))

            $newWidth = $originalWidth * $scale
            $newHeight = $originalHeight * $scale
            $newX = $centerX - ($newWidth / 2.0)
            $newY = $centerY - ($newHeight / 2.0)

            return Clamp-PdfImageRectToPage -ImageRect ([PSCustomObject]@{
                X      = [double]$newX
                Y      = [double]$newY
                Width  = [double]$newWidth
                Height = [double]$newHeight
            }) -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters
        }

        if ($Handle -in @('Left', 'Right')) {
            $newWidth = [Math]::Max($minimumSize, [Math]::Min($proposedWidth, $page.WidthPoints))
            $newHeight = $originalHeight
            switch ($Handle) {
                'Left' {
                    $newX = $anchorX - $newWidth
                    $newY = $originalY
                }
                'Right' {
                    $newX = $anchorX
                    $newY = $originalY
                }
            }
        }
        else {
            $newWidth = $originalWidth
            $newHeight = [Math]::Max($minimumSize, [Math]::Min($proposedHeight, $page.HeightPoints))
            switch ($Handle) {
                'Top' {
                    $newX = $originalX
                    $newY = $anchorY - $newHeight
                }
                'Bottom' {
                    $newX = $originalX
                    $newY = $anchorY
                }
            }
        }

        return Clamp-PdfImageRectToPage -ImageRect ([PSCustomObject]@{
            X      = [double]$newX
            Y      = [double]$newY
            Width  = [double]$newWidth
            Height = [double]$newHeight
        }) -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters
    }

    $proposedWidth = [Math]::Max($minimumSize, $proposedWidth)
    $proposedHeight = [Math]::Max($minimumSize, $proposedHeight)

    if ($LockAspectRatio) {
        $ratio = $originalWidth / $originalHeight
        $widthFromHeight = $proposedHeight * $ratio
        $heightFromWidth = $proposedWidth / $ratio

        if ($widthFromHeight -le $proposedWidth) {
            $newWidth = $widthFromHeight
            $newHeight = $proposedHeight
        }
        else {
            $newWidth = $proposedWidth
            $newHeight = $heightFromWidth
        }

        $newWidth = [Math]::Max($minimumSize, [Math]::Min($newWidth, $maxWidth))
        $newHeight = $newWidth / $ratio

        if ($newHeight -gt $maxHeight) {
            $newHeight = $maxHeight
            $newWidth = $newHeight * $ratio
        }

        $newWidth = [Math]::Max($minimumSize, $newWidth)
        $newHeight = [Math]::Max($minimumSize, $newHeight)
    }
    else {
        $newWidth = [Math]::Max($minimumSize, [Math]::Min($proposedWidth, $maxWidth))
        $newHeight = [Math]::Max($minimumSize, [Math]::Min($proposedHeight, $maxHeight))
    }

    switch ($Handle) {
        'TopLeft' {
            $newX = $anchorX - $newWidth
            $newY = $anchorY - $newHeight
        }
        'TopRight' {
            $newX = $anchorX
            $newY = $anchorY - $newHeight
        }
        'BottomLeft' {
            $newX = $anchorX - $newWidth
            $newY = $anchorY
        }
        'BottomRight' {
            $newX = $anchorX
            $newY = $anchorY
        }
    }

    return [PSCustomObject]@{
        X      = [double]$newX
        Y      = [double]$newY
        Width  = [double]$newWidth
        Height = [double]$newHeight
    }
}
}

if (-not (Get-Command -Name 'Draw-PdfImageItem' -CommandType Function -ErrorAction SilentlyContinue)) {
function Draw-PdfImageItem {
    param(
        [Parameter(Mandatory = $true)]$Graphics,
        [Parameter(Mandatory = $true)]$XImage,
        [Parameter(Mandatory = $true)]$ContainerPdfRect,
        [Parameter(Mandatory = $true)]$DrawPdfRect,
        [double]$RotationAngle = 0.0,
        [string]$PageFormat = 'A4',
        [double]$PageWidthMillimeters = 0.0,
        [double]$PageHeightMillimeters = 0.0
    )

    $containerRect = Clamp-PdfImageRectToPage -ImageRect $ContainerPdfRect -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters
    $drawRect = Clamp-PdfImageRectToPage -ImageRect $DrawPdfRect -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters
    $centerX = [double]$containerRect.X + ([double]$containerRect.Width / 2.0)
    $centerY = [double]$containerRect.Y + ([double]$containerRect.Height / 2.0)
    $state = $Graphics.Save()
    try {
        $Graphics.TranslateTransform($centerX, $centerY)
        if ([Math]::Abs($RotationAngle) -gt 0.001) {
            $Graphics.RotateTransform($RotationAngle)
        }
        $drawOffsetX = [double]$drawRect.X - $centerX
        $drawOffsetY = [double]$drawRect.Y - $centerY
        $Graphics.DrawImage($XImage, $drawOffsetX, $drawOffsetY, [double]$drawRect.Width, [double]$drawRect.Height)
    }
    finally {
        $Graphics.Restore($state)
    }
}
}

if (-not (Get-Command -Name 'Save-ImageItemsToPdf' -CommandType Function -ErrorAction SilentlyContinue)) {
function Save-ImageItemsToPdf {
    param(
        [Parameter(Mandatory = $true)][object[]]$ImageItems,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [string]$PageFormat = 'A4',
        [double]$PageWidthMillimeters = 0.0,
        [double]$PageHeightMillimeters = 0.0
    )

    Import-PdfRuntime

    $document = $null
    $graphics = $null
    $xImages = New-Object System.Collections.Generic.List[object]
    $temporaryBitmaps = New-Object System.Collections.Generic.List[object]

    try {
        $pageLayout = Get-PdfPageLayout -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters
        $document = New-Object PdfSharp.Pdf.PdfDocument
        $page = $document.AddPage()
        $page.Width = [PdfSharp.Drawing.XUnit]::FromMillimeter($pageLayout.WidthMillimeters)
        $page.Height = [PdfSharp.Drawing.XUnit]::FromMillimeter($pageLayout.HeightMillimeters)

        $graphics = [PdfSharp.Drawing.XGraphics]::FromPdfPage($page)

        foreach ($item in $ImageItems) {
            if ($null -eq $item -or $null -eq $item.Bitmap -or $null -eq $item.PdfRect) {
                continue
            }

            $rotationAngle = 0.0
            if ($null -ne $item.PSObject.Properties['RotationAngle']) {
                $rotationAngle = [double]$item.RotationAngle
            }

            $crop = New-DefaultImageCrop
            if ($null -ne $item.PSObject.Properties['Crop']) {
                $crop = Get-NormalizedImageCrop -Crop $item.Crop
            }

            $bitmapForExport = $item.Bitmap
            if (-not (Test-IsDefaultImageCrop -Crop $crop)) {
                $bitmapForExport = New-CroppedBitmap -Bitmap $item.Bitmap -Crop $crop
                $temporaryBitmaps.Add($bitmapForExport)
            }

            $xImage = [PdfSharp.Drawing.XImage]::FromGdiPlusImage($bitmapForExport)
            $xImages.Add($xImage)
            Draw-PdfImageItem -Graphics $graphics -XImage $xImage -ContainerPdfRect $item.PdfRect -DrawPdfRect $item.PdfRect -RotationAngle $rotationAngle -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters
        }

        $document.Save($OutputFile)
    }
    finally {
        foreach ($xImage in $xImages) {
            if ($null -ne $xImage) {
                $xImage.Dispose()
            }
        }

        foreach ($temporaryBitmap in $temporaryBitmaps) {
            if ($null -ne $temporaryBitmap) {
                $temporaryBitmap.Dispose()
            }
        }

        if ($null -ne $graphics) {
            $graphics.Dispose()
        }

        if ($null -ne $document) {
            $document.Dispose()
        }
    }
}
}

if (-not (Get-Command -Name 'Save-ImageBitmapToPdf' -CommandType Function -ErrorAction SilentlyContinue)) {
function Save-ImageBitmapToPdf {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)]$ImageRect,
        [string]$PageFormat = 'A4',
        [double]$PageWidthMillimeters = 0.0,
        [double]$PageHeightMillimeters = 0.0
    )

    Import-PdfRuntime

    $document = $null
    $graphics = $null
    $xImage = $null
    $bitmapOwnedByXImage = $false

    try {
        $pageLayout = Get-PdfPageLayout -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters
        $document = New-Object PdfSharp.Pdf.PdfDocument
        $page = $document.AddPage()
        $page.Width = [PdfSharp.Drawing.XUnit]::FromMillimeter($pageLayout.WidthMillimeters)
        $page.Height = [PdfSharp.Drawing.XUnit]::FromMillimeter($pageLayout.HeightMillimeters)

        $graphics = [PdfSharp.Drawing.XGraphics]::FromPdfPage($page)
        $xImage = [PdfSharp.Drawing.XImage]::FromGdiPlusImage($Bitmap)
        $bitmapOwnedByXImage = $true

        $clampedRect = Clamp-PdfImageRectToPage -ImageRect $ImageRect -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters
        Draw-PdfImageItem -Graphics $graphics -XImage $xImage -ContainerPdfRect $clampedRect -DrawPdfRect $clampedRect -RotationAngle 0.0 -PageFormat $PageFormat -PageWidthMillimeters $PageWidthMillimeters -PageHeightMillimeters $PageHeightMillimeters
        $document.Save($OutputFile)
    }
    finally {
        if ($null -ne $graphics) {
            $graphics.Dispose()
        }

        if ($null -ne $xImage) {
            $xImage.Dispose()
        }

        if (-not $bitmapOwnedByXImage -and $null -ne $Bitmap) {
            $Bitmap.Dispose()
        }

        if ($null -ne $document) {
            $document.Dispose()
        }
    }
}
}

if (-not (Get-Command -Name 'Convert-ImageFileToPdf' -CommandType Function -ErrorAction SilentlyContinue)) {
function Convert-ImageFileToPdf {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile
    )

    $workingBitmap = $null

    try {
        $workingBitmap = New-NormalizedImageBitmap -InputFile $InputFile
        if ($null -eq $workingBitmap) {
            throw 'Unable to load the source image.'
        }

        if ($workingBitmap.Width -le 0 -or $workingBitmap.Height -le 0) {
            throw 'The source image is empty or invalid.'
        }

        $imageRect = New-InitialPdfImageRect -Bitmap $workingBitmap
        Save-ImageBitmapToPdf -Bitmap $workingBitmap -OutputFile $OutputFile -ImageRect $imageRect
        $workingBitmap = $null
    }
    finally {
        if ($null -ne $workingBitmap) {
            $workingBitmap.Dispose()
        }
    }
}
}
