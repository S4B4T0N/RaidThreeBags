[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$addonRoot = Join-Path $repoRoot 'RaidThreeBags'
$tocPath = Join-Path $addonRoot 'RaidThreeBags.toc'
$corePath = Join-Path $addonRoot 'RaidThreeBags.lua'
$repositoryLicensePath = Join-Path $repoRoot 'LICENSE'
$addonLicensePath = Join-Path $addonRoot 'LICENSE'

foreach ($required in @(
    $tocPath,
    $corePath,
    $repositoryLicensePath,
    $addonLicensePath
)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Missing required file: $required"
    }
}

$repositoryLicense = (
    Get-Content -LiteralPath $repositoryLicensePath -Raw
) -replace "`r`n", "`n"
$addonLicense = (
    Get-Content -LiteralPath $addonLicensePath -Raw
) -replace "`r`n", "`n"
if (-not [string]::Equals(
    $repositoryLicense,
    $addonLicense,
    [System.StringComparison]::Ordinal
)) {
    throw 'Repository and installable-addon LICENSE files differ.'
}

$behaviorTest = Join-Path $repoRoot 'tests\SettingsLogicMock.lua'
if (-not (Test-Path -LiteralPath $behaviorTest -PathType Leaf)) {
    throw "Missing behavior test: $behaviorTest"
}

$toc = Get-Content -LiteralPath $tocPath
$tocVersion = ($toc | Where-Object { $_ -match '^## Version:\s*(.+)$' } |
    ForEach-Object { $Matches[1].Trim() } | Select-Object -First 1)
$tocLicense = ($toc | Where-Object { $_ -match '^## X-License:\s*(.+)$' } |
    ForEach-Object { $Matches[1].Trim() } | Select-Object -First 1)
if ($tocLicense -ne 'MIT') {
    throw "TOC license mismatch: expected 'MIT', found '$tocLicense'."
}

$core = Get-Content -LiteralPath $corePath -Raw
$coreMatch = [regex]::Match($core, 'RTB\.VERSION\s*=\s*"([^"]+)"')
if (-not $tocVersion -or -not $coreMatch.Success -or $tocVersion -ne $coreMatch.Groups[1].Value) {
    throw "Version mismatch: TOC='$tocVersion', core='$($coreMatch.Groups[1].Value)'"
}

$listedFiles = $toc | Where-Object {
    $_ -and -not $_.StartsWith('##') -and -not $_.StartsWith('#')
}
foreach ($relativePath in $listedFiles) {
    $candidate = Join-Path $addonRoot $relativePath.Trim()
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "TOC references a missing file: $relativePath"
    }
}

$forbiddenFiles = Get-ChildItem -LiteralPath $repoRoot -Recurse -File | Where-Object {
    $_.Name -match '^\.env($|\.)|SavedVariables' -or
    $_.FullName -match '\\(__pycache__|WTF|Cache)\\'
}
if ($forbiddenFiles) {
    throw "Forbidden local-state files found: $($forbiddenFiles.FullName -join ', ')"
}

$addonTextFiles = Get-ChildItem -LiteralPath $addonRoot -Recurse -File |
    Where-Object { $_.Extension -in '.lua', '.toc', '.xml' }
foreach ($file in $addonTextFiles) {
    $branding = Select-String -LiteralPath $file.FullName -Pattern 'Warmane|ChromieCraft|S4B4T0N_AI'
    if ($branding) {
        throw "Forbidden server-specific or legacy branding in $($file.FullName):$($branding.LineNumber)"
    }
    $staleVersion = Select-String -LiteralPath $file.FullName -Pattern '\b0\.3\.10\b'
    if ($staleVersion) {
        throw "Stale addon version in $($file.FullName):$($staleVersion.LineNumber)"
    }
}

$allTextFiles = Get-ChildItem -LiteralPath $repoRoot -Recurse -File |
    Where-Object { $_.Extension -in '.lua', '.toc', '.md', '.ps1', '.txt' }
foreach ($file in $allTextFiles) {
    $secret = Select-String -LiteralPath $file.FullName -Pattern 'https://(?:discord(?:app)?\.com)/api/webhooks/'
    if ($secret) {
        throw "Credential pattern in $($file.FullName):$($secret.LineNumber)"
    }
}

Write-Host "RaidThreeBags $tocVersion static release validation passed."
