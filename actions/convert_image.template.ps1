param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-Error([string]$Message) {
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        "FFActions - Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function Get-TargetFormatFromExeName {
    $exeName = [System.IO.Path]::GetFileNameWithoutExtension([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)

    switch ($exeName.ToLowerInvariant()) {
        'convert_image_to_png'  { return '.png' }
        'convert_image_to_jpg'  { return '.jpg' }
        'convert_image_to_webp' { return '.webp' }
        'convert_image_to_bmp'  { return '.bmp' }
        default { throw 'Unknown conversion target. Expected convert_image_to_png.exe, convert_image_to_jpg.exe, convert_image_to_webp.exe or convert_image_to_bmp.exe.' }
    }
}

function New-FFmpegArguments {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [Parameter(Mandatory = $true)][string]$TargetExtension
    )

    $args = @(
        '-hide_banner',
        '-loglevel', 'error',
        '-y',
        '-i', $InputFile,
        '-frames:v', '1'
    )

    switch ($TargetExtension.ToLowerInvariant()) {
        '.png' {
            $args += @('-compression_level', '6')
        }
        '.jpg' {
            $args += @('-q:v', '2')
        }
        '.webp' {
            $args += @('-c:v', 'libwebp', '-quality', '90', '-compression_level', '4')
        }
        '.bmp' {
        }
        default {
            throw 'Unsupported target format. Only .png, .jpg, .webp and .bmp are supported.'
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

    $targetExtension = Get-TargetFormatFromExeName
    if ($targetExtension -eq '.jpg' -and $sourceExtension -eq '.jpeg') {
        Show-Error 'Source and target formats must be different.'
        exit 1
    }
    if ($targetExtension -eq $sourceExtension) {
        Show-Error 'Source and target formats must be different.'
        exit 1
    }

    $ffmpeg = Get-ToolPath 'ffmpeg.exe'
    if (-not (Test-Path -LiteralPath $ffmpeg)) {
        Show-Error 'ffmpeg.exe not found.'
        exit 1
    }

    $inputDir = Split-Path -Parent $InputFile
    $inputBase = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $targetLabel = $targetExtension.TrimStart('.')
    $desiredOutput = Join-Path $inputDir ("{0}_convert_{1}{2}" -f $inputBase, $targetLabel, $targetExtension)
    $script:OutputFile = Get-UniqueOutputPath -DesiredPath $desiredOutput

    $ffmpegArgs = New-FFmpegArguments -InputFile $InputFile -OutputFile $script:OutputFile -TargetExtension $targetExtension
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
    if ([string]::IsNullOrWhiteSpace($message)) { $message = 'Unknown image conversion error.' }
    Show-Error $message
    exit 1
}
