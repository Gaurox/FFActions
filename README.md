# FFActions

Version: `1.2.1`

---

# OVERVIEW

FFActions is a Windows tool that adds simple right-click actions to quickly process multimedia files.

It is not meant to replace full editing, encoding, or retouching software. FFActions is designed for fast everyday operations, with simple interfaces and limited settings, so common tasks can be completed without opening a large application or navigating through advanced options.

The general idea is intentionally simple: short dialogs, focused options, and output files created next to the original source file.

---

# HOW IT WORKS

FFActions integrates into the Windows context menu for supported video, audio, and image formats.

Each command launches a standalone tool based on PowerShell and FFmpeg. Every operation creates a new file next to the source file and does not overwrite the original.

For format-based actions such as convert and audio extraction, FFActions now uses small picker windows instead of large nested format submenus. The installer rewires these entries directly to the picker executables so Explorer opens the compact button dialog immediately.

Menu overview:

![Video Menu](screenshots/MenuVideo.png)
![Audio Menu](screenshots/MenuAudio.png)
![Image Menu](screenshots/MenuImage.png)

The installer offers these modules:

- Video
- Audio
- Image

## Recent 1.2.1 improvements

- `Cut video` now uses a live preview, a dual-handle timeline, and synchronized frame and time inputs.
- `Rotate / flip image` now uses a visual preview with direct transform buttons and reset.
- `Rotate / flip video` now follows the same visual workflow, with frame preview and slider.
- `Convert video`, `convert audio`, `convert image`, and `extract audio` now use compact centered format pickers with direct-click buttons, wired directly from the installed context menu.
- `Compress audio`, `compress image`, `crop video`, and the small picker dialogs received layout fixes for cut text and tighter spacing.

---

# VIDEO FEATURES

## Cut Video

Visual cutting tool with a live video preview, a double-handle timeline, and synchronized frame and time fields for precise start and end selection.

Formats: `mp4 mkv avi mov webm m4v`

![Cut Video](screenshots/CutVideo.jpg)

## Interpolate

Increase motion smoothness by generating intermediate frames.

Formats: `mp4 mkv avi mov webm m4v`

![Interpolate](screenshots/Interpolate.jpg)

## Remove Audio

Remove the audio track from a video.

Formats: `mp4 mkv avi mov webm m4v`

## Extract Audio

Extract the audio track from a video.

The action opens a small centered format picker with direct click buttons, then launches the extraction.

Input formats: `mp4 mkv avi mov webm m4v`

Output formats: `mp3 wav flac m4a ogg`

![Extract Audio](screenshots/ExtractAudio.jpg)

## Create GIF

Create a GIF from a video with simple presets for resolution, FPS and quality.

Formats: `mp4 mkv avi mov webm m4v`

![Create GIF](screenshots/CreateGif.jpg)

## Resize Video

Resize a video using pixels or percentage.

Options: width/height in px, width/height in %, keep ratio, presets `x0.5 x0.75 x1.5 x2 x4`

Formats: `mp4 mkv avi mov webm m4v`

![Resize Video](screenshots/ResizeVideo.jpg)

## Crop Video

Visual crop tool with frame preview and a timeline slider to inspect another moment of the video before applying one fixed crop to the full file.

Options: free, square, `16:9`, `9:16`, `4:3`, timeline preview, center, reset

Formats: `mp4 mkv avi mov webm m4v`

![Crop Video](screenshots/CropVideo.jpg)

## Rotate / Flip Video

Visual rotate and mirror tool with live frame preview, frame slider, reset button, and direct transform buttons.

Options: rotation left, rotation right, mirror horizontal, mirror vertical

Formats: `mp4 mkv avi mov webm m4v`

![Rotate Flip Video](screenshots/RotateFlipVideo.jpg)

## Compress Video

Compress a video with simple quality presets.

Options: `High quality Balanced Small file`, optional target size

Formats: `mp4 mkv avi mov webm m4v`

![Compress Video](screenshots/CompressVideo.jpg)

## Convert Video

Convert a video from one format to another.

The action opens a small centered format picker with direct click buttons, then launches the conversion.

Input/output formats: `mp4 mkv avi mov webm m4v`

![Convert Video](screenshots/ConvertVideo.jpg)

---

# AUDIO FEATURES

## Cut Audio

Quickly trim an audio file.

Formats: `mp3 wav flac m4a ogg`

![Cut Audio](screenshots/CutAudio.jpg)

## Convert Audio

Convert an audio file from one format to another.

The action opens a small centered format picker with direct click buttons, then launches the conversion.

Input/output formats: `mp3 wav flac m4a ogg`

![Convert Audio](screenshots/ConvertAudio.jpg)

## Change Speed

Adjust playback speed.

Options: percentage, target duration, pitch preservation

Formats: `mp3 wav flac m4a ogg`

![Change Speed](screenshots/ChangeAudioSpeed.jpg)

## Change Pitch

Adjust audio pitch.

Options: semitones, percentage, duration preservation

Formats: `mp3 wav flac m4a ogg`

![Change Pitch](screenshots/ChangeAudioPitch.jpg)

## Reverse Audio

Reverse an audio file so it plays backward.

Formats: `mp3 wav flac m4a ogg`

## Compress Audio

Compress an audio file with simple quality presets.

