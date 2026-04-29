[Setup]
AppName=FFActions
AppVersion=1.2.0
DefaultDirName={autopf}\FFActions
DefaultGroupName=FFActions
OutputDir=.
OutputBaseFilename=FFActions_Setup
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
DisableProgramGroupPage=yes
SetupIconFile=tools\icons\ffactions.ico
UninstallDisplayIcon={app}\tools\icons\ffactions.ico
ShowComponentSizes=no
ExtraDiskSpaceRequired=220000000

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Messages]
french.ComponentsDiscSpaceLabel=Selectionnez les modules a installer :

[Types]
Name: "complete"; Description: "Installation complete"
Name: "custom"; Description: "Installation personnalisee"; Flags: iscustom

[Components]
Name: "video"; Description: "Video"; Types: complete custom
Name: "video\cut_by_frame"; Description: "Cut by frame"; Types: complete custom
Name: "video\cut_by_time"; Description: "Cut by time"; Types: complete custom
Name: "video\interpolate"; Description: "Interpolate"; Types: complete custom
Name: "video\remove_audio"; Description: "Remove audio"; Types: complete custom
Name: "video\extract_audio"; Description: "Extract audio"; Types: complete custom
Name: "video\create_gif"; Description: "Create GIF"; Types: complete custom
Name: "video\resize_video"; Description: "Resize video"; Types: complete custom
Name: "video\crop_video"; Description: "Crop video"; Types: complete custom
Name: "video\rotate"; Description: "Rotate / flip"; Types: complete custom
Name: "video\compress"; Description: "Compress video"; Types: complete custom
Name: "video\convert"; Description: "Convert"; Types: complete custom
Name: "audio"; Description: "Audio"; Types: complete custom
Name: "audio\cut_audio"; Description: "Cut audio"; Types: complete custom
Name: "audio\change_speed"; Description: "Change speed"; Types: complete custom
Name: "audio\reverse"; Description: "Reverse audio"; Types: complete custom
Name: "audio\compress"; Description: "Compress audio"; Types: complete custom
Name: "audio\change_pitch"; Description: "Change pitch"; Types: complete custom
Name: "audio\convert"; Description: "Convert"; Types: complete custom
Name: "image"; Description: "Image"; Types: complete custom
Name: "image\resize_image"; Description: "Resize image"; Types: complete custom
Name: "image\convert"; Description: "Convert"; Types: complete custom
Name: "image\compress"; Description: "Compress"; Types: complete custom
Name: "image\flip"; Description: "Rotate / flip"; Types: complete custom
Name: "image\crop"; Description: "Crop"; Types: complete custom
Name: "image\icon"; Description: "Convert to icon"; Types: complete custom

[Files]
Source: "actions\cut_by_frame.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\cut_by_frame
Source: "actions\cut_by_time.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\cut_by_time
Source: "actions\interpolate.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\interpolate
Source: "actions\convert_to_mp4.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\convert
Source: "actions\convert_to_mkv.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\convert
Source: "actions\convert_to_avi.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\convert
Source: "actions\convert_to_mov.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\convert
Source: "actions\convert_to_webm.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\convert
Source: "actions\convert_to_m4v.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\convert
Source: "actions\remove_audio.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\remove_audio
Source: "actions\extract_audio_to_mp3.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\extract_audio
Source: "actions\extract_audio_to_wav.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\extract_audio
Source: "actions\extract_audio_to_flac.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\extract_audio
Source: "actions\extract_audio_to_m4a.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\extract_audio
Source: "actions\extract_audio_to_ogg.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\extract_audio
Source: "actions\extract_audio_picker.ps1"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\extract_audio
Source: "actions\extract_audio_picker.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\extract_audio
Source: "actions\create_gif.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\create_gif
Source: "actions\convert_video_picker.ps1"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\convert
Source: "actions\convert_video_picker.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\convert
Source: "actions\resize_video.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\resize_video
Source: "actions\crop_video.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\crop_video
Source: "actions\rotate_video.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\rotate
Source: "actions\compress_video.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: video\compress
Source: "actions\cut_audio.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: audio\cut_audio
Source: "actions\change_audio_speed.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: audio\change_speed
Source: "actions\reverse_audio.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: audio\reverse
Source: "actions\compress_audio.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: audio\compress
Source: "actions\change_audio_pitch.ps1"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: audio\change_pitch
Source: "actions\change_audio_pitch.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: audio\change_pitch
Source: "actions\convert_audio_to_mp3.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: audio\convert
Source: "actions\convert_audio_to_wav.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: audio\convert
Source: "actions\convert_audio_to_flac.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: audio\convert
Source: "actions\convert_audio_to_m4a.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: audio\convert
Source: "actions\convert_audio_to_ogg.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: audio\convert
Source: "actions\convert_audio_picker.ps1"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: audio\convert
Source: "actions\convert_audio_picker.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: audio\convert
Source: "actions\resize_image.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: image\resize_image
Source: "actions\convert_image_to_png.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: image\convert
Source: "actions\convert_image_to_jpg.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: image\convert
Source: "actions\convert_image_to_webp.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: image\convert
Source: "actions\convert_image_to_bmp.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: image\convert
Source: "actions\convert_image_picker.ps1"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: image\convert
Source: "actions\convert_image_picker.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: image\convert
Source: "actions\compress_image.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: image\compress
Source: "actions\flip_image.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: image\flip
Source: "actions\crop_image.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: image\crop
Source: "actions\convert_icon.exe"; DestDir: "{app}\actions"; Flags: ignoreversion; Components: image\icon

Source: "tools\ffmpeg\ffmpeg.exe"; DestDir: "{app}\tools\ffmpeg"; Flags: ignoreversion; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert audio\cut_audio audio\change_speed audio\reverse audio\compress audio\change_pitch audio\convert image\convert image\compress image\flip image\crop image\icon
Source: "tools\ffmpeg\ffprobe.exe"; DestDir: "{app}\tools\ffmpeg"; Flags: ignoreversion; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert audio\cut_audio audio\change_speed audio\reverse audio\compress audio\change_pitch audio\convert
Source: "tools\icons\ffactions.ico"; DestDir: "{app}\tools\icons"; DestName: "ffactions.ico"; Flags: ignoreversion; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert audio\cut_audio audio\change_speed audio\reverse audio\compress audio\change_pitch audio\convert image\resize_image image\convert image\compress image\flip image\crop image\icon
Source: "tools\repair_video_menus.ps1"; DestDir: "{app}\tools"; Flags: ignoreversion; Components: video
Source: "tools\repair_audio_image_convert_menus.ps1"; DestDir: "{app}\tools"; Flags: ignoreversion; Components: audio\convert image\convert

