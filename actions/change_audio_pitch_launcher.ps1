param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile
)

function Get-ScriptPath {
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $exeDir = Split-Path -Parent $exePath
    return Join-Path $exeDir 'change_audio_pitch.ps1'
}

function Quote-ProcessArgument {
    param([string]$Value)

    if ($null -eq $Value -or $Value -eq '') {
        return '""'
    }

    if ($Value -notmatch '[\s"]') {
        return $Value
    }

    $escaped = $Value -replace '(\\*)"', '$1$1\\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function Join-ProcessArguments {
    param([object[]]$Arguments)

    return (($Arguments | ForEach-Object {
        Quote-ProcessArgument ([string]$_)
    }) -join ' ')
}

$scriptPath = Get-ScriptPath
if (-not (Test-Path -LiteralPath $scriptPath)) {
    [System.Windows.Forms.MessageBox]::Show(
        'change_audio_pitch.ps1 not found next to the executable.',
        'FFActions - Error',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = 'powershell.exe'
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.Arguments = Join-ProcessArguments @(
    '-ExecutionPolicy', 'Bypass',
    '-STA',
    '-File', $scriptPath,
    $InputFile
)

$process = [System.Diagnostics.Process]::Start($psi)
$process.WaitForExit()
exit $process.ExitCode
