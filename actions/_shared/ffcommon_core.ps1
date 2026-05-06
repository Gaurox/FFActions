if (-not (Get-Command -Name 'Show-Error' -CommandType Function -ErrorAction SilentlyContinue)) {
function Show-Error {
    param([string]$Message)

    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        'FFActions - Error',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}
}

if (-not (Get-Command -Name 'Get-AppRoot' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-AppRoot {
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $exeDir = Split-Path -Parent $exePath
    return Split-Path -Parent $exeDir
}
}

if (-not (Get-Command -Name 'Get-ToolPath' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-ToolPath {
    param([Parameter(Mandatory = $true)][string]$ToolName)

    $appRoot = Get-AppRoot
    return Join-Path $appRoot "tools\ffmpeg\$ToolName"
}
}

if (-not (Get-Command -Name 'Quote-ProcessArgument' -CommandType Function -ErrorAction SilentlyContinue)) {
function Quote-ProcessArgument {
    param([string]$Value)

    if ($null -eq $Value) {
        return ''
    }

    if ($Value -eq '') {
        return '""'
    }

    if ($Value -notmatch '[\s"]') {
        return $Value
    }

    $escaped = $Value -replace '(\\*)"', '$1$1\\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}
}

if (-not (Get-Command -Name 'Join-ProcessArguments' -CommandType Function -ErrorAction SilentlyContinue)) {
function Join-ProcessArguments {
    param([object[]]$Arguments)

    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($arg in $Arguments) {
        if ($null -eq $arg) { continue }
        $text = [string]$arg
        if ($text -eq '') { continue }
        $parts.Add((Quote-ProcessArgument -Value $text))
    }

    return ($parts -join ' ')
}
}

if (-not (Get-Command -Name 'Invoke-HiddenProcess' -CommandType Function -ErrorAction SilentlyContinue)) {
function Invoke-HiddenProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][object[]]$Arguments
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = Join-ProcessArguments -Arguments $Arguments
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    [void]$process.Start()

    $stdOut = $process.StandardOutput.ReadToEnd()
    $stdErr = $process.StandardError.ReadToEnd()

    $process.WaitForExit()
    $exitCode = $process.ExitCode
    $process.Dispose()

    return [PSCustomObject]@{
        ExitCode = $exitCode
        StdOut   = $stdOut
        StdErr   = $stdErr
    }
}
}

if (-not (Get-Command -Name 'Get-UniqueOutputPath' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-UniqueOutputPath {
    param([Parameter(Mandatory = $true)][string]$DesiredPath)

    if (-not (Test-Path -LiteralPath $DesiredPath)) {
        return $DesiredPath
    }

    $dir = Split-Path -Parent $DesiredPath
    $base = [System.IO.Path]::GetFileNameWithoutExtension($DesiredPath)
    $ext = [System.IO.Path]::GetExtension($DesiredPath)

    for ($i = 1; $i -le 999; $i++) {
        $candidate = Join-Path $dir ("{0}_{1:D3}{2}" -f $base, $i, $ext)
        if (-not (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    throw 'Unable to create a unique output filename.'
}
}

if (-not (Get-Command -Name 'Remove-PartialOutput' -CommandType Function -ErrorAction SilentlyContinue)) {
function Remove-PartialOutput {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (Test-Path -LiteralPath $Path) {
        try { Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue } catch {}
    }
}
}

if (-not (Get-Command -Name 'Get-ShortErrorTextFromFfmpeg' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-ShortErrorTextFromFfmpeg {
    param(
        [string]$StdErr,
        [string]$FallbackMessage = 'FFmpeg failed during processing.'
    )

    if (-not [string]::IsNullOrWhiteSpace($StdErr)) {
        $lowerText = $StdErr.ToLowerInvariant()
        $friendlyMessage = $null

        if ($lowerText -match 'no space left|disk full|not enough space') {
            $friendlyMessage = 'There is not enough free disk space to create the output file.'
        } elseif ($lowerText -match 'permission denied|access is denied|cannot open output file|error opening output file|read-only file system') {
            $friendlyMessage = 'FFActions could not write the output file. Check permissions or whether the file is already open.'
        } elseif ($lowerText -match 'encrypted|decryption|invalid key|drm') {
            $friendlyMessage = 'This file appears to be protected, encrypted, or unreadable without a decryption key.'
        } elseif ($lowerText -match 'stream map .*matches no streams|does not contain any stream|output file does not contain any stream|cannot find a matching stream|no streams to mux') {
            $friendlyMessage = 'No usable audio, video, or image stream was found in this file.'
        } elseif ($lowerText -match 'encoder .*not found|decoder .*not found|unknown encoder|unknown decoder|unsupported codec|codec not currently supported|could not find tag for codec') {
            $friendlyMessage = 'The codec used by this file is not supported by the bundled FFmpeg.'
        } elseif ($lowerText -match 'invalid data found when processing input|no jpeg data found|not a jpeg file|invalid png|moov atom not found|header missing|end of file|truncated|corrupt|crc mismatch|decode error|error while decoding|error submitting packet|could not find codec parameters|cannot determine format') {
            $friendlyMessage = 'This file appears to be corrupted, incomplete, or unreadable.'
        } elseif ($lowerText -match 'invalid argument|error initializing filter|failed to configure input pad|height not divisible by|width not divisible by|invalid too big or non positive size') {
            $friendlyMessage = 'The selected settings are not compatible with this file.'
        }

        if (-not [string]::IsNullOrWhiteSpace($friendlyMessage)) {
            $detail = ($StdErr -split "`r?`n" | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1)
            if (-not [string]::IsNullOrWhiteSpace($detail)) {
                if ($detail.Length -gt 180) {
                    $detail = $detail.Substring(0, 180) + '...'
                }
                return $friendlyMessage + "`r`n`r`nTechnical detail: " + $detail
            }

            return $friendlyMessage
        }

        $lastLines = ($StdErr -split "`r?`n" | Where-Object { $_.Trim() -ne '' } | Select-Object -Last 3) -join "`r`n"
        if (-not [string]::IsNullOrWhiteSpace($lastLines)) {
            return "FFmpeg failed:`r`n" + $lastLines
        }
    }

    return $FallbackMessage
}
}

if (-not (Get-Command -Name 'Get-ShortErrorText' -CommandType Function -ErrorAction SilentlyContinue)) {
function Get-ShortErrorText {
    param(
        [string]$StdErr,
        [string]$FallbackMessage = 'FFmpeg failed during processing.'
    )

    return Get-ShortErrorTextFromFfmpeg -StdErr $StdErr -FallbackMessage $FallbackMessage
}
}
