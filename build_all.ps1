param(
    [string]$Version = '1.0.0',
    [string]$Company = 'FFActions contributors',
    [string]$Product = 'FFActions'
)

$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot
$base = Join-Path $repoRoot 'actions'
$shared = Join-Path $base '_shared\ffcommon_progress.ps1'
$builder = Join-Path $base 'build_ffaction.ps1'
$iconFile = Join-Path $repoRoot 'tools\icons\ffactions.ico'
$copyright = "Copyright (c) 2026 $Company"

function Invoke-GeneratedScriptBuild {
    param(
        [Parameter(Mandatory = $true)][string]$TemplateFile,
        [Parameter(Mandatory = $true)][string]$OutputPs1
    )

    & $builder `
        -SharedFile $shared `
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

    Invoke-PS2EXE @ps2exeParams -ErrorAction Stop
}

function Build-Action {
    param(
        [Parameter(Mandatory = $true)][string]$TemplateFile,
        [Parameter(Mandatory = $true)][string]$OutputPs1,
        [Parameter(Mandatory = $true)][string]$OutputExe,
        [string]$Title
    )

    Invoke-GeneratedScriptBuild -TemplateFile $TemplateFile -OutputPs1 $OutputPs1
    Invoke-ExeBuild -InputFile $OutputPs1 -OutputFile $OutputExe -Title $Title
}

Build-Action `
    -TemplateFile (Join-Path $base 'cut_by_frame.template.ps1') `
    -OutputPs1    (Join-Path $base 'cut_by_frame.ps1') `
    -OutputExe    (Join-Path $base 'cut_by_frame.exe') `
    -Title        'FFActions - Cut by Frame'

Build-Action `
    -TemplateFile (Join-Path $base 'cut_by_time.template.ps1') `
    -OutputPs1    (Join-Path $base 'cut_by_time.ps1') `
    -OutputExe    (Join-Path $base 'cut_by_time.exe') `
    -Title        'FFActions - Cut by Time'

Build-Action `
    -TemplateFile (Join-Path $base 'interpolate.template.ps1') `
    -OutputPs1    (Join-Path $base 'interpolate.ps1') `
    -OutputExe    (Join-Path $base 'interpolate.exe') `
    -Title        'FFActions - Interpolate'

Build-Action `
    -TemplateFile (Join-Path $base 'remove_audio.template.ps1') `
    -OutputPs1    (Join-Path $base 'remove_audio.ps1') `
    -OutputExe    (Join-Path $base 'remove_audio.exe') `
    -Title        'FFActions - Remove Audio'

Build-Action `
    -TemplateFile (Join-Path $base 'cut_audio.template.ps1') `
    -OutputPs1    (Join-Path $base 'cut_audio.ps1') `
    -OutputExe    (Join-Path $base 'cut_audio.exe') `
    -Title        'FFActions - Cut Audio'

Build-Action `
    -TemplateFile (Join-Path $base 'change_audio_speed.template.ps1') `
    -OutputPs1    (Join-Path $base 'change_audio_speed.ps1') `
    -OutputExe    (Join-Path $base 'change_audio_speed.exe') `
    -Title        'FFActions - Change Audio Speed'

Invoke-GeneratedScriptBuild `
    -TemplateFile (Join-Path $base 'change_audio_pitch.template.ps1') `
    -OutputPs1    (Join-Path $base 'change_audio_pitch.ps1')

Invoke-ExeBuild `
    -InputFile  (Join-Path $base 'change_audio_pitch_launcher.ps1') `
    -OutputFile (Join-Path $base 'change_audio_pitch.exe') `
    -Title      'FFActions - Change Audio Pitch'

Invoke-GeneratedScriptBuild `
    -TemplateFile (Join-Path $base 'convert_audio.template.ps1') `
    -OutputPs1    (Join-Path $base 'convert_audio.ps1')

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
    -TemplateFile (Join-Path $base 'convert_image.template.ps1') `
    -OutputPs1    (Join-Path $base 'convert_image.ps1')

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

Build-Action `
    -TemplateFile (Join-Path $base 'convert_icon.template.ps1') `
    -OutputPs1    (Join-Path $base 'convert_icon.ps1') `
    -OutputExe    (Join-Path $base 'convert_icon.exe') `
    -Title        'FFActions - Convert to Icon'

Invoke-GeneratedScriptBuild `
    -TemplateFile (Join-Path $base 'convert_video.template.ps1') `
    -OutputPs1    (Join-Path $base 'convert_video.ps1')

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

Write-Host ''
Write-Host "Build complete. Version: $Version"
