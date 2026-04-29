# Contributing

Thanks for contributing to FFActions.

## Scope

FFActions focuses on simple right-click multimedia actions for Windows. Please keep changes aligned with that goal: fast workflows, short dialogs, and practical defaults.

## Source Layout

- `actions/*.template.ps1`: action templates
- `actions/_shared/ffcommon_progress.ps1`: shared code injected into templates
- `actions/build_ffaction.ps1`: template assembler
- `build_all.ps1`: local build script for generated scripts and executables
- `FFActions.iss`: Inno Setup installer script

## Before Sending Changes

1. Test the affected action locally.
2. Regenerate the related script or executable if needed.
3. Keep output files next to the source file and never overwrite originals.
4. Avoid introducing machine-specific absolute paths.

## Do Not Commit

- local FFmpeg binaries
- generated `.exe` files unless intentionally publishing release artifacts
- temporary files
- local test exports
- installer output files

## Build Notes

- `build_all.ps1` expects `Invoke-PS2EXE` to be available locally.
- The installer requires Inno Setup.
- FFmpeg and FFprobe should be available in `tools/ffmpeg/` for local testing.
