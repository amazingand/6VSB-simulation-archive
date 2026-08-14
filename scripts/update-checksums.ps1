[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$Path,

    [string]$ManifestPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $repositoryRoot 'SHA256SUMS'
}

$entries = [ordered]@{}
if (Test-Path -LiteralPath $ManifestPath -PathType Leaf) {
    foreach ($line in Get-Content -LiteralPath $ManifestPath) {
        if ($line -match '^([0-9a-fA-F]{64})\s{2}(.+)$') {
            $entries[$Matches[2]] = $Matches[1].ToLowerInvariant()
        }
    }
}

$files = foreach ($itemPath in $Path) {
    $resolved = Resolve-Path -LiteralPath $itemPath
    $item = Get-Item -LiteralPath $resolved
    if ($item.PSIsContainer) {
        Get-ChildItem -LiteralPath $item.FullName -Recurse -Force -File
    }
    else {
        $item
    }
}

foreach ($file in ($files | Sort-Object FullName -Unique)) {
    if (-not $file.FullName.StartsWith($repositoryRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside the repository: $($file.FullName)"
    }

    $relativePath = $file.FullName.Substring($repositoryRoot.Length).TrimStart('\').Replace('\', '/')
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
    $entries[$relativePath] = $hash
    Write-Host "Hashed: $relativePath"
}

$lines = @($entries.Keys | Sort-Object | ForEach-Object { '{0}  {1}' -f $entries[$_], $_ })
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllLines($ManifestPath, $lines, $utf8WithoutBom)
Write-Host "Updated manifest: $ManifestPath"
