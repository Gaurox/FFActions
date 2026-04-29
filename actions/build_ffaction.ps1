param(
    [Parameter(Mandatory = $true)][string]$SharedFile,
    [Parameter(Mandatory = $true)][string]$TemplateFile,
    [Parameter(Mandatory = $true)][string]$OutputFile
)

$shared = Get-Content -LiteralPath $SharedFile -Raw -Encoding UTF8
$template = Get-Content -LiteralPath $TemplateFile -Raw -Encoding UTF8

$marker = '#__FFCOMMON_INJECT_HERE__'
if ($template.IndexOf($marker, [System.StringComparison]::Ordinal) -lt 0) {
    throw "Marker not found in template: $marker"
}

$result = $template.Replace($marker, $shared)
$targetPath = [System.IO.Path]::GetFullPath($OutputFile)
$encoding = New-Object System.Text.UTF8Encoding($false)

if (Test-Path -LiteralPath $targetPath) {
    $existing = Get-Content -LiteralPath $targetPath -Raw -Encoding UTF8
    if ($existing -ceq $result) {
        Write-Host "Build OK -> $OutputFile"
        return
    }
}

$maxAttempts = 5
for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    try {
        [System.IO.File]::WriteAllText($targetPath, $result, $encoding)
        break
    }
    catch {
        if ($attempt -eq $maxAttempts) {
            throw
        }

        Start-Sleep -Milliseconds 200
    }
}

Write-Host "Build OK -> $OutputFile"
