param(
    [string]$Version = '1.4.1',
    [string]$Company = 'FFActions contributors',
    [string]$Product = 'FFActions'
)

$ErrorActionPreference = 'Stop'
$ConfirmPreference = 'None'
$ProgressPreference = 'SilentlyContinue'
$InformationPreference = 'Continue'

# Force non-interactive behavior for common cmdlets.
# This avoids per-file confirmations during rebuild.
$PSDefaultParameterValues['*:Confirm'] = $false


$repoRoot = $PSScriptRoot
$base = Join-Path $repoRoot 'actions'
$sharedOrder = @(
    [PSCustomObject]@{ Name = 'core';     Path = Join-Path $base '_shared\ffcommon_core.ps1' }
    [PSCustomObject]@{ Name = 'media';    Path = Join-Path $base '_shared\ffcommon_media.ps1' }
    [PSCustomObject]@{ Name = 'pdf';      Path = Join-Path $base '_shared\ffcommon_pdf.ps1' }
    [PSCustomObject]@{ Name = 'progress'; Path = Join-Path $base '_shared\ffcommon_progress.ps1' }
    [PSCustomObject]@{ Name = 'picker';   Path = Join-Path $base '_shared\ffcommon_picker.ps1' }
)
$builder = Join-Path $base 'build_ffaction.ps1'
$iconFile = Join-Path $repoRoot 'tools\icons\ffactions.ico'
$copyright = "Copyright (c) 2026 $Company"

function Resolve-SharedFiles {
    param(
        [string[]]$SharedNames = @('core', 'progress')
    )

    $requested = @{}
    foreach ($name in $SharedNames) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        $requested[$name.ToLowerInvariant()] = $true
    }

    $files = New-Object System.Collections.Generic.List[string]
    foreach ($shared in $sharedOrder) {
        if (-not $requested.ContainsKey($shared.Name)) {
            continue
        }

        if (Test-Path -LiteralPath $shared.Path) {
            $files.Add($shared.Path)
        }
    }

    return ,$files.ToArray()
}

function Remove-BuildOutputFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    try {
        # Clear read-only flag if present, then delete without prompting.
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        if ($item.Attributes -band [System.IO.FileAttributes]::ReadOnly) {
            $item.Attributes = ($item.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly))
        }

        Remove-Item -LiteralPath $Path -Force -Confirm:$false -ErrorAction Stop
    }
    catch {
        throw "Unable to remove existing build output: $Path`n$($_.Exception.Message)"
    }

    if (Test-Path -LiteralPath $Path) {
        throw "Existing build output was not removed: $Path"
    }
}