[InstallDelete]
Type: files; Name: "{app}\actions\cut_by_frame.exe"
Type: files; Name: "{app}\actions\cut_by_time.exe"
Type: files; Name: "{app}\actions\interpolate.exe"
Type: files; Name: "{app}\actions\convert_to_mp4.exe"
Type: files; Name: "{app}\actions\convert_to_mkv.exe"
Type: files; Name: "{app}\actions\convert_to_avi.exe"
Type: files; Name: "{app}\actions\convert_to_mov.exe"
Type: files; Name: "{app}\actions\convert_to_webm.exe"
Type: files; Name: "{app}\actions\convert_to_m4v.exe"
Type: files; Name: "{app}\actions\remove_audio.exe"
Type: files; Name: "{app}\actions\extract_audio_to_mp3.exe"
Type: files; Name: "{app}\actions\extract_audio_to_wav.exe"
Type: files; Name: "{app}\actions\extract_audio_to_flac.exe"
Type: files; Name: "{app}\actions\extract_audio_to_m4a.exe"
Type: files; Name: "{app}\actions\extract_audio_to_ogg.exe"
Type: files; Name: "{app}\actions\extract_audio_picker.ps1"
Type: files; Name: "{app}\actions\extract_audio_picker.exe"
Type: files; Name: "{app}\actions\create_gif.exe"
Type: files; Name: "{app}\actions\convert_video_picker.ps1"
Type: files; Name: "{app}\actions\convert_video_picker.exe"
Type: files; Name: "{app}\actions\resize_video.exe"
Type: files; Name: "{app}\actions\crop_video.exe"
Type: files; Name: "{app}\actions\rotate_video.exe"
Type: files; Name: "{app}\actions\compress_video.exe"
Type: files; Name: "{app}\actions\cut_audio.exe"
Type: files; Name: "{app}\actions\change_audio_speed.exe"
Type: files; Name: "{app}\actions\reverse_audio.exe"
Type: files; Name: "{app}\actions\compress_audio.exe"
Type: files; Name: "{app}\actions\change_audio_pitch.exe"
Type: files; Name: "{app}\actions\convert_audio_to_mp3.exe"
Type: files; Name: "{app}\actions\convert_audio_to_wav.exe"
Type: files; Name: "{app}\actions\convert_audio_to_flac.exe"
Type: files; Name: "{app}\actions\convert_audio_to_m4a.exe"
Type: files; Name: "{app}\actions\convert_audio_to_ogg.exe"
Type: files; Name: "{app}\actions\convert_audio_picker.ps1"
Type: files; Name: "{app}\actions\convert_audio_picker.exe"
Type: files; Name: "{app}\actions\resize_image.exe"
Type: files; Name: "{app}\actions\convert_image_to_png.exe"
Type: files; Name: "{app}\actions\convert_image_to_jpg.exe"
Type: files; Name: "{app}\actions\convert_image_to_webp.exe"
Type: files; Name: "{app}\actions\convert_image_to_bmp.exe"
Type: files; Name: "{app}\actions\convert_image_picker.ps1"
Type: files; Name: "{app}\actions\convert_image_picker.exe"
Type: files; Name: "{app}\actions\compress_image.exe"
Type: files; Name: "{app}\actions\flip_image.exe"
Type: files; Name: "{app}\actions\crop_image.exe"
Type: files; Name: "{app}\actions\convert_icon.exe"
Type: files; Name: "{app}\tools\ffmpeg\ffmpeg.exe"
Type: files; Name: "{app}\tools\ffmpeg\ffprobe.exe"
Type: files; Name: "{app}\tools\icons\ffactions.ico"
Type: files; Name: "{app}\tools\repair_video_menus.ps1"
Type: files; Name: "{app}\tools\repair_audio_image_convert_menus.ps1"

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\tools\repair_video_menus.ps1"" -InstallRoot ""{app}"" -AllUsers -ResetExisting"; Flags: runhidden waituntilterminated; Components: video
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\tools\repair_audio_image_convert_menus.ps1"" -InstallRoot ""{app}"" -AllUsers"; Flags: runhidden waituntilterminated; Components: audio\convert image\convert

[Registry]
; ========================
; .mp4
; ========================
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\cut_by_frame"; ValueType: string; ValueName: "MUIVerb"; ValueData: "cut by frame"; Flags: uninsdeletekey; Components: video\cut_by_frame
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\cut_by_frame\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\cut_by_frame.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\cut_by_frame
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\cut_by_time"; ValueType: string; ValueName: "MUIVerb"; ValueData: "cut by time"; Flags: uninsdeletekey; Components: video\cut_by_time
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\cut_by_time\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\cut_by_time.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\cut_by_time
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\interpolate"; ValueType: string; ValueName: "MUIVerb"; ValueData: "interpolate"; Flags: uninsdeletekey; Components: video\interpolate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\interpolate\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\interpolate.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\interpolate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\remove_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "remove audio"; Flags: uninsdeletekey; Components: video\remove_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\remove_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\remove_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\remove_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\extract_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "extract audio"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\extract_audio"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\extract_audio\shell\to_mp3"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mp3"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\extract_audio\shell\to_mp3\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_mp3.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\extract_audio\shell\to_wav"; ValueType: string; ValueName: "MUIVerb"; ValueData: "wav"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\extract_audio\shell\to_wav\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_wav.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\extract_audio\shell\to_flac"; ValueType: string; ValueName: "MUIVerb"; ValueData: "flac"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\extract_audio\shell\to_flac\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_flac.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\extract_audio\shell\to_m4a"; ValueType: string; ValueName: "MUIVerb"; ValueData: "m4a"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\extract_audio\shell\to_m4a\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_m4a.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\extract_audio\shell\to_ogg"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ogg"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\extract_audio\shell\to_ogg\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_ogg.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\create_gif"; ValueType: string; ValueName: "MUIVerb"; ValueData: "create gif"; Flags: uninsdeletekey; Components: video\create_gif
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\create_gif\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\create_gif.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\create_gif
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\resize"; ValueType: string; ValueName: "MUIVerb"; ValueData: "resize video"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\resize"; ValueType: string; ValueName: "Position"; ValueData: "Top"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\resize\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\resize_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\resize"; ValueType: string; ValueName: "MUIVerb"; ValueData: "resize video"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\resize"; ValueType: string; ValueName: "Position"; ValueData: "Top"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\resize\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\resize_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\resize_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\crop_video"; ValueType: string; ValueName: "MUIVerb"; ValueData: "crop video"; Flags: uninsdeletekey; Components: video\crop_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\crop_video\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\crop_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\crop_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\rotate_video"; ValueType: string; ValueName: "MUIVerb"; ValueData: "rotate / flip"; Flags: uninsdeletekey; Components: video\rotate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\rotate_video\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\rotate_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\rotate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\compress_video"; ValueType: string; ValueName: "MUIVerb"; ValueData: "compress video"; Flags: uninsdeletekey; Components: video\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\compress_video\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\compress_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\convert"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\convert"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\convert\shell\to_mkv"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mkv"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\convert\shell\to_mkv\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_mkv.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\convert\shell\to_avi"; ValueType: string; ValueName: "MUIVerb"; ValueData: "avi"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\convert\shell\to_avi\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_avi.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\convert\shell\to_mov"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mov"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\convert\shell\to_mov\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_mov.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\convert\shell\to_webm"; ValueType: string; ValueName: "MUIVerb"; ValueData: "webm"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\convert\shell\to_webm\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_webm.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\convert\shell\to_m4v"; ValueType: string; ValueName: "MUIVerb"; ValueData: "m4v"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp4\shell\FFActions\shell\convert\shell\to_m4v\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_m4v.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert

