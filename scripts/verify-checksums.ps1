[CmdletBinding()]
param(
    [string]$ManifestPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $repositoryRoot 'SHA256SUMS'
}
$manifest = Resolve-Path -LiteralPath $ManifestPath
$failed = $false

foreach ($line in Get-Content -LiteralPath $manifest -Encoding UTF8) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
        continue
    }

    if ($line -notmatch '^([0-9a-fA-F]{64})\s{2}(.+)$') {
        Write-Error "Cannot parse manifest line: $line"
    }

    $expectedHash = $Matches[1].ToLowerInvariant()
    $relativePath = $Matches[2].Replace('/', [IO.Path]::DirectorySeparatorChar)
    $targetPath = Join-Path $repositoryRoot $relativePath

    if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
        Write-Warning "Missing file: $relativePath"
        $failed = $true
        continue
    }

    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $targetPath).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        Write-Warning "Checksum mismatch: $relativePath"
        $failed = $true
        continue
    }

    Write-Host "OK: $relativePath"
}

if ($failed) {
    throw 'One or more files failed checksum validation.'
}

Write-Host 'All files passed checksum validation.'