Options: `High quality Balanced Small file`, optional target size

Formats: `mp3 wav flac m4a ogg`

![Compress Audio](screenshots/CompressAudio.jpg)

---

# IMAGE FEATURES

## Resize Image

Resize an image using pixels or percentage.

Options: width/height in px, width/height in %, keep ratio, presets `x0.5 x0.75 x1.5 x2 x4`

Formats: `png jpg jpeg webp bmp`

![Resize Image](screenshots/ResizeImage.jpg)

## Convert Image

Convert an image from one format to another.

The action opens a small centered format picker with direct click buttons, then launches the conversion.

Input formats: `png jpg jpeg webp bmp`

Output formats: `png jpg webp bmp`

![Convert Image](screenshots/ConvertImage.jpg)

## Compress Image

Compress an image using several quality levels.

Options: `High quality Balanced Small file`, optional target size, output `png jpg webp`

Formats: `png jpg jpeg webp bmp`

![Compress Image](screenshots/CompressImage.jpg)

## Rotate / Flip Image

Visual rotate and mirror tool with live preview, reset button, and direct transform buttons.

Options: rotation left, rotation right, mirror horizontal, mirror vertical

Formats: `png jpg jpeg webp bmp`

![Rotate Flip Image](screenshots/RotateFlipImage.jpg)

## Crop Image

Visual crop tool with live preview.

Options: free, square, `16:9`, `9:16`, `4:3`, center, reset

Formats: `png jpg jpeg webp bmp`

![Crop Image](screenshots/CropImage.jpg)

## Convert to Icon

Generate an `.ico` file from an image.

Options: sizes `16 24 32 48 64 128 256`, modes `Fit Fill`, background `transparent white black`

Input formats: `png jpg jpeg webp bmp`

Output formats: `ico`

![Convert To Icon](screenshots/ConvertToIcon.jpg)

---

# USING THE SCRIPTS WITHOUT THE INSTALLER

This method is useful if you want to review the code, inspect the scripts, or run the tools manually without executing the Windows installer.

## What To Know First

Not every action is stored directly as a final ready-to-run script. A large part of the project is built around:

- template files in `actions\*.template.ps1`
- a shared common file in `actions\_shared\ffcommon_progress.ps1`
- a build script that combines them into usable final scripts

In practice, the flow is:

`template .ps1` -> `generated .ps1 script` -> `manual execution` or `compiled .exe`

## Requirements

Before running any action without the installer, make sure these files exist:

```text
tools/ffmpeg/ffmpeg.exe
tools/ffmpeg/ffprobe.exe
```

You should also open PowerShell in the project root folder, the one that contains `build_all.ps1` and `FFActions.iss`.

## Generate One Script

If you only want to test one feature, you can generate that final script directly from its template.

Example with `resize_image`:

```powershell
powershell -ExecutionPolicy Bypass -File .\actions\build_ffaction.ps1 -SharedFile .\actions\_shared\ffcommon_progress.ps1 -TemplateFile .\actions\resize_image.template.ps1 -OutputFile .\actions\resize_image.ps1
```

This command takes:

- the shared common block
- the action template
- then produces a final script that is ready to run

## Run A Script Manually

Once the final script has been generated, you can launch it directly and pass the file to process as an argument.

Example:

```powershell
powershell -ExecutionPolicy Bypass -STA -File .\actions\resize_image.ps1 "C:\path\to\image.png"
```

The `-STA` mode is important for actions that open a Windows Forms interface.

## Rebuild All Scripts

If you want to rebuild every action in the project at once, use:

```powershell
.\build_all.ps1
```

This regenerates the scripts and can also rebuild the executables if the required build chain is available on the machine.

## Build Requirements

For full local builds, the project expects:

- PowerShell
- `Invoke-PS2EXE` available in the local environment
- Inno Setup for installer builds
- local FFmpeg binaries in `tools/ffmpeg/`

Example to rebuild all local executables:

```powershell
.\build_all.ps1 -Version 1.2.1
```

Example to build the installer after that:

```text
Open FFActions.iss with Inno Setup and compile the installer
```

## If You Never Want To Run The Installer

You can fully work with the project by:

1. reading the templates inside `actions\`
2. generating only the scripts you want to inspect or test
3. running those scripts manually on test files
4. reviewing the FFmpeg commands before execution

In other words, the installer is convenient for Windows right-click integration, but it is not required to audit or use the code.

---

# INSTALLATION

The standard installation uses Inno Setup.

It registers the Windows context menu entries and allows module selection by category:

- Video
- Audio
- Image

Main script:

```text
FFActions.iss
```

Release note:

Compiled installers and generated executables are better distributed through GitHub Releases than committed to the source repository.

---

# LIMITATIONS

FFActions is designed for speed and simplicity.

Advanced codec tuning, fine bitrate control, color profiles, subtitles, complex metadata, multi-track editing, and professional workflows are outside the intended scope of the project.

For advanced or highly precise work, a dedicated tool is a better choice.

---

# DEPENDENCIES

FFActions mainly relies on FFmpeg and FFprobe.

FFmpeg license information:

[https://ffmpeg.org/legal.html](https://ffmpeg.org/legal.html)

---

# LICENSE

FFActions source code is distributed under the MIT License.

See [LICENSE](LICENSE).

Third-party dependencies keep their own licenses.