; ========================
; .mkv
; ========================
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\cut_by_frame"; ValueType: string; ValueName: "MUIVerb"; ValueData: "cut by frame"; Flags: uninsdeletekey; Components: video\cut_by_frame
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\cut_by_frame\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\cut_by_frame.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\cut_by_frame
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\cut_by_time"; ValueType: string; ValueName: "MUIVerb"; ValueData: "cut by time"; Flags: uninsdeletekey; Components: video\cut_by_time
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\cut_by_time\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\cut_by_time.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\cut_by_time
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\interpolate"; ValueType: string; ValueName: "MUIVerb"; ValueData: "interpolate"; Flags: uninsdeletekey; Components: video\interpolate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\interpolate\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\interpolate.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\interpolate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\remove_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "remove audio"; Flags: uninsdeletekey; Components: video\remove_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\remove_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\remove_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\remove_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\extract_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "extract audio"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\extract_audio"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\extract_audio\shell\to_mp3"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mp3"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\extract_audio\shell\to_mp3\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_mp3.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\extract_audio\shell\to_wav"; ValueType: string; ValueName: "MUIVerb"; ValueData: "wav"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\extract_audio\shell\to_wav\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_wav.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\extract_audio\shell\to_flac"; ValueType: string; ValueName: "MUIVerb"; ValueData: "flac"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\extract_audio\shell\to_flac\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_flac.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\extract_audio\shell\to_m4a"; ValueType: string; ValueName: "MUIVerb"; ValueData: "m4a"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\extract_audio\shell\to_m4a\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_m4a.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\extract_audio\shell\to_ogg"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ogg"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\extract_audio\shell\to_ogg\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_ogg.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\create_gif"; ValueType: string; ValueName: "MUIVerb"; ValueData: "create gif"; Flags: uninsdeletekey; Components: video\create_gif
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\create_gif\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\create_gif.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\create_gif
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\resize"; ValueType: string; ValueName: "MUIVerb"; ValueData: "resize video"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\resize"; ValueType: string; ValueName: "Position"; ValueData: "Top"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\resize\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\resize_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\resize"; ValueType: string; ValueName: "MUIVerb"; ValueData: "resize video"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\resize"; ValueType: string; ValueName: "Position"; ValueData: "Top"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\resize\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\resize_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\resize_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\crop_video"; ValueType: string; ValueName: "MUIVerb"; ValueData: "crop video"; Flags: uninsdeletekey; Components: video\crop_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\crop_video\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\crop_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\crop_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\rotate_video"; ValueType: string; ValueName: "MUIVerb"; ValueData: "rotate / flip"; Flags: uninsdeletekey; Components: video\rotate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\rotate_video\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\rotate_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\rotate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\compress_video"; ValueType: string; ValueName: "MUIVerb"; ValueData: "compress video"; Flags: uninsdeletekey; Components: video\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\compress_video\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\compress_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\convert"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\convert"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\convert\shell\to_mp4"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mp4"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\convert\shell\to_mp4\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_mp4.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\convert\shell\to_avi"; ValueType: string; ValueName: "MUIVerb"; ValueData: "avi"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\convert\shell\to_avi\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_avi.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\convert\shell\to_mov"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mov"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\convert\shell\to_mov\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_mov.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\convert\shell\to_webm"; ValueType: string; ValueName: "MUIVerb"; ValueData: "webm"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\convert\shell\to_webm\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_webm.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\convert\shell\to_m4v"; ValueType: string; ValueName: "MUIVerb"; ValueData: "m4v"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mkv\shell\FFActions\shell\convert\shell\to_m4v\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_m4v.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert

