param(
    [string]$InstallRoot = 'C:\Program Files\FFActions',
    [switch]$AllUsers,
    [switch]$ResetExisting
)

$ErrorActionPreference = 'Stop'

$extensions = @('.mp4', '.mkv', '.avi', '.mov', '.webm', '.m4v')
$iconPath = Join-Path $InstallRoot 'tools\icons\ffactions.ico'

function Ensure-FileExists {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required file not found: $Path"
    }
}

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

$hives = New-Object System.Collections.Generic.List[Microsoft.Win32.RegistryKey]
[void]$hives.Add([Microsoft.Win32.Registry]::CurrentUser)

if ($AllUsers) {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        throw 'The -AllUsers option requires running PowerShell as Administrator.'
    }
    [void]$hives.Add([Microsoft.Win32.Registry]::LocalMachine)
}

$requiredFiles = @(
    (Join-Path $InstallRoot 'actions\cut_by_frame.exe'),
    (Join-Path $InstallRoot 'actions\cut_by_time.exe'),
    (Join-Path $InstallRoot 'actions\interpolate.exe'),
    (Join-Path $InstallRoot 'actions\remove_audio.exe'),
    (Join-Path $InstallRoot 'actions\extract_audio_picker.exe'),
    (Join-Path $InstallRoot 'actions\extract_audio_to_mp3.exe'),
    (Join-Path $InstallRoot 'actions\extract_audio_to_wav.exe'),
    (Join-Path $InstallRoot 'actions\extract_audio_to_flac.exe'),
    (Join-Path $InstallRoot 'actions\extract_audio_to_m4a.exe'),
    (Join-Path $InstallRoot 'actions\extract_audio_to_ogg.exe'),
    (Join-Path $InstallRoot 'actions\create_gif.exe'),
    (Join-Path $InstallRoot 'actions\convert_video_picker.exe'),
    (Join-Path $InstallRoot 'actions\resize_video.exe'),
    (Join-Path $InstallRoot 'actions\crop_video.exe'),
    (Join-Path $InstallRoot 'actions\rotate_video.exe'),
    (Join-Path $InstallRoot 'actions\compress_video.exe'),
    (Join-Path $InstallRoot 'actions\convert_to_mp4.exe'),
    (Join-Path $InstallRoot 'actions\convert_to_mkv.exe'),
    (Join-Path $InstallRoot 'actions\convert_to_avi.exe'),
    (Join-Path $InstallRoot 'actions\convert_to_mov.exe'),
    (Join-Path $InstallRoot 'actions\convert_to_webm.exe'),
    (Join-Path $InstallRoot 'actions\convert_to_m4v.exe')
)

foreach ($file in $requiredFiles) {
    Ensure-FileExists -Path $file
}

$extractTargets = @('mp3', 'wav', 'flac', 'm4a', 'ogg')
$convertTargetsByExtension = @{
    '.mp4'  = @('mkv', 'avi', 'mov', 'webm', 'm4v')
    '.mkv'  = @('mp4', 'avi', 'mov', 'webm', 'm4v')
    '.avi'  = @('mp4', 'mkv', 'mov', 'webm', 'm4v')
    '.mov'  = @('mp4', 'mkv', 'avi', 'webm', 'm4v')
    '.webm' = @('mp4', 'mkv', 'avi', 'mov', 'm4v')
    '.m4v'  = @('mp4', 'mkv', 'avi', 'mov', 'webm')
}

