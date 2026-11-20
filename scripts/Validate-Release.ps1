[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$addonRoot = $repoRoot
$tocPath = Join-Path $addonRoot 'RaidThreeBags.toc'
$corePath = Join-Path $addonRoot 'RaidThreeBags.lua'
$stylePath = Join-Path $addonRoot 'RaidThreeUIStyle.lua'
$uiPath = Join-Path $addonRoot 'RTB_UI.lua'
$bankPath = Join-Path $addonRoot 'RTB_Bank.lua'
$repositoryLicensePath = Join-Path $repoRoot 'LICENSE'
$expectedVersion = '0.7.1'

foreach ($required in @(
    $tocPath,
    $corePath,
    $stylePath,
    $uiPath,
    $bankPath,
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
$expectedLoadOrder = @(
    'RaidThreeBags.lua',
    'RaidThreeUIStyle.lua',
    'RTB_UI.lua',
    'RTB_Bank.lua',
    'RTB_Prospect.lua',
    'RTB_Disenchant.lua'
)
if (($listedFiles -join "`n") -ne ($expectedLoadOrder -join "`n")) {
    throw "Unexpected TOC load order: $($listedFiles -join ', ')"
}
foreach ($relativePath in $listedFiles) {
    $candidate = Join-Path $addonRoot $relativePath.Trim()
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "TOC references a missing file: $relativePath"
    }
}

$style = Get-Content -LiteralPath $stylePath -Raw
$ui = Get-Content -LiteralPath $uiPath -Raw
$bank = Get-Content -LiteralPath $bankPath -Raw
foreach ($marker in @(
    'function Style:ApplySquareControl(button)',
    'function Style:CreateSquareIconChrome(button, texturePath)',
    'RaidThreeUIStyle = Style'
)) {
    if (-not $style.Contains($marker)) {
        throw "Required shared-style marker is missing: $marker"
    }
}
if (-not ($ui.Contains('local Style = assert(') -and $bank.Contains('local Style = assert('))) {
    throw 'Inventory and bank UI must both consume RaidThreeUIStyle.'
}

foreach ($marker in @(
    'RTB.BAG_IDS = { 0, 1, 2, 3, 4 }',
    'RTB.ITEM_AGE_SECONDS = 24 * 60 * 60',
    'function RTB:BuildInventorySortPlan(observedAt)',
    'local function SortItemsHierarchically(first, second)',
    'function RTB:InventorySortNeedsConsolidation(pools)',
    'function RTB:FindInventoryConsolidationMove(pools)',
    'function RTB:ContinueInventorySort()',
    'function RTB:SortInventory()',
    'RTB.SORT_TRACE_SCHEMA = 2',
    'RTB.SORT_TRACE_MAX_SESSIONS = 10',
    'function RTB:VerifyInventorySortTrace(trace)',
    'command == "sort" or command == "arrange"',
    'command == "sortlog status"'
)) {
    if (-not $core.Contains($marker)) {
        throw "Required inventory-sort marker is missing: $marker"
    }
}
foreach ($marker in @(
    'function RTB:CreateInventorySortButton()',
    '"RaidThreeBagsInventorySortButton"',
    'RTB:SortInventory()',
    'self.InventorySortButton = button'
)) {
    if (-not $ui.Contains($marker)) {
        throw "Required inventory-sort UI marker is missing: $marker"
    }
}

$behaviorTestText = Get-Content -LiteralPath $behaviorTest -Raw
foreach ($marker in @(
    'inventory sorting did not finish',
    'one-session consolidation and three-group arrangement failed',
    'successful sort trace was not persisted with complete lifecycle data',
    'sort trace verifier accepted changed item totals',
    'specialty bag sort crossed or misordered its family pool',
    'combat did not block sorting'
)) {
    if (-not $behaviorTestText.Contains($marker)) {
        throw "Required inventory-sort behavior test marker is missing: $marker"
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
    throw "README does not identify $expectedVersion as the current distribution candidate."
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