; ========================
; .avi
; ========================
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\cut_by_frame"; ValueType: string; ValueName: "MUIVerb"; ValueData: "cut by frame"; Flags: uninsdeletekey; Components: video\cut_by_frame
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\cut_by_frame\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\cut_by_frame.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\cut_by_frame
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\cut_by_time"; ValueType: string; ValueName: "MUIVerb"; ValueData: "cut by time"; Flags: uninsdeletekey; Components: video\cut_by_time
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\cut_by_time\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\cut_by_time.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\cut_by_time
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\interpolate"; ValueType: string; ValueName: "MUIVerb"; ValueData: "interpolate"; Flags: uninsdeletekey; Components: video\interpolate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\interpolate\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\interpolate.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\interpolate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\remove_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "remove audio"; Flags: uninsdeletekey; Components: video\remove_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\remove_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\remove_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\remove_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\extract_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "extract audio"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\extract_audio"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\extract_audio\shell\to_mp3"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mp3"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\extract_audio\shell\to_mp3\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_mp3.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\extract_audio\shell\to_wav"; ValueType: string; ValueName: "MUIVerb"; ValueData: "wav"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\extract_audio\shell\to_wav\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_wav.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\extract_audio\shell\to_flac"; ValueType: string; ValueName: "MUIVerb"; ValueData: "flac"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\extract_audio\shell\to_flac\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_flac.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\extract_audio\shell\to_m4a"; ValueType: string; ValueName: "MUIVerb"; ValueData: "m4a"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\extract_audio\shell\to_m4a\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_m4a.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\extract_audio\shell\to_ogg"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ogg"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\extract_audio\shell\to_ogg\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_ogg.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\create_gif"; ValueType: string; ValueName: "MUIVerb"; ValueData: "create gif"; Flags: uninsdeletekey; Components: video\create_gif
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\create_gif\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\create_gif.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\create_gif
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\resize"; ValueType: string; ValueName: "MUIVerb"; ValueData: "resize video"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\resize"; ValueType: string; ValueName: "Position"; ValueData: "Top"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\resize\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\resize_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\resize"; ValueType: string; ValueName: "MUIVerb"; ValueData: "resize video"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\resize"; ValueType: string; ValueName: "Position"; ValueData: "Top"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\resize\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\resize_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\resize_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\crop_video"; ValueType: string; ValueName: "MUIVerb"; ValueData: "crop video"; Flags: uninsdeletekey; Components: video\crop_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\crop_video\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\crop_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\crop_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\rotate_video"; ValueType: string; ValueName: "MUIVerb"; ValueData: "rotate / flip"; Flags: uninsdeletekey; Components: video\rotate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\rotate_video\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\rotate_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\rotate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\compress_video"; ValueType: string; ValueName: "MUIVerb"; ValueData: "compress video"; Flags: uninsdeletekey; Components: video\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\compress_video\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\compress_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\convert"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\convert"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\convert\shell\to_mp4"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mp4"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\convert\shell\to_mp4\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_mp4.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\convert\shell\to_mkv"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mkv"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\convert\shell\to_mkv\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_mkv.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\convert\shell\to_mov"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mov"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\convert\shell\to_mov\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_mov.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\convert\shell\to_webm"; ValueType: string; ValueName: "MUIVerb"; ValueData: "webm"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\convert\shell\to_webm\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_webm.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\convert\shell\to_m4v"; ValueType: string; ValueName: "MUIVerb"; ValueData: "m4v"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.avi\shell\FFActions\shell\convert\shell\to_m4v\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_m4v.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert

; ========================
; .mov
; ========================
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\cut_by_frame"; ValueType: string; ValueName: "MUIVerb"; ValueData: "cut by frame"; Flags: uninsdeletekey; Components: video\cut_by_frame
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\cut_by_frame\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\cut_by_frame.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\cut_by_frame
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\cut_by_time"; ValueType: string; ValueName: "MUIVerb"; ValueData: "cut by time"; Flags: uninsdeletekey; Components: video\cut_by_time
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\cut_by_time\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\cut_by_time.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\cut_by_time
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\interpolate"; ValueType: string; ValueName: "MUIVerb"; ValueData: "interpolate"; Flags: uninsdeletekey; Components: video\interpolate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\interpolate\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\interpolate.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\interpolate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\remove_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "remove audio"; Flags: uninsdeletekey; Components: video\remove_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\remove_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\remove_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\remove_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\extract_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "extract audio"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\extract_audio"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\extract_audio\shell\to_mp3"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mp3"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\extract_audio\shell\to_mp3\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_mp3.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\extract_audio\shell\to_wav"; ValueType: string; ValueName: "MUIVerb"; ValueData: "wav"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\extract_audio\shell\to_wav\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_wav.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\extract_audio\shell\to_flac"; ValueType: string; ValueName: "MUIVerb"; ValueData: "flac"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\extract_audio\shell\to_flac\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_flac.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\extract_audio\shell\to_m4a"; ValueType: string; ValueName: "MUIVerb"; ValueData: "m4a"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\extract_audio\shell\to_m4a\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_m4a.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\extract_audio\shell\to_ogg"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ogg"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\extract_audio\shell\to_ogg\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_ogg.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\create_gif"; ValueType: string; ValueName: "MUIVerb"; ValueData: "create gif"; Flags: uninsdeletekey; Components: video\create_gif
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\create_gif\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\create_gif.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\create_gif
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\resize"; ValueType: string; ValueName: "MUIVerb"; ValueData: "resize video"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\resize"; ValueType: string; ValueName: "Position"; ValueData: "Top"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\resize\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\resize_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\resize"; ValueType: string; ValueName: "MUIVerb"; ValueData: "resize video"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\resize"; ValueType: string; ValueName: "Position"; ValueData: "Top"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\resize\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\resize_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\resize_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\crop_video"; ValueType: string; ValueName: "MUIVerb"; ValueData: "crop video"; Flags: uninsdeletekey; Components: video\crop_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\crop_video\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\crop_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\crop_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\rotate_video"; ValueType: string; ValueName: "MUIVerb"; ValueData: "rotate / flip"; Flags: uninsdeletekey; Components: video\rotate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\rotate_video\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\rotate_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\rotate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\compress_video"; ValueType: string; ValueName: "MUIVerb"; ValueData: "compress video"; Flags: uninsdeletekey; Components: video\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\compress_video\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\compress_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\convert"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\convert"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\convert\shell\to_mp4"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mp4"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\convert\shell\to_mp4\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_mp4.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\convert\shell\to_mkv"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mkv"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\convert\shell\to_mkv\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_mkv.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\convert\shell\to_avi"; ValueType: string; ValueName: "MUIVerb"; ValueData: "avi"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\convert\shell\to_avi\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_avi.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\convert\shell\to_webm"; ValueType: string; ValueName: "MUIVerb"; ValueData: "webm"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\convert\shell\to_webm\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_webm.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\convert\shell\to_m4v"; ValueType: string; ValueName: "MUIVerb"; ValueData: "m4v"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mov\shell\FFActions\shell\convert\shell\to_m4v\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_m4v.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert

