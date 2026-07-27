[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$addonRoot = $repoRoot
$tocPath = Join-Path $addonRoot 'RaidThreeBags.toc'
$corePath = Join-Path $addonRoot 'RaidThreeBags.lua'
$repositoryLicensePath = Join-Path $repoRoot 'LICENSE'
$expectedVersion = '0.4.1'

foreach ($required in @(
    $tocPath,
    $corePath,
    $repositoryLicensePath
)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Missing required file: $required"
    }
}

$legacyNestedToc = Join-Path $repoRoot 'RaidThreeBags\RaidThreeBags.toc'
if (Test-Path -LiteralPath $legacyNestedToc) {
    throw "Legacy nested addon layout found: $legacyNestedToc"
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
if ($tocVersion -ne $expectedVersion) {
    throw "TOC version mismatch: expected '$expectedVersion', found '$tocVersion'."
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

$addonTextFiles = @(
    Get-Item -LiteralPath $tocPath
    foreach ($relativePath in $listedFiles) {
        Get-Item -LiteralPath (Join-Path $addonRoot $relativePath.Trim())
    }
) | Where-Object { $_.Extension -in '.lua', '.toc', '.xml' }
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

$readmePath = Join-Path $repoRoot 'README.md'
$changelogPath = Join-Path $repoRoot 'CHANGELOG.md'
$readme = Get-Content -LiteralPath $readmePath -Raw
$changelog = Get-Content -LiteralPath $changelogPath -Raw
if ($readme -notmatch [regex]::Escape("``$expectedVersion``")) {
    throw "README does not identify $expectedVersion as the current release."
}
if ($changelog -notmatch "(?m)^##\s+$([regex]::Escape($expectedVersion))\s+-") {
    throw "CHANGELOG is missing the current $expectedVersion heading."
}

$allTextFiles = Get-ChildItem -LiteralPath $repoRoot -Recurse -File |
    Where-Object { $_.Extension -in '.lua', '.toc', '.md', '.ps1', '.txt' }
foreach ($file in $allTextFiles) {
    $secret = Select-String -LiteralPath $file.FullName -Pattern 'https://(?:discord(?:app)?\.com)/api/webhooks/'
    if ($secret) {
        throw "Credential pattern in $($file.FullName):$($secret.LineNumber)"
    }
}

$warperiaLayoutTest = Join-Path $PSScriptRoot 'Test-WarperiaGitHubLayout.ps1'
if (-not (Test-Path -LiteralPath $warperiaLayoutTest -PathType Leaf)) {
    throw "Missing Warperia layout test: $warperiaLayoutTest"
}
& $warperiaLayoutTest

Write-Host "RaidThreeBags $tocVersion static release validation passed."
