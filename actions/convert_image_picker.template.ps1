param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

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

function Get-ActionPath([string]$ActionName) {
    $appRoot = Get-AppRoot
    return Join-Path $appRoot ("actions\{0}" -f $ActionName)
}

#__FFCOMMON_INJECT_HERE__


try {
    if ([string]::IsNullOrWhiteSpace($InputFile)) {
        Show-Error 'Input file is missing.'
        exit 1
    }

    $fullInputPath = [System.IO.Path]::GetFullPath($InputFile)
    if (-not (Test-Path -LiteralPath $fullInputPath)) {
        Show-Error "Input file not found:`r`n$fullInputPath"
        exit 1
    }

    $sourceExtension = [System.IO.Path]::GetExtension($fullInputPath).ToLowerInvariant()
    $targetsBySource = @{
        '.png'  = @('jpg', 'webp', 'bmp')
        '.jpg'  = @('png', 'webp', 'bmp')
        '.jpeg' = @('png', 'webp', 'bmp')
        '.webp' = @('png', 'jpg', 'bmp')
        '.bmp'  = @('png', 'jpg', 'webp')
    }

    if (-not $targetsBySource.ContainsKey($sourceExtension)) {
        Show-Error 'Unsupported input format. Only .png, .jpg, .jpeg, .webp and .bmp are supported.'
        exit 1
    }

    $selectedTarget = Show-FormatPicker `
        -Formats $targetsBySource[$sourceExtension] `
        -Title 'FFActions - Convert Image' `
        -LabelText ("Choose the output format for this {0} image." -f $sourceExtension.TrimStart('.').ToUpperInvariant())
    if ([string]::IsNullOrWhiteSpace($selectedTarget)) {
        exit 0
    }

    $targetExe = Get-ActionPath ("convert_image_to_{0}.exe" -f $selectedTarget.ToLowerInvariant())
    if (-not (Test-Path -LiteralPath $targetExe)) {
        Show-Error "Conversion action not found:`r`n$targetExe"
        exit 1
    }

    $process = Start-ActionProcess -ExePath $targetExe -FilePath $fullInputPath
    if ($null -eq $process) {
        Show-Error 'Unable to start image conversion.'
        exit 1
    }

    exit 0
}
catch {
    $message = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($message)) { $message = 'Unknown image conversion launcher error.' }
    Show-Error $message
    exit 1
}
