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

    return 'FFmpeg failed during image transform.'
}

function Get-TransformConfig {
    param([string]$Key)

    switch ($Key) {
        'rotate90' {
            return [PSCustomObject]@{ Filter = 'transpose=1'; Label = 'rotate90' }
        }
        'rotate180' {
            return [PSCustomObject]@{ Filter = 'transpose=1,transpose=1'; Label = 'rotate180' }
        }
        'rotate270' {
            return [PSCustomObject]@{ Filter = 'transpose=2'; Label = 'rotate270' }
        }
        'flip_h' {
            return [PSCustomObject]@{ Filter = 'hflip'; Label = 'flipH' }
        }
        'flip_v' {
            return [PSCustomObject]@{ Filter = 'vflip'; Label = 'flipV' }
        }
        default {
            throw 'Unknown image transform.'
        }
    }
}

function Show-FlipWindow {
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'FFActions - Rotate / flip image'
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(420, 290)
    $form.TopMost = $true

    $labelTitle = New-Object System.Windows.Forms.Label
    $labelTitle.Location = New-Object System.Drawing.Point(20, 18)
    $labelTitle.Size = New-Object System.Drawing.Size(360, 22)
    $labelTitle.Text = 'Choose the transform to apply'
    $form.Controls.Add($labelTitle)

    $group = New-Object System.Windows.Forms.GroupBox
    $group.Text = 'Transform'
    $group.Location = New-Object System.Drawing.Point(18, 48)
    $group.Size = New-Object System.Drawing.Size(384, 180)
    $form.Controls.Add($group)

    $options = @(
        @{ Key = 'rotate90';  Text = 'Rotate 90° clockwise';   X = 18;  Y = 28 },
        @{ Key = 'rotate180'; Text = 'Rotate 180°';            X = 18;  Y = 58 },
        @{ Key = 'rotate270'; Text = 'Rotate 270° clockwise';  X = 18;  Y = 88 },
        @{ Key = 'flip_h';    Text = 'Mirror horizontal';      X = 18;  Y = 128 },
        @{ Key = 'flip_v';    Text = 'Mirror vertical';        X = 200; Y = 128 }
    )

    $radioButtons = @()
    foreach ($item in $options) {
        $radio = New-Object System.Windows.Forms.RadioButton
        $radio.Text = $item.Text
        $radio.Tag = $item.Key
        $radio.Location = New-Object System.Drawing.Point($item.X, $item.Y)
        $radio.Size = New-Object System.Drawing.Size(170, 24)
        if ($item.Key -eq 'rotate90') { $radio.Checked = $true }
        $group.Controls.Add($radio)
        $radioButtons += $radio
    }

    $labelHint = New-Object System.Windows.Forms.Label
    $labelHint.Location = New-Object System.Drawing.Point(20, 236)
    $labelHint.Size = New-Object System.Drawing.Size(360, 18)
    $labelHint.Text = 'The transformed image will be created next to the original file.'
    $form.Controls.Add($labelHint)

    $buttonOK = New-Object System.Windows.Forms.Button
    $buttonOK.Text = 'OK'
    $buttonOK.Location = New-Object System.Drawing.Point(206, 256)
    $buttonOK.Size = New-Object System.Drawing.Size(90, 28)
    $buttonOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($buttonOK)

    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.Location = New-Object System.Drawing.Point(308, 256)
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

    $selected = $radioButtons | Where-Object { $_.Checked } | Select-Object -First 1
    if ($null -eq $selected) {
        $form.Dispose()
        Show-Error 'No transform selected.'
        exit 1
    }

    $payload = Get-TransformConfig -Key ([string]$selected.Tag)
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

    $transform = Show-FlipWindow
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
