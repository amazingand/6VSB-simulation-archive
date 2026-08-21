[CmdletBinding()]
param(
    [Parameter()]
    [string]$WorktreeRoot = 'D:\database\6VSB-worktrees\restructure-cprime-history-2026-08-17',

    [Parameter()]
    [string]$PackageRoot = 'D:\database\6VSB\Cprime_migration_20260815',

    [Parameter()]
    [string]$AuditRoot = 'D:\database\6VSB\work\archive_audit_20260817_r2'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Utf8LfFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [AllowEmptyCollection()][string[]]$Lines = @()
    )

    $normalized = @($Lines | ForEach-Object { ([string]$_).Replace("`r`n", "`n").Replace("`r", "`n") })
    $content = if ($normalized.Count -eq 0) { '' } else { ($normalized -join "`n") + "`n" }
    [System.IO.File]::WriteAllText($Path, $content, [System.Text.UTF8Encoding]::new($false))
}

function Write-Tsv {
    param([string]$Path, [string[]]$Headers, [object[]]$Rows)
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add(($Headers -join "`t"))
    foreach ($row in $Rows) {
        $values = foreach ($header in $Headers) {
            ([string]$row.$header).Replace("`t", ' ').Replace("`r", ' ').Replace("`n", ' ')
        }
        $lines.Add(($values -join "`t"))
    }
    Write-Utf8LfFile -Path $Path -Lines $lines
}

