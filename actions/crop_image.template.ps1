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

    return 'FFmpeg failed during image crop.'
}

function Get-ImageInfo {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $image = [System.Drawing.Image]::FromStream($stream, $false, $false)
        try {
            return [PSCustomObject]@{
                Width  = [int]$image.Width
                Height = [int]$image.Height
            }
        }
        finally {
            $image.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function New-PreviewBitmap {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$MaxWidth,
        [Parameter(Mandatory = $true)][int]$MaxHeight
    )

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $source = [System.Drawing.Image]::FromStream($stream, $false, $false)
        try {
            $scale = [Math]::Min(($MaxWidth / [double]$source.Width), ($MaxHeight / [double]$source.Height))
            if ($scale -gt 1.0) { $scale = 1.0 }
            $previewWidth = [Math]::Max(1, [int][Math]::Round($source.Width * $scale))
            $previewHeight = [Math]::Max(1, [int][Math]::Round($source.Height * $scale))

            $bitmap = New-Object System.Drawing.Bitmap($previewWidth, $previewHeight)
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.DrawImage($source, 0, 0, $previewWidth, $previewHeight)
            }
            finally {
                $graphics.Dispose()
            }

            return $bitmap
        }
        finally {
            $source.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Get-RatioValue {
    param([string]$Mode)

    switch ($Mode) {
        'Square' { return 1.0 }
        '16:9'   { return (16.0 / 9.0) }
        '4:3'    { return (4.0 / 3.0) }
        default  { return $null }
    }
}

function Get-NormalizedRect {
    param([System.Drawing.RectangleF]$Rect)

    $x = [Math]::Min($Rect.Left, $Rect.Right)
    $y = [Math]::Min($Rect.Top, $Rect.Bottom)
    $w = [Math]::Abs($Rect.Width)
    $h = [Math]::Abs($Rect.Height)
    return New-Object System.Drawing.RectangleF($x, $y, $w, $h)
}

function Clamp-CropRect {
    param(
        [System.Drawing.RectangleF]$Rect,
        [System.Drawing.RectangleF]$Bounds,
        [Nullable[double]]$Ratio
    )

    $r = Get-NormalizedRect -Rect $Rect
    $minSize = 12.0

    if ($null -ne $Ratio) {
        if ($r.Width / [double]$r.Height -gt $Ratio) {
            $r.Width = [float]($r.Height * $Ratio)
        }
        else {
            $r.Height = [float]($r.Width / $Ratio)
        }
    }

    if ($r.Width -lt $minSize) { $r.Width = [float]$minSize }
    if ($r.Height -lt $minSize) { $r.Height = [float]$minSize }

    if ($null -ne $Ratio) {
        if ($r.Width -gt $Bounds.Width) {
            $r.Width = [float]$Bounds.Width
            $r.Height = [float]($r.Width / $Ratio)
        }
        if ($r.Height -gt $Bounds.Height) {
            $r.Height = [float]$Bounds.Height
            $r.Width = [float]($r.Height * $Ratio)
        }
    }
    else {
        if ($r.Width -gt $Bounds.Width) { $r.Width = [float]$Bounds.Width }
        if ($r.Height -gt $Bounds.Height) { $r.Height = [float]$Bounds.Height }
    }

    if ($r.X -lt $Bounds.X) { $r.X = [float]$Bounds.X }
    if ($r.Y -lt $Bounds.Y) { $r.Y = [float]$Bounds.Y }
    if ($r.Right -gt $Bounds.Right) { $r.X = [float]($Bounds.Right - $r.Width) }
    if ($r.Bottom -gt $Bounds.Bottom) { $r.Y = [float]($Bounds.Bottom - $r.Height) }

    return $r
}

function Show-CropWindow {
    param(
        [Parameter(Mandatory = $true)][string]$ImagePath,
        [Parameter(Mandatory = $true)][int]$SourceWidth,
        [Parameter(Mandatory = $true)][int]$SourceHeight
    )

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $previewBitmap = New-PreviewBitmap -Path $ImagePath -MaxWidth 760 -MaxHeight 520
    $script:cropRect = New-Object System.Drawing.RectangleF(0, 0, 1, 1)
    $script:imageBounds = New-Object System.Drawing.RectangleF(0, 0, 1, 1)
    $script:dragMode = ''
    $script:dragStart = New-Object System.Drawing.PointF(0, 0)
    $script:dragRect = New-Object System.Drawing.RectangleF(0, 0, 1, 1)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFActions - Crop image'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(940, 650)
    $form.TopMost = $true

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(12, 12)
    $panel.Size = New-Object System.Drawing.Size(780, 560)
    $panel.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 32)
    $form.Controls.Add($panel)

    $group = New-Object System.Windows.Forms.GroupBox
    $group.Text = 'Ratio'
    $group.Location = New-Object System.Drawing.Point(806, 12)
    $group.Size = New-Object System.Drawing.Size(120, 150)
    $form.Controls.Add($group)

    $ratioOptions = @('Free', 'Square', '16:9', '4:3')
    $radioButtons = @()
    for ($i = 0; $i -lt $ratioOptions.Count; $i++) {
        $radio = New-Object System.Windows.Forms.RadioButton
        $radio.Text = $ratioOptions[$i]
        $radio.Tag = $ratioOptions[$i]
        $radio.Location = New-Object System.Drawing.Point(14, (24 + ($i * 28)))
        $radio.Size = New-Object System.Drawing.Size(90, 24)
        if ($i -eq 0) { $radio.Checked = $true }
        $group.Controls.Add($radio)
        $radioButtons += $radio
    }

    $labelSize = New-Object System.Windows.Forms.Label
    $labelSize.Location = New-Object System.Drawing.Point(806, 178)
    $labelSize.Size = New-Object System.Drawing.Size(120, 42)
    $form.Controls.Add($labelSize)

    $buttonCenter = New-Object System.Windows.Forms.Button
    $buttonCenter.Text = 'Center'
    $buttonCenter.Location = New-Object System.Drawing.Point(806, 238)
    $buttonCenter.Size = New-Object System.Drawing.Size(120, 28)
    $form.Controls.Add($buttonCenter)

    $buttonReset = New-Object System.Windows.Forms.Button
    $buttonReset.Text = 'Reset'
    $buttonReset.Location = New-Object System.Drawing.Point(806, 276)
    $buttonReset.Size = New-Object System.Drawing.Size(120, 28)
    $form.Controls.Add($buttonReset)

    $buttonOK = New-Object System.Windows.Forms.Button
    $buttonOK.Text = 'OK'
    $buttonOK.Location = New-Object System.Drawing.Point(734, 604)
    $buttonOK.Size = New-Object System.Drawing.Size(90, 28)
    $buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($buttonOK)

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.Location = New-Object System.Drawing.Point(836, 604)
    $buttonCancel.Size = New-Object System.Drawing.Size(90, 28)
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($buttonCancel)

    $form.AcceptButton = $buttonOK
    $form.CancelButton = $buttonCancel

    function Get-SelectedRatioMode {
        $selected = $radioButtons | Where-Object { $_.Checked } | Select-Object -First 1
        if ($selected) { return [string]$selected.Tag }
        return 'Free'
    }

    function Update-ImageBounds {
        $x = [Math]::Floor(($panel.ClientSize.Width - $previewBitmap.Width) / 2.0)
        $y = [Math]::Floor(($panel.ClientSize.Height - $previewBitmap.Height) / 2.0)
        $script:imageBounds = New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$previewBitmap.Width, [float]$previewBitmap.Height)
    }

    function Reset-CropRect {
        $mode = Get-SelectedRatioMode
        $ratio = Get-RatioValue -Mode $mode
        $margin = 0.08
        $w = $script:imageBounds.Width * (1.0 - ($margin * 2.0))
        $h = $script:imageBounds.Height * (1.0 - ($margin * 2.0))

        if ($null -ne $ratio) {
            if ($w / [double]$h -gt $ratio) {
                $w = $h * $ratio
            }
            else {
                $h = $w / $ratio
            }
        }

        $x = $script:imageBounds.X + (($script:imageBounds.Width - $w) / 2.0)
        $y = $script:imageBounds.Y + (($script:imageBounds.Height - $h) / 2.0)
        $script:cropRect = New-Object System.Drawing.RectangleF([float]$x, [float]$y, [float]$w, [float]$h)
    }

    function Center-CropRect {
        $script:cropRect.X = [float]($script:imageBounds.X + (($script:imageBounds.Width - $script:cropRect.Width) / 2.0))
        $script:cropRect.Y = [float]($script:imageBounds.Y + (($script:imageBounds.Height - $script:cropRect.Height) / 2.0))
        $mode = Get-SelectedRatioMode
        $script:cropRect = Clamp-CropRect -Rect $script:cropRect -Bounds $script:imageBounds -Ratio (Get-RatioValue -Mode $mode)
    }

    function Get-SourceCropRect {
        $scaleX = $SourceWidth / [double]$script:imageBounds.Width
        $scaleY = $SourceHeight / [double]$script:imageBounds.Height
        $x = [int][Math]::Round(($script:cropRect.X - $script:imageBounds.X) * $scaleX)
        $y = [int][Math]::Round(($script:cropRect.Y - $script:imageBounds.Y) * $scaleY)
        $w = [int][Math]::Round($script:cropRect.Width * $scaleX)
        $h = [int][Math]::Round($script:cropRect.Height * $scaleY)

        if ($x -lt 0) { $x = 0 }
        if ($y -lt 0) { $y = 0 }
        if ($x -ge $SourceWidth) { $x = $SourceWidth - 1 }
        if ($y -ge $SourceHeight) { $y = $SourceHeight - 1 }
        if ($x + $w -gt $SourceWidth) { $w = $SourceWidth - $x }
        if ($y + $h -gt $SourceHeight) { $h = $SourceHeight - $y }
        if ($w -lt 1) { $w = 1 }
        if ($h -lt 1) { $h = 1 }

        return [PSCustomObject]@{ X = $x; Y = $y; Width = $w; Height = $h }
    }

    function Update-SizeLabel {
        $r = Get-SourceCropRect
        $labelSize.Text = "Crop:`r`n$($r.Width) x $($r.Height) px"
    }

    function Get-HitMode {
        param([System.Drawing.PointF]$Point)

        $r = $script:cropRect
        $handle = 9.0
        $nearLeft = [Math]::Abs($Point.X - $r.Left) -le $handle
        $nearRight = [Math]::Abs($Point.X - $r.Right) -le $handle
        $nearTop = [Math]::Abs($Point.Y - $r.Top) -le $handle
        $nearBottom = [Math]::Abs($Point.Y - $r.Bottom) -le $handle

        if ($nearLeft -and $nearTop) { return 'tl' }
        if ($nearRight -and $nearTop) { return 'tr' }
        if ($nearLeft -and $nearBottom) { return 'bl' }
        if ($nearRight -and $nearBottom) { return 'br' }
        if ($r.Contains($Point)) { return 'move' }
        return ''
    }

    function Apply-RatioToCurrentCrop {
        $mode = Get-SelectedRatioMode
        $ratio = Get-RatioValue -Mode $mode
        $script:cropRect = Clamp-CropRect -Rect $script:cropRect -Bounds $script:imageBounds -Ratio $ratio
        Center-CropRect
        Update-SizeLabel
        $panel.Invalidate()
    }

    $panel.Add_Paint({
        param($sender, $e)

        $g = $e.Graphics
        $g.Clear($panel.BackColor)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($previewBitmap, $script:imageBounds)

        $overlayBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120, 0, 0, 0))
        try {
            $outer = New-Object System.Drawing.Region($script:imageBounds)
            $outer.Exclude($script:cropRect)
            $g.FillRegion($overlayBrush, $outer)
            $outer.Dispose()
        }
        finally {
            $overlayBrush.Dispose()
        }

        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)
        $accentPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(32, 145, 255), 1)
        $handleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        try {
            $g.DrawRectangle($pen, [int]$script:cropRect.X, [int]$script:cropRect.Y, [int]$script:cropRect.Width, [int]$script:cropRect.Height)
            $thirdW = $script:cropRect.Width / 3.0
            $thirdH = $script:cropRect.Height / 3.0
            $g.DrawLine($accentPen, [float]($script:cropRect.X + $thirdW), $script:cropRect.Top, [float]($script:cropRect.X + $thirdW), $script:cropRect.Bottom)
            $g.DrawLine($accentPen, [float]($script:cropRect.X + ($thirdW * 2.0)), $script:cropRect.Top, [float]($script:cropRect.X + ($thirdW * 2.0)), $script:cropRect.Bottom)
            $g.DrawLine($accentPen, $script:cropRect.Left, [float]($script:cropRect.Y + $thirdH), $script:cropRect.Right, [float]($script:cropRect.Y + $thirdH))
            $g.DrawLine($accentPen, $script:cropRect.Left, [float]($script:cropRect.Y + ($thirdH * 2.0)), $script:cropRect.Right, [float]($script:cropRect.Y + ($thirdH * 2.0)))

            foreach ($pt in @(
                @{ X = $script:cropRect.Left; Y = $script:cropRect.Top },
                @{ X = $script:cropRect.Right; Y = $script:cropRect.Top },
                @{ X = $script:cropRect.Left; Y = $script:cropRect.Bottom },
                @{ X = $script:cropRect.Right; Y = $script:cropRect.Bottom }
            )) {
                $g.FillRectangle($handleBrush, [float]($pt.X - 4), [float]($pt.Y - 4), 8, 8)
            }
        }
        finally {
            $pen.Dispose()
            $accentPen.Dispose()
            $handleBrush.Dispose()
        }
    })

    $panel.Add_MouseDown({
        param($sender, $e)
        if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
        $p = New-Object System.Drawing.PointF([float]$e.X, [float]$e.Y)
        $script:dragMode = Get-HitMode -Point $p
        if ($script:dragMode -eq '') { return }
        $script:dragStart = $p
        $script:dragRect = $script:cropRect
    })

    $panel.Add_MouseMove({
        param($sender, $e)
        $p = New-Object System.Drawing.PointF([float]$e.X, [float]$e.Y)
        if ($script:dragMode -eq '') {
            $hit = Get-HitMode -Point $p
            if ($hit -eq 'move') {
                $panel.Cursor = [System.Windows.Forms.Cursors]::SizeAll
            }
            elseif ($hit -in @('tl', 'br')) {
                $panel.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
            }
            elseif ($hit -in @('tr', 'bl')) {
                $panel.Cursor = [System.Windows.Forms.Cursors]::SizeNESW
            }
            else {
                $panel.Cursor = [System.Windows.Forms.Cursors]::Default
            }
            return
        }

        $dx = $p.X - $script:dragStart.X
        $dy = $p.Y - $script:dragStart.Y
        $r = New-Object System.Drawing.RectangleF($script:dragRect.X, $script:dragRect.Y, $script:dragRect.Width, $script:dragRect.Height)

        if ($script:dragMode -eq 'move') {
            $r.X = [float]($script:dragRect.X + $dx)
            $r.Y = [float]($script:dragRect.Y + $dy)
        }
        else {
            if ($script:dragMode.Contains('l')) {
                $r.X = [float]($script:dragRect.X + $dx)
                $r.Width = [float]($script:dragRect.Width - $dx)
            }
            if ($script:dragMode.Contains('r')) {
                $r.Width = [float]($script:dragRect.Width + $dx)
            }
            if ($script:dragMode.Contains('t')) {
                $r.Y = [float]($script:dragRect.Y + $dy)
                $r.Height = [float]($script:dragRect.Height - $dy)
            }
            if ($script:dragMode.Contains('b')) {
                $r.Height = [float]($script:dragRect.Height + $dy)
            }
        }

        $ratio = Get-RatioValue -Mode (Get-SelectedRatioMode)
        $script:cropRect = Clamp-CropRect -Rect $r -Bounds $script:imageBounds -Ratio $ratio
        Update-SizeLabel
        $panel.Invalidate()
    })

    $panel.Add_MouseUp({
        $script:dragMode = ''
    })

    foreach ($radio in $radioButtons) {
        $radio.Add_CheckedChanged({
            param($sender, $e)
            if ($sender.Checked) { Apply-RatioToCurrentCrop }
        })
    }

    $buttonCenter.Add_Click({
        Center-CropRect
        Update-SizeLabel
        $panel.Invalidate()
    })

    $buttonReset.Add_Click({
        Reset-CropRect
        Update-SizeLabel
        $panel.Invalidate()
    })

    Update-ImageBounds
    Reset-CropRect
    Update-SizeLabel

    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        $previewBitmap.Dispose()
        $form.Dispose()
        return $null
    }

    $sourceCrop = Get-SourceCropRect
    $previewBitmap.Dispose()
    $form.Dispose()
    return $sourceCrop
}

