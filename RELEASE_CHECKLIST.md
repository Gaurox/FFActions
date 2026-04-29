# Release Checklist

## Before Tagging

- Confirm `README.md` version is correct
- Confirm `FFActions.iss` `AppVersion` is correct
- Rebuild actions with `.\build_all.ps1 -Version <version>`
- Compile the installer from `FFActions.iss`
- Verify a few representative actions still work after reinstall

## Source Repository Check

- Generated `.exe` files are ignored or excluded from the source commit
- FFmpeg binaries are not included in the source commit unless intentionally required
- Large local test files are not included in the source commit
- Temporary files are removed

## Release Artifacts

- Installer name is correct
- Release notes summarize new actions and fixes
- License information remains present for the project
- Third-party dependencies are documented

## Final Sanity Check

- Fresh clone can be understood from `README.md`
- Build scripts do not depend on machine-specific absolute paths
- Version shown in compiled executables matches the release version
