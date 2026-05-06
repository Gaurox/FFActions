Project: FFActions



Description:

FFActions is a Windows tool using PowerShell 5.1 and FFmpeg.

Each action is a standalone .ps1 compiled to .exe (PS2EXE -noConsole -STA).

Actions are triggered via Windows right-click context menu.

All processing is local and offline.



Architecture:

\- actions/ → action scripts (.template.ps1)

\- actions/\_shared/ → shared helpers

\- tools/ffmpeg/ → ffmpeg.exe / ffprobe.exe

\- build\_ffaction.ps1 → builds individual actions

\- build\_all.ps1 → builds all actions



Core Principles:

\- Do NOT duplicate logic across scripts

\- Always reuse shared helpers when available

\- Keep each action script minimal and focused on its task

\- Do NOT refactor multiple files unless explicitly asked

\- Preserve existing behavior at all times



PowerShell Constraints:

\- PowerShell 5.1 ONLY

\- param(...) must be at the top of each script

\- Do NOT use modern PowerShell features incompatible with 5.1

\- Do NOT use ArgumentList

\- Do NOT use --%

\- Always handle paths with spaces correctly



FFmpeg Execution Rules:

\- Must use System.Diagnostics.Process

\- Required:

&#x20; - UseShellExecute = false

&#x20; - CreateNoWindow = true

&#x20; - RedirectStandardOutput = true

&#x20; - RedirectStandardError = true

\- Arguments must be passed as a properly quoted string

\- Never call ffmpeg directly in console mode



File Safety:

\- NEVER overwrite existing files

\- ALWAYS generate unique output names (suffix \_001, \_002, etc.)

\- ALWAYS clean partial output files on failure



Shared Helpers Usage:

\- ffcommon\_core.ps1:

&#x20; - process execution

&#x20; - argument quoting

&#x20; - tool path resolution

&#x20; - unique output naming

&#x20; - error handling



\- ffcommon\_progress.ps1:

&#x20; - progress window

&#x20; - FFmpeg progress parsing

&#x20; - cancel handling



\- ffcommon\_media.ps1 (if present):

&#x20; - media info (duration, resolution, fps)

&#x20; - time parsing and formatting



\- ffcommon\_picker.ps1 (if present):

&#x20; - format selection UI

&#x20; - launching target actions



Rules for Shared Code:

\- Only place logic in \_shared if:

&#x20; - used by multiple scripts

&#x20; - or critical to centralize (process, errors, naming)

\- Shared functions may be:

&#x20; - strictly identical

&#x20; - or parameterized for reuse

\- Do NOT move highly specific logic into shared files



UI Guidelines:

\- Windows Forms only

\- No console window

\- Simple, stable UI

\- Avoid flickering

\- Reuse UI patterns when possible



Refactoring Rules:

\- Refactor ONE file at a time unless explicitly asked

\- Do NOT change architecture

\- Do NOT introduce new dependencies

\- Do NOT break compatibility with existing build system

\- Prefer small, safe improvements



When Implementing New Features:

\- Always check if shared helpers already provide the needed logic

\- Reuse existing patterns (convert, extract, resize, etc.)

\- Do NOT rewrite process or FFmpeg logic

\- Keep consistency with existing scripts



Expected Behavior:

\- All actions must:

&#x20; - run silently (no console)

&#x20; - handle errors cleanly

&#x20; - generate valid output files

&#x20; - be robust with all input paths