; ========================
; .webm
; ========================
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\cut_by_frame"; ValueType: string; ValueName: "MUIVerb"; ValueData: "cut by frame"; Flags: uninsdeletekey; Components: video\cut_by_frame
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\cut_by_frame\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\cut_by_frame.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\cut_by_frame
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\cut_by_time"; ValueType: string; ValueName: "MUIVerb"; ValueData: "cut by time"; Flags: uninsdeletekey; Components: video\cut_by_time
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\cut_by_time\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\cut_by_time.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\cut_by_time
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\interpolate"; ValueType: string; ValueName: "MUIVerb"; ValueData: "interpolate"; Flags: uninsdeletekey; Components: video\interpolate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\interpolate\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\interpolate.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\interpolate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\remove_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "remove audio"; Flags: uninsdeletekey; Components: video\remove_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\remove_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\remove_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\remove_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\extract_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "extract audio"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\extract_audio"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\extract_audio\shell\to_mp3"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mp3"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\extract_audio\shell\to_mp3\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_mp3.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\extract_audio\shell\to_wav"; ValueType: string; ValueName: "MUIVerb"; ValueData: "wav"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\extract_audio\shell\to_wav\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_wav.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\extract_audio\shell\to_flac"; ValueType: string; ValueName: "MUIVerb"; ValueData: "flac"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\extract_audio\shell\to_flac\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_flac.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\extract_audio\shell\to_m4a"; ValueType: string; ValueName: "MUIVerb"; ValueData: "m4a"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\extract_audio\shell\to_m4a\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_m4a.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\extract_audio\shell\to_ogg"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ogg"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\extract_audio\shell\to_ogg\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_ogg.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\create_gif"; ValueType: string; ValueName: "MUIVerb"; ValueData: "create gif"; Flags: uninsdeletekey; Components: video\create_gif
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\create_gif\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\create_gif.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\create_gif
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\resize"; ValueType: string; ValueName: "MUIVerb"; ValueData: "resize video"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\resize"; ValueType: string; ValueName: "Position"; ValueData: "Top"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\resize\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\resize_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\resize"; ValueType: string; ValueName: "MUIVerb"; ValueData: "resize video"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\resize"; ValueType: string; ValueName: "Position"; ValueData: "Top"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\resize\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\resize_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\resize_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\crop_video"; ValueType: string; ValueName: "MUIVerb"; ValueData: "crop video"; Flags: uninsdeletekey; Components: video\crop_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\crop_video\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\crop_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\crop_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\rotate_video"; ValueType: string; ValueName: "MUIVerb"; ValueData: "rotate / flip"; Flags: uninsdeletekey; Components: video\rotate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\rotate_video\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\rotate_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\rotate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\compress_video"; ValueType: string; ValueName: "MUIVerb"; ValueData: "compress video"; Flags: uninsdeletekey; Components: video\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\compress_video\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\compress_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\convert"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\convert"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\convert\shell\to_mp4"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mp4"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\convert\shell\to_mp4\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_mp4.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\convert\shell\to_mkv"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mkv"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\convert\shell\to_mkv\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_mkv.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\convert\shell\to_avi"; ValueType: string; ValueName: "MUIVerb"; ValueData: "avi"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\convert\shell\to_avi\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_avi.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\convert\shell\to_mov"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mov"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\convert\shell\to_mov\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_mov.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\convert\shell\to_m4v"; ValueType: string; ValueName: "MUIVerb"; ValueData: "m4v"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webm\shell\FFActions\shell\convert\shell\to_m4v\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_m4v.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert

; ========================
; .m4v
; ========================
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: video\cut_by_frame video\cut_by_time video\interpolate video\remove_audio video\extract_audio video\create_gif video\resize_video video\crop_video video\rotate video\compress video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\cut_by_frame"; ValueType: string; ValueName: "MUIVerb"; ValueData: "cut by frame"; Flags: uninsdeletekey; Components: video\cut_by_frame
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\cut_by_frame\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\cut_by_frame.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\cut_by_frame
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\cut_by_time"; ValueType: string; ValueName: "MUIVerb"; ValueData: "cut by time"; Flags: uninsdeletekey; Components: video\cut_by_time
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\cut_by_time\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\cut_by_time.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\cut_by_time
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\interpolate"; ValueType: string; ValueName: "MUIVerb"; ValueData: "interpolate"; Flags: uninsdeletekey; Components: video\interpolate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\interpolate\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\interpolate.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\interpolate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\remove_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "remove audio"; Flags: uninsdeletekey; Components: video\remove_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\remove_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\remove_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\remove_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\extract_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "extract audio"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\extract_audio"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\extract_audio\shell\to_mp3"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mp3"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\extract_audio\shell\to_mp3\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_mp3.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\extract_audio\shell\to_wav"; ValueType: string; ValueName: "MUIVerb"; ValueData: "wav"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\extract_audio\shell\to_wav\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_wav.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\extract_audio\shell\to_flac"; ValueType: string; ValueName: "MUIVerb"; ValueData: "flac"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\extract_audio\shell\to_flac\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_flac.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\extract_audio\shell\to_m4a"; ValueType: string; ValueName: "MUIVerb"; ValueData: "m4a"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\extract_audio\shell\to_m4a\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_m4a.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\extract_audio\shell\to_ogg"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ogg"; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\extract_audio\shell\to_ogg\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\extract_audio_to_ogg.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\extract_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\create_gif"; ValueType: string; ValueName: "MUIVerb"; ValueData: "create gif"; Flags: uninsdeletekey; Components: video\create_gif
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\create_gif\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\create_gif.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\create_gif
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\resize"; ValueType: string; ValueName: "MUIVerb"; ValueData: "resize video"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\resize"; ValueType: string; ValueName: "Position"; ValueData: "Top"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\resize\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\resize_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\resize"; ValueType: string; ValueName: "MUIVerb"; ValueData: "resize video"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\resize"; ValueType: string; ValueName: "Position"; ValueData: "Top"; Flags: uninsdeletekey; Components: video\resize_video
Root: HKLM; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\resize\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\resize_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\resize_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\crop_video"; ValueType: string; ValueName: "MUIVerb"; ValueData: "crop video"; Flags: uninsdeletekey; Components: video\crop_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\crop_video\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\crop_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\crop_video
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\rotate_video"; ValueType: string; ValueName: "MUIVerb"; ValueData: "rotate / flip"; Flags: uninsdeletekey; Components: video\rotate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\rotate_video\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\rotate_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\rotate
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\compress_video"; ValueType: string; ValueName: "MUIVerb"; ValueData: "compress video"; Flags: uninsdeletekey; Components: video\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\compress_video\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\compress_video.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\convert"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\convert"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\convert\shell\to_mp4"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mp4"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\convert\shell\to_mp4\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_mp4.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\convert\shell\to_mkv"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mkv"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\convert\shell\to_mkv\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_mkv.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\convert\shell\to_avi"; ValueType: string; ValueName: "MUIVerb"; ValueData: "avi"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\convert\shell\to_avi\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_avi.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\convert\shell\to_mov"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mov"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\convert\shell\to_mov\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_mov.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\convert\shell\to_webm"; ValueType: string; ValueName: "MUIVerb"; ValueData: "webm"; Flags: uninsdeletekey; Components: video\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4v\shell\FFActions\shell\convert\shell\to_webm\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_to_webm.exe"" ""%1"""; Flags: uninsdeletekey; Components: video\convert

