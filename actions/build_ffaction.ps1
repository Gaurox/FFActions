param(
    [string[]]$SharedFile = @(),
    [Parameter(Mandatory = $true)][string]$TemplateFile,
    [Parameter(Mandatory = $true)][string]$OutputFile
)

$sharedParts = New-Object System.Collections.Generic.List[string]
foreach ($path in $SharedFile) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        continue
    }

    $sharedParts.Add((Get-Content -LiteralPath $path -Raw -Encoding UTF8))
}

$shared = ($sharedParts.ToArray() -join "`r`n`r`n")
$template = Get-Content -LiteralPath $TemplateFile -Raw -Encoding UTF8

$marker = '#__FFCOMMON_INJECT_HERE__'

if ($template.IndexOf($marker, [System.StringComparison]::Ordinal) -ge 0) {
    $result = $template.Replace($marker, $shared)
}
else {
    $result = $template
}

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
