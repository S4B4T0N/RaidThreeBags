[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$mainFolderName = 'RaidThreeBags'
$expectedTocName = 'RaidThreeBags.toc'
$tempBase = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::GetTempPath()
).TrimEnd('\')
$testRoot = Join-Path $tempBase (
    'RaidThreeBags-Warperia-' + [guid]::NewGuid().ToString('N')
)

New-Item -ItemType Directory -Path $testRoot | Out-Null

try {
    $installPath = Join-Path $testRoot 'Interface\AddOns'
    $archiveRoot = Join-Path $installPath 'S4B4T0N-RaidThreeBags-archive'
    New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null

    $sourceFiles = Get-ChildItem -LiteralPath $repoRoot -Recurse -File |
        Where-Object { $_.FullName -notmatch '\\\.git\\' }
    foreach ($sourceFile in $sourceFiles) {
        $sourcePath = $sourceFile.FullName
        $relativePath = $sourcePath.Substring($repoRoot.Length).TrimStart('\')
        $destinationPath = Join-Path $archiveRoot $relativePath
        $destinationParent = Split-Path -Parent $destinationPath
        New-Item -ItemType Directory -Path $destinationParent -Force |
            Out-Null
        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath
    }

    $expectedFolders = @($mainFolderName)
    $directDirectories = Get-ChildItem -LiteralPath $archiveRoot -Directory
    $matchCount = @(
        $directDirectories |
            Where-Object { $expectedFolders -contains $_.Name }
    ).Count
    if ($matchCount -ge 2) {
        throw 'Unexpected multi-folder path selected for a single-folder addon.'
    }

    $finalFolder = Join-Path $installPath $mainFolderName
    Move-Item -LiteralPath $archiveRoot -Destination $finalFolder

    $tocPath = Join-Path $finalFolder $expectedTocName
    if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
        throw "Warperia simulation did not produce the expected TOC: $tocPath"
    }

    $nestedToc = Join-Path $finalFolder (
        "$mainFolderName\$expectedTocName"
    )
    if (Test-Path -LiteralPath $nestedToc) {
        throw "Warperia simulation produced a nested TOC: $nestedToc"
    }

    $toc = Get-Content -LiteralPath $tocPath
    $listedFiles = $toc | Where-Object {
        $_ -and -not $_.StartsWith('##') -and -not $_.StartsWith('#')
    }
    foreach ($relativePath in $listedFiles) {
        $installedPath = Join-Path $finalFolder $relativePath.Trim()
        if (-not (Test-Path -LiteralPath $installedPath -PathType Leaf)) {
            throw "Warperia simulation is missing: $relativePath"
        }
    }

    Write-Host (
        'Warperia GitHub layout simulation passed: ' +
        'Interface\AddOns\RaidThreeBags\RaidThreeBags.toc'
    )
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolvedTestRoot = (Resolve-Path -LiteralPath $testRoot).Path
        $expectedPrefix = $tempBase + '\RaidThreeBags-Warperia-'
        if (-not $resolvedTestRoot.StartsWith(
            $expectedPrefix,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            throw "Refusing to remove unexpected test path: $resolvedTestRoot"
        }
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