function Invoke-GeneratedScriptBuild {
    param(
        [Parameter(Mandatory = $true)][string]$TemplateFile,
        [Parameter(Mandatory = $true)][string]$OutputPs1,
        [string[]]$SharedNames = @('core', 'progress')
    )

    $outputDir = Split-Path -Parent $OutputPs1
    if (-not (Test-Path -LiteralPath $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    Remove-BuildOutputFile -Path $OutputPs1

    $sharedFiles = Resolve-SharedFiles -SharedNames $SharedNames

    & $builder `
        -SharedFile $sharedFiles `
        -TemplateFile $TemplateFile `
        -OutputFile $OutputPs1
}

function Invoke-ExeBuild {
    param(
        [Parameter(Mandatory = $true)][string]$InputFile,
        [Parameter(Mandatory = $true)][string]$OutputFile,
        [string]$Title
    )

    $ps2exeParams = @{
        inputFile   = $InputFile
        outputFile  = $OutputFile
        noConsole   = $true
        STA         = $true
        product     = $Product
        company     = $Company
        copyright   = $copyright
        version     = $Version
        title       = $(if ($Title) { $Title } else { [System.IO.Path]::GetFileNameWithoutExtension($OutputFile) })
        description = 'FFActions multimedia right-click tool'
    }

    if (Test-Path -LiteralPath $iconFile) {
        $ps2exeParams.iconFile = $iconFile
    }

    $outputDir = Split-Path -Parent $OutputFile
    if (-not (Test-Path -LiteralPath $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    Remove-BuildOutputFile -Path $OutputFile

    Invoke-PS2EXE @ps2exeParams -ErrorAction Stop
}

function Build-Action {
    param(
        [Parameter(Mandatory = $true)][string]$TemplateFile,
        [Parameter(Mandatory = $true)][string]$OutputPs1,
        [Parameter(Mandatory = $true)][string]$OutputExe,
        [string]$Title,
        [string[]]$SharedNames = @('core', 'progress')
    )

    Invoke-GeneratedScriptBuild -TemplateFile $TemplateFile -OutputPs1 $OutputPs1 -SharedNames $SharedNames
    Invoke-ExeBuild -InputFile $OutputPs1 -OutputFile $OutputExe -Title $Title
}

Build-Action `
    -TemplateFile (Join-Path $base 'cut_video.template.ps1') `
    -OutputPs1    (Join-Path $base 'cut_video.ps1') `
    -OutputExe    (Join-Path $base 'cut_video.exe') `
    -Title        'FFActions - Cut Video'

Build-Action `
    -TemplateFile (Join-Path $base 'interpolate.template.ps1') `
    -OutputPs1    (Join-Path $base 'interpolate.ps1') `
    -OutputExe    (Join-Path $base 'interpolate.exe') `
    -Title        'FFActions - Interpolate'

Build-Action `
    -TemplateFile (Join-Path $base 'create_gif.template.ps1') `
    -OutputPs1    (Join-Path $base 'create_gif.ps1') `
    -OutputExe    (Join-Path $base 'create_gif.exe') `
    -Title        'FFActions - Create GIF'

Build-Action `
    -TemplateFile (Join-Path $base 'convert_video_picker.template.ps1') `
    -OutputPs1    (Join-Path $base 'convert_video_picker.ps1') `
    -OutputExe    (Join-Path $base 'convert_video_picker.exe') `
    -Title        'FFActions - Convert Video' `
    -SharedNames  @('picker')

Build-Action `
    -TemplateFile (Join-Path $base 'resize_video.template.ps1') `
    -OutputPs1    (Join-Path $base 'resize_video.ps1') `
    -OutputExe    (Join-Path $base 'resize_video.exe') `
    -Title        'FFActions - Resize Video'

Build-Action `
    -TemplateFile (Join-Path $base 'remove_audio.template.ps1') `
    -OutputPs1    (Join-Path $base 'remove_audio.ps1') `
    -OutputExe    (Join-Path $base 'remove_audio.exe') `
    -Title        'FFActions - Remove Audio' `
    -SharedNames  @('core', 'media', 'progress')

Build-Action `
    -TemplateFile (Join-Path $base 'extract_frames.template.ps1') `
    -OutputPs1    (Join-Path $base 'extract_frames.ps1') `
    -OutputExe    (Join-Path $base 'extract_frames.exe') `
    -Title        'FFActions - Extract Frames' `
    -SharedNames  @('core', 'media', 'progress')

Build-Action `
    -TemplateFile (Join-Path $base 'rotate_video.template.ps1') `
    -OutputPs1    (Join-Path $base 'rotate_video.ps1') `
    -OutputExe    (Join-Path $base 'rotate_video.exe') `
    -Title        'FFActions - Rotate or Flip Video' `
    -SharedNames  @('core', 'media', 'progress')

Build-Action `
    -TemplateFile (Join-Path $base 'compress_video.template.ps1') `
    -OutputPs1    (Join-Path $base 'compress_video.ps1') `
    -OutputExe    (Join-Path $base 'compress_video.exe') `
    -Title        'FFActions - Compress Video'

Build-Action `
    -TemplateFile (Join-Path $base 'change_video_speed.template.ps1') `
    -OutputPs1    (Join-Path $base 'change_video_speed.ps1') `
    -OutputExe    (Join-Path $base 'change_video_speed.exe') `
    -Title        'FFActions - Change Video Speed'

Build-Action `
    -TemplateFile (Join-Path $base 'cut_audio.template.ps1') `
    -OutputPs1    (Join-Path $base 'cut_audio.ps1') `
    -OutputExe    (Join-Path $base 'cut_audio.exe') `
    -Title        'FFActions - Cut Audio'

Build-Action `
    -TemplateFile (Join-Path $base 'change_audio_speed.template.ps1') `
    -OutputPs1    (Join-Path $base 'change_audio_speed.ps1') `
    -OutputExe    (Join-Path $base 'change_audio_speed.exe') `
    -Title        'FFActions - Change Audio Speed' `
    -SharedNames  @('core', 'media', 'progress')

Build-Action `
    -TemplateFile (Join-Path $base 'reverse_audio.template.ps1') `
    -OutputPs1    (Join-Path $base 'reverse_audio.ps1') `
    -OutputExe    (Join-Path $base 'reverse_audio.exe') `
    -Title        'FFActions - Reverse Audio' `
    -SharedNames  @('core', 'media', 'progress')

Build-Action `
    -TemplateFile (Join-Path $base 'compress_audio.template.ps1') `
    -OutputPs1    (Join-Path $base 'compress_audio.ps1') `
    -OutputExe    (Join-Path $base 'compress_audio.exe') `
    -Title        'FFActions - Compress Audio' `
    -SharedNames  @('core', 'media', 'progress')

Invoke-GeneratedScriptBuild `
    -TemplateFile (Join-Path $base 'change_audio_pitch.template.ps1') `
    -OutputPs1    (Join-Path $base 'change_audio_pitch.ps1') `
    -SharedNames  @('core', 'media', 'progress')

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'change_audio_pitch_launcher.ps1') `
    -OutputFile (Join-Path $base 'change_audio_pitch.exe') `
    -Title      'FFActions - Change Audio Pitch'

Invoke-GeneratedScriptBuild `
    -TemplateFile (Join-Path $base 'convert_audio.template.ps1') `
    -OutputPs1    (Join-Path $base 'convert_audio.ps1') `
    -SharedNames  @('core', 'media', 'progress')

Build-Action `
    -TemplateFile (Join-Path $base 'convert_audio_picker.template.ps1') `
    -OutputPs1    (Join-Path $base 'convert_audio_picker.ps1') `
    -OutputExe    (Join-Path $base 'convert_audio_picker.exe') `
    -Title        'FFActions - Convert Audio' `
    -SharedNames  @('picker')

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'convert_audio.ps1') `
    -OutputFile (Join-Path $base 'convert_audio_to_mp3.exe') `
    -Title      'FFActions - Convert Audio to MP3'

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'convert_audio.ps1') `
    -OutputFile (Join-Path $base 'convert_audio_to_wav.exe') `
    -Title      'FFActions - Convert Audio to WAV'

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'convert_audio.ps1') `
    -OutputFile (Join-Path $base 'convert_audio_to_flac.exe') `
    -Title      'FFActions - Convert Audio to FLAC'

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'convert_audio.ps1') `
    -OutputFile (Join-Path $base 'convert_audio_to_m4a.exe') `
    -Title      'FFActions - Convert Audio to M4A'

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'convert_audio.ps1') `
    -OutputFile (Join-Path $base 'convert_audio_to_ogg.exe') `
    -Title      'FFActions - Convert Audio to OGG'

Invoke-GeneratedScriptBuild `
    -TemplateFile (Join-Path $base 'extract_audio.template.ps1') `
    -OutputPs1    (Join-Path $base 'extract_audio.ps1') `
    -SharedNames  @('core', 'media', 'progress')

Build-Action `
    -TemplateFile (Join-Path $base 'extract_audio_picker.template.ps1') `
    -OutputPs1    (Join-Path $base 'extract_audio_picker.ps1') `
    -OutputExe    (Join-Path $base 'extract_audio_picker.exe') `
    -Title        'FFActions - Extract Audio' `
    -SharedNames  @('picker')

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'extract_audio.ps1') `
    -OutputFile (Join-Path $base 'extract_audio_to_mp3.exe') `
    -Title      'FFActions - Extract Audio to MP3'

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'extract_audio.ps1') `
    -OutputFile (Join-Path $base 'extract_audio_to_wav.exe') `
    -Title      'FFActions - Extract Audio to WAV'

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'extract_audio.ps1') `
    -OutputFile (Join-Path $base 'extract_audio_to_flac.exe') `
    -Title      'FFActions - Extract Audio to FLAC'

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'extract_audio.ps1') `
    -OutputFile (Join-Path $base 'extract_audio_to_m4a.exe') `
    -Title      'FFActions - Extract Audio to M4A'

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'extract_audio.ps1') `
    -OutputFile (Join-Path $base 'extract_audio_to_ogg.exe') `
    -Title      'FFActions - Extract Audio to OGG'

Invoke-GeneratedScriptBuild `
    -TemplateFile (Join-Path $base 'convert_image.template.ps1') `
    -OutputPs1    (Join-Path $base 'convert_image.ps1') `
    -SharedNames  @('core')

Build-Action `
    -TemplateFile (Join-Path $base 'image_to_pdf.template.ps1') `
    -OutputPs1    (Join-Path $base 'image_to_pdf.ps1') `
    -OutputExe    (Join-Path $base 'image_to_pdf.exe') `
    -Title        'FFActions - Image to PDF' `
    -SharedNames  @('core', 'pdf')

Build-Action `
    -TemplateFile (Join-Path $base 'convert_image_picker.template.ps1') `
    -OutputPs1    (Join-Path $base 'convert_image_picker.ps1') `
    -OutputExe    (Join-Path $base 'convert_image_picker.exe') `
    -Title        'FFActions - Convert Image' `
    -SharedNames  @('picker')

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'convert_image.ps1') `
    -OutputFile (Join-Path $base 'convert_image_to_png.exe') `
    -Title      'FFActions - Convert Image to PNG'

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'convert_image.ps1') `
    -OutputFile (Join-Path $base 'convert_image_to_jpg.exe') `
    -Title      'FFActions - Convert Image to JPG'

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'convert_image.ps1') `
    -OutputFile (Join-Path $base 'convert_image_to_webp.exe') `
    -Title      'FFActions - Convert Image to WEBP'

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'convert_image.ps1') `
    -OutputFile (Join-Path $base 'convert_image_to_bmp.exe') `
    -Title      'FFActions - Convert Image to BMP'