function New-FFmpegArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)][string]$Extension,
        [Parameter(Mandatory = $true)][int]$X,
        [Parameter(Mandatory = $true)][int]$Y,
        [Parameter(Mandatory = $true)][int]$Width,
        [Parameter(Mandatory = $true)][int]$Height
    )

    $cropFilter = 'crop={0}:{1}:{2}:{3}' -f $Width, $Height, $X, $Y
    $args = @(
        '-hide_banner',
        '-loglevel', 'error',
        '-y',
        '-i', $InputFile,
        '-frames:v', '1',
        '-vf', $cropFilter
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

    $info = Get-ImageInfo -Path $InputFile
    $crop = Show-CropWindow -ImagePath $InputFile -SourceWidth $info.Width -SourceHeight $info.Height
    if ($null -eq $crop) {
        exit 0
    }

    $inputDir = Split-Path -Parent $InputFile
    $inputBase = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $desiredOutput = Join-Path $inputDir ($inputBase + '_crop' + $sourceExtension)
    $script:OutputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

    $ffmpegArgs = New-FFmpegArguments -InputFile $InputFile -OutputFile $script:OutputFile -Extension $sourceExtension -X $crop.X -Y $crop.Y -Width $crop.Width -Height $crop.Height
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
    if ([string]::IsNullOrWhiteSpace($message)) { $message = 'Unknown image crop error.' }
    Show-Error $message
    exit 1
}