; ========================
; .wav
; ========================
; ========================
; .wav
; ========================
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: audio\cut_audio audio\change_speed audio\reverse audio\compress audio\change_pitch audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: audio\cut_audio audio\change_speed audio\reverse audio\compress audio\change_pitch audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: audio\cut_audio audio\change_speed audio\reverse audio\compress audio\change_pitch audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\cut_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "cut audio"; Flags: uninsdeletekey; Components: audio\cut_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\cut_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\cut_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\cut_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\change_audio_speed"; ValueType: string; ValueName: "MUIVerb"; ValueData: "change speed"; Flags: uninsdeletekey; Components: audio\change_speed
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\change_audio_speed\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\change_audio_speed.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\change_speed
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\reverse_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "reverse audio"; Flags: uninsdeletekey; Components: audio\reverse
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\reverse_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\reverse_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\reverse
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\compress_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "compress audio"; Flags: uninsdeletekey; Components: audio\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\compress_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\compress_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\change_audio_pitch"; ValueType: string; ValueName: "MUIVerb"; ValueData: "change pitch"; Flags: uninsdeletekey; Components: audio\change_pitch
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\change_audio_pitch\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\change_audio_pitch.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\change_pitch
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\convert"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\convert"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\convert\shell\to_mp3"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mp3"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\convert\shell\to_mp3\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_mp3.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\convert\shell\to_flac"; ValueType: string; ValueName: "MUIVerb"; ValueData: "flac"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\convert\shell\to_flac\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_flac.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\convert\shell\to_m4a"; ValueType: string; ValueName: "MUIVerb"; ValueData: "m4a"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\convert\shell\to_m4a\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_m4a.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\convert\shell\to_ogg"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ogg"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.wav\shell\FFActions\shell\convert\shell\to_ogg\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_ogg.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert

; ========================
; .mp3
; ========================
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: audio\cut_audio audio\change_speed audio\reverse audio\compress audio\change_pitch audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: audio\cut_audio audio\change_speed audio\reverse audio\compress audio\change_pitch audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: audio\cut_audio audio\change_speed audio\reverse audio\compress audio\change_pitch audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\cut_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "cut audio"; Flags: uninsdeletekey; Components: audio\cut_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\cut_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\cut_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\cut_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\change_audio_speed"; ValueType: string; ValueName: "MUIVerb"; ValueData: "change speed"; Flags: uninsdeletekey; Components: audio\change_speed
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\change_audio_speed\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\change_audio_speed.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\change_speed
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\reverse_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "reverse audio"; Flags: uninsdeletekey; Components: audio\reverse
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\reverse_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\reverse_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\reverse
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\compress_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "compress audio"; Flags: uninsdeletekey; Components: audio\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\compress_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\compress_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\change_audio_pitch"; ValueType: string; ValueName: "MUIVerb"; ValueData: "change pitch"; Flags: uninsdeletekey; Components: audio\change_pitch
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\change_audio_pitch\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\change_audio_pitch.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\change_pitch
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\convert"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\convert"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\convert\shell\to_wav"; ValueType: string; ValueName: "MUIVerb"; ValueData: "wav"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\convert\shell\to_wav\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_wav.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\convert\shell\to_flac"; ValueType: string; ValueName: "MUIVerb"; ValueData: "flac"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\convert\shell\to_flac\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_flac.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\convert\shell\to_m4a"; ValueType: string; ValueName: "MUIVerb"; ValueData: "m4a"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\convert\shell\to_m4a\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_m4a.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\convert\shell\to_ogg"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ogg"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.mp3\shell\FFActions\shell\convert\shell\to_ogg\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_ogg.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert

; ========================
; .flac
; ========================
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: audio\cut_audio audio\change_speed audio\reverse audio\compress audio\change_pitch audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: audio\cut_audio audio\change_speed audio\reverse audio\compress audio\change_pitch audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: audio\cut_audio audio\change_speed audio\reverse audio\compress audio\change_pitch audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\cut_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "cut audio"; Flags: uninsdeletekey; Components: audio\cut_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\cut_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\cut_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\cut_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\change_audio_speed"; ValueType: string; ValueName: "MUIVerb"; ValueData: "change speed"; Flags: uninsdeletekey; Components: audio\change_speed
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\change_audio_speed\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\change_audio_speed.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\change_speed
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\reverse_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "reverse audio"; Flags: uninsdeletekey; Components: audio\reverse
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\reverse_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\reverse_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\reverse
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\compress_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "compress audio"; Flags: uninsdeletekey; Components: audio\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\compress_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\compress_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\change_audio_pitch"; ValueType: string; ValueName: "MUIVerb"; ValueData: "change pitch"; Flags: uninsdeletekey; Components: audio\change_pitch
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\change_audio_pitch\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\change_audio_pitch.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\change_pitch
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\convert"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\convert"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\convert\shell\to_mp3"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mp3"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\convert\shell\to_mp3\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_mp3.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\convert\shell\to_wav"; ValueType: string; ValueName: "MUIVerb"; ValueData: "wav"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\convert\shell\to_wav\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_wav.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\convert\shell\to_m4a"; ValueType: string; ValueName: "MUIVerb"; ValueData: "m4a"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\convert\shell\to_m4a\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_m4a.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\convert\shell\to_ogg"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ogg"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.flac\shell\FFActions\shell\convert\shell\to_ogg\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_ogg.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert

; ========================
; .m4a
; ========================
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: audio\cut_audio audio\change_speed audio\reverse audio\compress audio\change_pitch audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: audio\cut_audio audio\change_speed audio\reverse audio\compress audio\change_pitch audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: audio\cut_audio audio\change_speed audio\reverse audio\compress audio\change_pitch audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\cut_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "cut audio"; Flags: uninsdeletekey; Components: audio\cut_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\cut_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\cut_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\cut_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\change_audio_speed"; ValueType: string; ValueName: "MUIVerb"; ValueData: "change speed"; Flags: uninsdeletekey; Components: audio\change_speed
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\change_audio_speed\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\change_audio_speed.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\change_speed
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\reverse_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "reverse audio"; Flags: uninsdeletekey; Components: audio\reverse
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\reverse_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\reverse_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\reverse
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\compress_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "compress audio"; Flags: uninsdeletekey; Components: audio\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\compress_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\compress_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\change_audio_pitch"; ValueType: string; ValueName: "MUIVerb"; ValueData: "change pitch"; Flags: uninsdeletekey; Components: audio\change_pitch
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\change_audio_pitch\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\change_audio_pitch.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\change_pitch
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\convert"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\convert"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\convert\shell\to_mp3"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mp3"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\convert\shell\to_mp3\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_mp3.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\convert\shell\to_wav"; ValueType: string; ValueName: "MUIVerb"; ValueData: "wav"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\convert\shell\to_wav\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_wav.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\convert\shell\to_flac"; ValueType: string; ValueName: "MUIVerb"; ValueData: "flac"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\convert\shell\to_flac\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_flac.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\convert\shell\to_ogg"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ogg"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.m4a\shell\FFActions\shell\convert\shell\to_ogg\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_ogg.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert

