param(
    [string]$InstallRoot = 'C:\Program Files\FFActions',
    [switch]$AllUsers
)

$ErrorActionPreference = 'Stop'

function Remove-RegistryTree {
    param(
        [Parameter(Mandatory = $true)][Microsoft.Win32.RegistryKey]$Hive,
        [Parameter(Mandatory = $true)][string]$KeyPath
    )

    try {
        $Hive.DeleteSubKeyTree($KeyPath, $false)
    }
    catch {}
}

function Set-RegistryValue {
    param(
        [Parameter(Mandatory = $true)][Microsoft.Win32.RegistryKey]$Hive,
        [Parameter(Mandatory = $true)][string]$KeyPath,
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowEmptyString()]
        [Parameter(Mandatory = $true)][string]$Value
    )

    $key = $Hive.CreateSubKey($KeyPath)
    try {
        $key.SetValue($Name, $Value, [Microsoft.Win32.RegistryValueKind]::String)
    }
    finally {
        if ($key) { $key.Dispose() }
    }
}

function Set-DefaultRegistryValue {
    param(
        [Parameter(Mandatory = $true)][Microsoft.Win32.RegistryKey]$Hive,
        [Parameter(Mandatory = $true)][string]$KeyPath,
        [AllowEmptyString()]
        [Parameter(Mandatory = $true)][string]$Value
    )

    $key = $Hive.CreateSubKey($KeyPath)
    try {
        $key.SetValue('', $Value, [Microsoft.Win32.RegistryValueKind]::String)
    }
    finally {
        if ($key) { $key.Dispose() }
    }
}

$audioPicker = Join-Path $InstallRoot 'actions\convert_audio_picker.exe'
$imagePicker = Join-Path $InstallRoot 'actions\convert_image_picker.exe'
$hasAudioPicker = Test-Path -LiteralPath $audioPicker
$hasImagePicker = Test-Path -LiteralPath $imagePicker

if (-not $hasAudioPicker -and -not $hasImagePicker) {
    throw "No convert picker executable was found under $InstallRoot\actions."
}

$hives = New-Object System.Collections.Generic.List[Microsoft.Win32.RegistryKey]
[void]$hives.Add([Microsoft.Win32.Registry]::CurrentUser)

if ($AllUsers) {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        throw 'The -AllUsers option requires running PowerShell as Administrator.'
    }
    [void]$hives.Add([Microsoft.Win32.Registry]::LocalMachine)
}

$audioExtensions = @('.wav', '.mp3', '.flac', '.m4a', '.ogg')
$imageExtensions = @('.png', '.jpg', '.jpeg', '.bmp', '.webp')

foreach ($hive in $hives) {
    if ($hasAudioPicker) {
        foreach ($ext in $audioExtensions) {
            $convertKey = "Software\Classes\SystemFileAssociations\$ext\shell\FFActions\shell\convert"
            Remove-RegistryTree -Hive $hive -KeyPath $convertKey
            Set-RegistryValue -Hive $hive -KeyPath $convertKey -Name 'MUIVerb' -Value 'convert'
            Set-DefaultRegistryValue -Hive $hive -KeyPath "$convertKey\command" -Value ('"{0}" "%1"' -f $audioPicker)
        }
    }

    if ($hasImagePicker) {
        foreach ($ext in $imageExtensions) {
            $convertKey = "Software\Classes\SystemFileAssociations\$ext\shell\FFActions\shell\convert"
            Remove-RegistryTree -Hive $hive -KeyPath $convertKey
            Set-RegistryValue -Hive $hive -KeyPath $convertKey -Name 'MUIVerb' -Value 'convert'
            Set-DefaultRegistryValue -Hive $hive -KeyPath "$convertKey\command" -Value ('"{0}" "%1"' -f $imagePicker)
        }
    }
}

if ($AllUsers) {
    Write-Host 'audio and image convert menus repaired for current user and all users.'
}
else {
    Write-Host 'audio and image convert menus repaired for current user.'
}