function Write-Manifest {
    param([string]$Root)
    $rows = @(
        Get-ChildItem -LiteralPath $Root -File -Recurse |
            Where-Object Name -ne 'MANIFEST.tsv' |
            Sort-Object FullName |
            ForEach-Object {
                [pscustomobject]@{
                    relative_path = $_.FullName.Substring($Root.Length + 1).Replace('\', '/')
                    bytes = $_.Length
                    sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
                }
            }
    )
    Write-Tsv -Path (Join-Path $Root 'MANIFEST.tsv') -Headers @('relative_path', 'bytes', 'sha256') -Rows $rows
}

$worktree = [System.IO.Path]::GetFullPath($WorktreeRoot)
$package = [System.IO.Path]::GetFullPath($PackageRoot)
$audit = [System.IO.Path]::GetFullPath($AuditRoot)
$archive = Join-Path $worktree 'history'
$extractedRows = Import-Csv -LiteralPath (Join-Path $audit 'reports\EXTRACTED_FILES.csv')

$s0Definitions = @(
    [pscustomobject]@{ Hash = 'c690db985aa83b89b0863a7ac0a9069b0f1cbaef36ab9570529ff4e277f6ec74'; System = 'cleaved'; Job = 'charmm-gui-8643876985' },
    [pscustomobject]@{ Hash = '29509aa6a105b707ab9fb6b9065eb6cd3199cdb23a589372f9e9b699b18ee6a5'; System = 'uncleaved'; Job = 'charmm-gui-8644096179' }
)
$s0Rows = [System.Collections.Generic.List[object]]::new()
foreach ($definition in $s0Definitions) {
    foreach ($row in $extractedRows | Where-Object container_sha256 -eq $definition.Hash | Sort-Object normalized_path) {
        $currentRelative = "simulations/construct-X/$($definition.System)/$($definition.Job)/$($row.normalized_path)"
        $currentPath = Join-Path $worktree $currentRelative.Replace('/', '\')
        $currentHash = if (Test-Path -LiteralPath $currentPath) { (Get-FileHash -LiteralPath $currentPath -Algorithm SHA256).Hash.ToLowerInvariant() } else { '' }
        $s0Rows.Add([pscustomobject]@{
            source_container_sha256 = $definition.Hash
            source_member = $row.extracted_path
            canonical_path = $currentRelative
            sha256 = $row.sha256
            canonical_sha256 = $currentHash
            status = if ($currentHash -eq $row.sha256) { 'MATCH' } elseif ($currentHash) { 'DIFFERENT' } else { 'MISSING' }
        })
    }
}
Write-Tsv -Path (Join-Path $archive 'S0_20260811_construct-X_sources\SOURCE_MEMBERS.tsv') -Headers @('source_container_sha256', 'source_member', 'canonical_path', 'sha256', 'canonical_sha256', 'status') -Rows $s0Rows

$p2Root = Join-Path $archive 'P2_20260814_and_end修正'
$p2Rows = [System.Collections.Generic.List[object]]::new()
foreach ($system in @('cleaved', 'uncleaved')) {
    $sourceSystem = Join-Path $package "history\P2_20260814_and_end修正\$system"
    foreach ($file in Get-ChildItem -LiteralPath $sourceSystem -File | Sort-Object Name) {
        $canonicalRelative = "construct-X/$system/$($file.Name)"
        $canonical = Join-Path $p2Root $canonicalRelative.Replace('/', '\')
        $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $canonicalHash = (Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash.ToLowerInvariant()
        $p2Rows.Add([pscustomobject]@{
            source_container_sha256 = 'uncompressed-migration-tree'
            source_member = "history/P2_20260814_and_end修正/$system/$($file.Name)"
            canonical_path = $canonicalRelative
            sha256 = $sourceHash
            canonical_sha256 = $canonicalHash
            status = if ($sourceHash -eq $canonicalHash) { 'MATCH' } else { 'DIFFERENT' }
        })
    }
}
Write-Tsv -Path (Join-Path $p2Root 'SOURCE_MEMBERS.tsv') -Headers @('source_container_sha256', 'source_member', 'canonical_path', 'sha256', 'canonical_sha256', 'status') -Rows $p2Rows

$p3Root = Join-Path $archive 'P3_20260814_分片可重启'
$p3Definitions = @(
    [pscustomobject]@{ Hash = '2d68fc708a32101691e7abddde3ca4c1e65554a7272c7186a9df379bab935363'; Prefix = 'construct-X/cleaved' },
    [pscustomobject]@{ Hash = 'd338a100947a70bdb3981e38a504fee4fa99bd9ddb8f0f1f2840ecc520318143'; Prefix = 'construct-X/uncleaved' },
    [pscustomobject]@{ Hash = '3d5bdec39c6de7bfbbdeea2d6f1b1b74fd4a9e938b2743ecb949bee20ea677c3'; Prefix = 'core' }
)
$p3Rows = [System.Collections.Generic.List[object]]::new()
foreach ($definition in $p3Definitions) {
    foreach ($row in $extractedRows | Where-Object container_sha256 -eq $definition.Hash | Sort-Object normalized_path) {
        $canonicalRelative = "$($definition.Prefix)/$($row.normalized_path)"
        $canonical = Join-Path $p3Root $canonicalRelative.Replace('/', '\')
        $canonicalHash = (Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash.ToLowerInvariant()
        $p3Rows.Add([pscustomobject]@{
            source_container_sha256 = $definition.Hash
            source_member = $row.extracted_path
            canonical_path = $canonicalRelative
            sha256 = $row.sha256
            canonical_sha256 = $canonicalHash
            status = if ($row.sha256 -eq $canonicalHash) { 'MATCH' } else { 'DIFFERENT' }
        })
    }
}
Write-Tsv -Path (Join-Path $p3Root 'SOURCE_MEMBERS.tsv') -Headers @('source_container_sha256', 'source_member', 'canonical_path', 'sha256', 'canonical_sha256', 'status') -Rows $p3Rows

$p4Root = Join-Path $archive 'P4_20260815_核验修订'
$p4Hash = '82de76be417b85dc7ffa4b14a5d190f347c16dded323ace376a4c1b63a8c2637'
$p4TargetMap = @{
    '说明.md' = 'source_variants/说明_container_final_82de76be.md'
    'analyze_smd.py' = 'common/analyze_smd.py'
    'run_smd.sh' = 'common/run_smd.sh'
    'run_smd_cleaved.sh' = 'construct-X/cleaved/run_smd_cleaved.sh'
    'smd_pull_cleaved.mdin' = 'construct-X/cleaved/smd_pull_cleaved.mdin'
    'cleaved/smd_pull.mdin' = 'construct-X/cleaved/smd_pull_cleaved.mdin'
    'cleaved/smd.RST' = 'construct-X/cleaved/smd_cleaved.RST'
    'run_smd_uncleaved.sh' = 'construct-X/uncleaved/run_smd_uncleaved.sh'
    'smd_pull_uncleaved.mdin' = 'construct-X/uncleaved/smd_pull_uncleaved.mdin'
    'uncleaved/smd_pull.mdin' = 'construct-X/uncleaved/smd_pull_uncleaved.mdin'
    'uncleaved/smd.RST' = 'construct-X/uncleaved/smd_uncleaved.RST'
}
$p4Rows = [System.Collections.Generic.List[object]]::new()
foreach ($row in $extractedRows | Where-Object container_sha256 -eq $p4Hash | Sort-Object normalized_path) {
    $canonicalRelative = $p4TargetMap[$row.normalized_path]
    if (-not $canonicalRelative) { throw "P4 member lacks target mapping: $($row.normalized_path)" }
    $canonical = Join-Path $p4Root $canonicalRelative.Replace('/', '\')
    $canonicalHash = (Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash.ToLowerInvariant()
    $p4Rows.Add([pscustomobject]@{
        source_container_sha256 = $p4Hash
        source_member = $row.extracted_path
        canonical_path = $canonicalRelative
        sha256 = $row.sha256
        canonical_sha256 = $canonicalHash
        status = if ($row.sha256 -eq $canonicalHash) { 'MATCH' } else { 'DIFFERENT' }
    })
}
$earlyDescription = $extractedRows | Where-Object { $_.container_sha256 -eq 'bc48c181aec43e1781e8bc1d55e6958d7626916c6946919e59aa4e480283411c' -and $_.normalized_path -eq '说明.md' }
$earlyTarget = Join-Path $p4Root 'source_variants\说明_pre_final_bc48c181.md'
$earlyTargetHash = (Get-FileHash -LiteralPath $earlyTarget -Algorithm SHA256).Hash.ToLowerInvariant()
$p4Rows.Add([pscustomobject]@{
    source_container_sha256 = $earlyDescription.container_sha256
    source_member = $earlyDescription.extracted_path
    canonical_path = 'source_variants/说明_pre_final_bc48c181.md'
    sha256 = $earlyDescription.sha256
    canonical_sha256 = $earlyTargetHash
    status = if ($earlyDescription.sha256 -eq $earlyTargetHash) { 'MATCH' } else { 'DIFFERENT' }
})
Write-Tsv -Path (Join-Path $p4Root 'SOURCE_MEMBERS.tsv') -Headers @('source_container_sha256', 'source_member', 'canonical_path', 'sha256', 'canonical_sha256', 'status') -Rows $p4Rows

$provenanceRows = [System.Collections.Generic.List[object]]::new()
foreach ($system in @('cleaved', 'uncleaved')) {
    $job = if ($system -eq 'cleaved') { 'charmm-gui-8643876985' } else { 'charmm-gui-8644096179' }
    $protocolRoot = Join-Path $worktree "protocols\construct-X\$system"
    foreach ($file in Get-ChildItem -LiteralPath $protocolRoot -File | Sort-Object Name) {
        $deployedRelative = "simulations/construct-X/$system/$job/amber/$($file.Name)"
        $deployed = Join-Path $worktree $deployedRelative.Replace('/', '\')
        $canonicalHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $deployedHash = if (Test-Path -LiteralPath $deployed) { (Get-FileHash -LiteralPath $deployed -Algorithm SHA256).Hash.ToLowerInvariant() } else { '' }
        $provenanceRows.Add([pscustomobject]@{
            canonical_path = $file.FullName.Substring($worktree.Length + 1).Replace('\', '/')
            deployed_path = $deployedRelative
            sha256 = $canonicalHash
            deployed_sha256 = $deployedHash
            status = if ($canonicalHash -eq $deployedHash) { 'MATCH' } elseif ($deployedHash) { 'DIFFERENT' } else { 'MISSING' }
        })
    }
}
$analysisPairs = @(
    @('analysis/cleaved_smd_v02.dat', 'simulations/construct-X/cleaved/charmm-gui-8643876985/amber/smd_production/smd_curves.dat'),
    @('analysis/cleaved_smd_curves_v02.png', 'simulations/construct-X/cleaved/charmm-gui-8643876985/amber/smd_production/smd_curves.png'),
    @('analysis/uncleaved_smd_v02.dat', 'simulations/construct-X/uncleaved/charmm-gui-8644096179/amber/smd_production/smd_curves.dat'),
    @('analysis/uncleaved_smd_curves_v02.png', 'simulations/construct-X/uncleaved/charmm-gui-8644096179/amber/smd_production/smd_curves.png')
)
foreach ($pair in $analysisPairs) {
    $canonical = Join-Path $worktree $pair[0].Replace('/', '\')
    $deployed = Join-Path $worktree $pair[1].Replace('/', '\')
    $canonicalHash = (Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash.ToLowerInvariant()
    $deployedHash = (Get-FileHash -LiteralPath $deployed -Algorithm SHA256).Hash.ToLowerInvariant()
    $provenanceRows.Add([pscustomobject]@{
        canonical_path = $pair[0]
        deployed_path = $pair[1]
        sha256 = $canonicalHash
        deployed_sha256 = $deployedHash
        status = if ($canonicalHash -eq $deployedHash) { 'MATCH' } else { 'DIFFERENT' }
    })
}
Write-Tsv -Path (Join-Path $worktree 'PROVENANCE_MAP.tsv') -Headers @('canonical_path', 'deployed_path', 'sha256', 'deployed_sha256', 'status') -Rows $provenanceRows

foreach ($snapshot in @(
    (Join-Path $archive 'S0_20260811_construct-X_sources'),
    (Join-Path $archive 'P1_20260813_初始交付_sander兼容版'),
    $p2Root,
    $p3Root,
    $p4Root,
    (Join-Path $archive 'non_delivery\analyze_smd_v0_63cdce37'),
    (Join-Path $archive '文档旧版')
)) {
    Write-Manifest -Root $snapshot
}

Write-Manifest -Root (Join-Path $worktree 'protocols')
Write-Manifest -Root (Join-Path $worktree 'analysis')
Write-Manifest -Root (Join-Path $worktree 'structures\construct-X')

Write-Output "S0 member mappings: $($s0Rows.Count)"
Write-Output "P2 member mappings: $($p2Rows.Count)"
Write-Output "P3 member mappings: $($p3Rows.Count)"
Write-Output "P4 member mappings: $($p4Rows.Count)"
Write-Output "Current provenance mappings: $($provenanceRows.Count)"