; ========================
; .ogg
; ========================
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: audio\cut_audio audio\change_speed audio\reverse audio\compress audio\change_pitch audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: audio\cut_audio audio\change_speed audio\reverse audio\compress audio\change_pitch audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: audio\cut_audio audio\change_speed audio\reverse audio\compress audio\change_pitch audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\cut_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "cut audio"; Flags: uninsdeletekey; Components: audio\cut_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\cut_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\cut_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\cut_audio
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\change_audio_speed"; ValueType: string; ValueName: "MUIVerb"; ValueData: "change speed"; Flags: uninsdeletekey; Components: audio\change_speed
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\change_audio_speed\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\change_audio_speed.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\change_speed
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\reverse_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "reverse audio"; Flags: uninsdeletekey; Components: audio\reverse
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\reverse_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\reverse_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\reverse
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\compress_audio"; ValueType: string; ValueName: "MUIVerb"; ValueData: "compress audio"; Flags: uninsdeletekey; Components: audio\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\compress_audio\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\compress_audio.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\change_audio_pitch"; ValueType: string; ValueName: "MUIVerb"; ValueData: "change pitch"; Flags: uninsdeletekey; Components: audio\change_pitch
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\change_audio_pitch\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\change_audio_pitch.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\change_pitch
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\convert"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\convert"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\convert\shell\to_mp3"; ValueType: string; ValueName: "MUIVerb"; ValueData: "mp3"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\convert\shell\to_mp3\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_mp3.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\convert\shell\to_wav"; ValueType: string; ValueName: "MUIVerb"; ValueData: "wav"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\convert\shell\to_wav\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_wav.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\convert\shell\to_flac"; ValueType: string; ValueName: "MUIVerb"; ValueData: "flac"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\convert\shell\to_flac\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_flac.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\convert\shell\to_m4a"; ValueType: string; ValueName: "MUIVerb"; ValueData: "m4a"; Flags: uninsdeletekey; Components: audio\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.ogg\shell\FFActions\shell\convert\shell\to_m4a\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_audio_to_m4a.exe"" ""%1"""; Flags: uninsdeletekey; Components: audio\convert

Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: image\resize_image image\convert image\compress image\flip image\crop image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: image\resize_image image\convert image\compress image\flip image\crop image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: image\resize_image image\convert image\compress image\flip image\crop image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions\shell\resize_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "resize image"; Flags: uninsdeletekey; Components: image\resize_image
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions\shell\resize_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\resize_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\resize_image
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions\shell\compress_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "compress image"; Flags: uninsdeletekey; Components: image\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions\shell\compress_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\compress_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions\shell\flip_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "rotate / flip"; Flags: uninsdeletekey; Components: image\flip
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions\shell\flip_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\flip_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\flip
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions\shell\crop_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "crop image"; Flags: uninsdeletekey; Components: image\crop
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions\shell\crop_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\crop_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\crop
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions\shell\convert_icon"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert to icon"; Flags: uninsdeletekey; Components: image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions\shell\convert_icon\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_icon.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions\shell\convert"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions\shell\convert"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions\shell\convert\shell\to_jpg"; ValueType: string; ValueName: "MUIVerb"; ValueData: "jpg"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions\shell\convert\shell\to_jpg\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_image_to_jpg.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions\shell\convert\shell\to_webp"; ValueType: string; ValueName: "MUIVerb"; ValueData: "webp"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions\shell\convert\shell\to_webp\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_image_to_webp.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions\shell\convert\shell\to_bmp"; ValueType: string; ValueName: "MUIVerb"; ValueData: "bmp"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.png\shell\FFActions\shell\convert\shell\to_bmp\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_image_to_bmp.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\convert

Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: image\resize_image image\convert image\compress image\flip image\crop image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: image\resize_image image\convert image\compress image\flip image\crop image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: image\resize_image image\convert image\compress image\flip image\crop image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions\shell\resize_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "resize image"; Flags: uninsdeletekey; Components: image\resize_image
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions\shell\resize_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\resize_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\resize_image
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions\shell\compress_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "compress image"; Flags: uninsdeletekey; Components: image\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions\shell\compress_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\compress_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions\shell\flip_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "rotate / flip"; Flags: uninsdeletekey; Components: image\flip
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions\shell\flip_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\flip_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\flip
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions\shell\crop_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "crop image"; Flags: uninsdeletekey; Components: image\crop
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions\shell\crop_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\crop_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\crop
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions\shell\convert_icon"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert to icon"; Flags: uninsdeletekey; Components: image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions\shell\convert_icon\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_icon.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions\shell\convert"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions\shell\convert"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions\shell\convert\shell\to_png"; ValueType: string; ValueName: "MUIVerb"; ValueData: "png"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions\shell\convert\shell\to_png\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_image_to_png.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions\shell\convert\shell\to_webp"; ValueType: string; ValueName: "MUIVerb"; ValueData: "webp"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions\shell\convert\shell\to_webp\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_image_to_webp.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions\shell\convert\shell\to_bmp"; ValueType: string; ValueName: "MUIVerb"; ValueData: "bmp"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpg\shell\FFActions\shell\convert\shell\to_bmp\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_image_to_bmp.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\convert

Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: image\resize_image image\convert image\compress image\flip image\crop image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: image\resize_image image\convert image\compress image\flip image\crop image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: image\resize_image image\convert image\compress image\flip image\crop image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions\shell\resize_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "resize image"; Flags: uninsdeletekey; Components: image\resize_image
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions\shell\resize_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\resize_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\resize_image
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions\shell\compress_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "compress image"; Flags: uninsdeletekey; Components: image\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions\shell\compress_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\compress_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions\shell\flip_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "rotate / flip"; Flags: uninsdeletekey; Components: image\flip
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions\shell\flip_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\flip_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\flip
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions\shell\crop_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "crop image"; Flags: uninsdeletekey; Components: image\crop
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions\shell\crop_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\crop_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\crop
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions\shell\convert_icon"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert to icon"; Flags: uninsdeletekey; Components: image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions\shell\convert_icon\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_icon.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions\shell\convert"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions\shell\convert"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions\shell\convert\shell\to_png"; ValueType: string; ValueName: "MUIVerb"; ValueData: "png"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions\shell\convert\shell\to_png\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_image_to_png.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions\shell\convert\shell\to_webp"; ValueType: string; ValueName: "MUIVerb"; ValueData: "webp"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions\shell\convert\shell\to_webp\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_image_to_webp.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions\shell\convert\shell\to_bmp"; ValueType: string; ValueName: "MUIVerb"; ValueData: "bmp"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions\shell\convert\shell\to_bmp\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_image_to_bmp.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\convert

Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: image\resize_image image\convert image\compress image\flip image\crop image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: image\resize_image image\convert image\compress image\flip image\crop image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: image\resize_image image\convert image\compress image\flip image\crop image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions\shell\resize_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "resize image"; Flags: uninsdeletekey; Components: image\resize_image
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions\shell\resize_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\resize_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\resize_image
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions\shell\compress_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "compress image"; Flags: uninsdeletekey; Components: image\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions\shell\compress_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\compress_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions\shell\flip_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "rotate / flip"; Flags: uninsdeletekey; Components: image\flip
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions\shell\flip_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\flip_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\flip
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions\shell\crop_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "crop image"; Flags: uninsdeletekey; Components: image\crop
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions\shell\crop_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\crop_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\crop
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions\shell\convert_icon"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert to icon"; Flags: uninsdeletekey; Components: image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions\shell\convert_icon\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_icon.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions\shell\convert"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions\shell\convert"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions\shell\convert\shell\to_png"; ValueType: string; ValueName: "MUIVerb"; ValueData: "png"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions\shell\convert\shell\to_png\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_image_to_png.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions\shell\convert\shell\to_jpg"; ValueType: string; ValueName: "MUIVerb"; ValueData: "jpg"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions\shell\convert\shell\to_jpg\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_image_to_jpg.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions\shell\convert\shell\to_webp"; ValueType: string; ValueName: "MUIVerb"; ValueData: "webp"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.bmp\shell\FFActions\shell\convert\shell\to_webp\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_image_to_webp.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\convert

Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions"; ValueType: string; ValueName: "MUIVerb"; ValueData: "ffmpg"; Flags: uninsdeletekey; Components: image\resize_image image\convert image\compress image\flip image\crop image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: image\resize_image image\convert image\compress image\flip image\crop image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\tools\icons\ffactions.ico"; Flags: uninsdeletekey; Components: image\resize_image image\convert image\compress image\flip image\crop image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions\shell\resize_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "resize image"; Flags: uninsdeletekey; Components: image\resize_image
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions\shell\resize_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\resize_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\resize_image
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions\shell\compress_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "compress image"; Flags: uninsdeletekey; Components: image\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions\shell\compress_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\compress_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\compress
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions\shell\flip_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "rotate / flip"; Flags: uninsdeletekey; Components: image\flip
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions\shell\flip_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\flip_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\flip
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions\shell\crop_image"; ValueType: string; ValueName: "MUIVerb"; ValueData: "crop image"; Flags: uninsdeletekey; Components: image\crop
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions\shell\crop_image\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\crop_image.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\crop
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions\shell\convert_icon"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert to icon"; Flags: uninsdeletekey; Components: image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions\shell\convert_icon\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_icon.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\icon
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions\shell\convert"; ValueType: string; ValueName: "MUIVerb"; ValueData: "convert"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions\shell\convert"; ValueType: string; ValueName: "SubCommands"; ValueData: ""; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions\shell\convert\shell\to_png"; ValueType: string; ValueName: "MUIVerb"; ValueData: "png"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions\shell\convert\shell\to_png\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_image_to_png.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions\shell\convert\shell\to_jpg"; ValueType: string; ValueName: "MUIVerb"; ValueData: "jpg"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions\shell\convert\shell\to_jpg\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_image_to_jpg.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions\shell\convert\shell\to_bmp"; ValueType: string; ValueName: "MUIVerb"; ValueData: "bmp"; Flags: uninsdeletekey; Components: image\convert
Root: HKCU; Subkey: "Software\Classes\SystemFileAssociations\.webp\shell\FFActions\shell\convert\shell\to_bmp\command"; ValueType: string; ValueName: ""; ValueData: """{app}\actions\convert_image_to_bmp.exe"" ""%1"""; Flags: uninsdeletekey; Components: image\convert

[Code]
procedure CleanupContextMenuKeys;
begin
  RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\SystemFileAssociations\.mp4\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\SystemFileAssociations\.mkv\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\SystemFileAssociations\.avi\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\SystemFileAssociations\.mov\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\SystemFileAssociations\.webm\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\SystemFileAssociations\.m4v\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\SystemFileAssociations\.wav\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\SystemFileAssociations\.mp3\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\SystemFileAssociations\.flac\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\SystemFileAssociations\.m4a\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\SystemFileAssociations\.ogg\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\SystemFileAssociations\.png\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\SystemFileAssociations\.jpg\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\SystemFileAssociations\.bmp\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\SystemFileAssociations\.webp\shell\FFActions');

  RegDeleteKeyIncludingSubkeys(HKLM, 'Software\Classes\SystemFileAssociations\.mp4\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKLM, 'Software\Classes\SystemFileAssociations\.mkv\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKLM, 'Software\Classes\SystemFileAssociations\.avi\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKLM, 'Software\Classes\SystemFileAssociations\.mov\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKLM, 'Software\Classes\SystemFileAssociations\.webm\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKLM, 'Software\Classes\SystemFileAssociations\.m4v\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKLM, 'Software\Classes\SystemFileAssociations\.wav\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKLM, 'Software\Classes\SystemFileAssociations\.mp3\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKLM, 'Software\Classes\SystemFileAssociations\.flac\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKLM, 'Software\Classes\SystemFileAssociations\.m4a\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKLM, 'Software\Classes\SystemFileAssociations\.ogg\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKLM, 'Software\Classes\SystemFileAssociations\.png\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKLM, 'Software\Classes\SystemFileAssociations\.jpg\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKLM, 'Software\Classes\SystemFileAssociations\.jpeg\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKLM, 'Software\Classes\SystemFileAssociations\.bmp\shell\FFActions');
  RegDeleteKeyIncludingSubkeys(HKLM, 'Software\Classes\SystemFileAssociations\.webp\shell\FFActions');
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
  begin
    CleanupContextMenuKeys;
  end;
end;