foreach ($ext in $extensions) {
    $rootKey = "Software\Classes\SystemFileAssociations\$ext\shell\FFActions"
    $rootShell = "$rootKey\shell"

    if ($ResetExisting) {
        Remove-RegistryTree -Hive ([Microsoft.Win32.Registry]::CurrentUser) -KeyPath $rootKey
        if ($AllUsers) {
            Remove-RegistryTree -Hive ([Microsoft.Win32.Registry]::LocalMachine) -KeyPath $rootKey
        }
    }

    foreach ($hive in $hives) {
        Set-RegistryValue -Hive $hive -KeyPath $rootKey -Name 'MUIVerb' -Value 'ffmpg'
        Set-RegistryValue -Hive $hive -KeyPath $rootKey -Name 'SubCommands' -Value ''
        if (Test-Path -LiteralPath $iconPath) {
            Set-RegistryValue -Hive $hive -KeyPath $rootKey -Name 'Icon' -Value $iconPath
        }

        Set-RegistryValue -Hive $hive -KeyPath "$rootShell\a_convert_video" -Name 'MUIVerb' -Value 'convert'
        Set-DefaultRegistryValue -Hive $hive -KeyPath "$rootShell\a_convert_video\command" -Value ('"{0}" "%1"' -f (Join-Path $InstallRoot 'actions\convert_video_picker.exe'))

        Set-RegistryValue -Hive $hive -KeyPath "$rootShell\b_resize_video" -Name 'MUIVerb' -Value 'resize video'
        Set-DefaultRegistryValue -Hive $hive -KeyPath "$rootShell\b_resize_video\command" -Value ('"{0}" "%1"' -f (Join-Path $InstallRoot 'actions\resize_video.exe'))

        Set-RegistryValue -Hive $hive -KeyPath "$rootShell\c_cut_by_frame" -Name 'MUIVerb' -Value 'cut by frame'
        Set-DefaultRegistryValue -Hive $hive -KeyPath "$rootShell\c_cut_by_frame\command" -Value ('"{0}" "%1"' -f (Join-Path $InstallRoot 'actions\cut_by_frame.exe'))

        Set-RegistryValue -Hive $hive -KeyPath "$rootShell\d_cut_by_time" -Name 'MUIVerb' -Value 'cut by time'
        Set-DefaultRegistryValue -Hive $hive -KeyPath "$rootShell\d_cut_by_time\command" -Value ('"{0}" "%1"' -f (Join-Path $InstallRoot 'actions\cut_by_time.exe'))

        Set-RegistryValue -Hive $hive -KeyPath "$rootShell\e_interpolate" -Name 'MUIVerb' -Value 'interpolate'
        Set-DefaultRegistryValue -Hive $hive -KeyPath "$rootShell\e_interpolate\command" -Value ('"{0}" "%1"' -f (Join-Path $InstallRoot 'actions\interpolate.exe'))

        Set-RegistryValue -Hive $hive -KeyPath "$rootShell\f_remove_audio" -Name 'MUIVerb' -Value 'remove audio'
        Set-DefaultRegistryValue -Hive $hive -KeyPath "$rootShell\f_remove_audio\command" -Value ('"{0}" "%1"' -f (Join-Path $InstallRoot 'actions\remove_audio.exe'))

        Set-RegistryValue -Hive $hive -KeyPath "$rootShell\g_extract_audio" -Name 'MUIVerb' -Value 'extract audio'
        Set-DefaultRegistryValue -Hive $hive -KeyPath "$rootShell\g_extract_audio\command" -Value ('"{0}" "%1"' -f (Join-Path $InstallRoot 'actions\extract_audio_picker.exe'))

        Set-RegistryValue -Hive $hive -KeyPath "$rootShell\h_create_gif" -Name 'MUIVerb' -Value 'create gif'
        Set-DefaultRegistryValue -Hive $hive -KeyPath "$rootShell\h_create_gif\command" -Value ('"{0}" "%1"' -f (Join-Path $InstallRoot 'actions\create_gif.exe'))

        Set-RegistryValue -Hive $hive -KeyPath "$rootShell\i_crop_video" -Name 'MUIVerb' -Value 'crop video'
        Set-DefaultRegistryValue -Hive $hive -KeyPath "$rootShell\i_crop_video\command" -Value ('"{0}" "%1"' -f (Join-Path $InstallRoot 'actions\crop_video.exe'))

        Set-RegistryValue -Hive $hive -KeyPath "$rootShell\j_rotate_video" -Name 'MUIVerb' -Value 'rotate / flip'
        Set-DefaultRegistryValue -Hive $hive -KeyPath "$rootShell\j_rotate_video\command" -Value ('"{0}" "%1"' -f (Join-Path $InstallRoot 'actions\rotate_video.exe'))

        Set-RegistryValue -Hive $hive -KeyPath "$rootShell\k_compress_video" -Name 'MUIVerb' -Value 'compress video'
        Set-DefaultRegistryValue -Hive $hive -KeyPath "$rootShell\k_compress_video\command" -Value ('"{0}" "%1"' -f (Join-Path $InstallRoot 'actions\compress_video.exe'))
    }
}

if ($AllUsers) {
    if ($ResetExisting) {
        Write-Host 'video menus reset and repaired for current user and all users.'
    }
    else {
        Write-Host 'video menus repaired for current user and all users.'
    }
}
else {
    if ($ResetExisting) {
        Write-Host 'video menus reset and repaired for current user.'
    }
    else {
        Write-Host 'video menus repaired for current user.'
    }
}