Build-Action `
    -TemplateFile (Join-Path $base 'compress_image.template.ps1') `
    -OutputPs1    (Join-Path $base 'compress_image.ps1') `
    -OutputExe    (Join-Path $base 'compress_image.exe') `
    -Title        'FFActions - Compress Image'

Build-Action `
    -TemplateFile (Join-Path $base 'flip_image.template.ps1') `
    -OutputPs1    (Join-Path $base 'flip_image.ps1') `
    -OutputExe    (Join-Path $base 'flip_image.exe') `
    -Title        'FFActions - Rotate or Flip Image'

Build-Action `
    -TemplateFile (Join-Path $base 'crop_image.template.ps1') `
    -OutputPs1    (Join-Path $base 'crop_image.ps1') `
    -OutputExe    (Join-Path $base 'crop_image.exe') `
    -Title        'FFActions - Crop Image'

Invoke-GeneratedScriptBuild `
    -TemplateFile (Join-Path $base 'resize_image.template.ps1') `
    -OutputPs1    (Join-Path $base 'resize_image.ps1') `
    -SharedNames  @()

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'resize_image.ps1') `
    -OutputFile (Join-Path $base 'resize_image.exe') `
    -Title      'FFActions - Resize Image'

Build-Action `
    -TemplateFile (Join-Path $base 'crop_video.template.ps1') `
    -OutputPs1    (Join-Path $base 'crop_video.ps1') `
    -OutputExe    (Join-Path $base 'crop_video.exe') `
    -Title        'FFActions - Crop Video'

Build-Action `
    -TemplateFile (Join-Path $base 'convert_icon.template.ps1') `
    -OutputPs1    (Join-Path $base 'convert_icon.ps1') `
    -OutputExe    (Join-Path $base 'convert_icon.exe') `
    -Title        'FFActions - Convert to Icon'

Invoke-GeneratedScriptBuild `
    -TemplateFile (Join-Path $base 'convert_video.template.ps1') `
    -OutputPs1    (Join-Path $base 'convert_video.ps1') `
    -SharedNames  @('core', 'media', 'progress')

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'convert_video.ps1') `
    -OutputFile (Join-Path $base 'convert_to_mp4.exe') `
    -Title      'FFActions - Convert Video to MP4'

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'convert_video.ps1') `
    -OutputFile (Join-Path $base 'convert_to_mkv.exe') `
    -Title      'FFActions - Convert Video to MKV'

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'convert_video.ps1') `
    -OutputFile (Join-Path $base 'convert_to_avi.exe') `
    -Title      'FFActions - Convert Video to AVI'

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'convert_video.ps1') `
    -OutputFile (Join-Path $base 'convert_to_mov.exe') `
    -Title      'FFActions - Convert Video to MOV'

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'convert_video.ps1') `
    -OutputFile (Join-Path $base 'convert_to_webm.exe') `
    -Title      'FFActions - Convert Video to WEBM'

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'convert_video.ps1') `
    -OutputFile (Join-Path $base 'convert_to_m4v.exe') `
    -Title      'FFActions - Convert Video to M4V'

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'media_info.ps1') `
    -OutputFile (Join-Path $base 'media_info.exe') `
    -Title      'FFActions - Media Info'

Write-Host ''
Write-Host "Build complete. Version: $Version"
