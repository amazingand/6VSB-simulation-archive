[CmdletBinding()]
param(
    [Parameter()]
    [string]$WorktreeRoot = 'D:\database\6VSB-worktrees\restructure-cprime-history-2026-08-17',

    [Parameter()]
    [string]$SourceRoot = 'D:\database\6VSB',

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

$hashP3Cleaved = '2d68fc708a32101691e7abddde3ca4c1e65554a7272c7186a9df379bab935363'
$hashP3Uncleaved = 'd338a100947a70bdb3981e38a504fee4fa99bd9ddb8f0f1f2840ecc520318143'
$hashP3Core = '3d5bdec39c6de7bfbbdeea2d6f1b1b74fd4a9e938b2743ecb949bee20ea677c3'
$hashP4 = '82de76be417b85dc7ffa4b14a5d190f347c16dded323ace376a4c1b63a8c2637'
$hashP4Early = 'bc48c181aec43e1781e8bc1d55e6958d7626916c6946919e59aa4e480283411c'
$hashHybridCleaved = 'fc6041920c9c014b11c6f16b48459be447de4f5117ef6667a96b9c9de67dce32'
$hashHybridUncleaved = 'd62a9f9acfbcffb56119a56ce562dcc26b499f4d1c3872f850ada0c65bda8440'
$hashDraftAnalyze = '63cdce37976d404943901f8a98cea36d0f43613622bc3eb7ecebeebb2bd9a842'
$hashAnalyzeVersionReport = '66ed49aceb38992069ffaf3e548905ed5dfd27941cca4bb132f223c2512e0b95'

function Assert-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Required directory does not exist: $Path"
    }
}

function Copy-NewFile {
    param([string]$Source, [string]$Destination)
    if (Test-Path -LiteralPath $Destination) {
        throw "Refusing to overwrite: $Destination"
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Destination
}

function Copy-NewTree {
    param([string]$Source, [string]$Destination)
    if (Test-Path -LiteralPath $Destination) {
        throw "Refusing to overwrite directory: $Destination"
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse
}

function Get-ContainerRoot {
    param([string]$ContainerSha256)
    $container = Join-Path (Join-Path $AuditRoot 'extracted') $ContainerSha256
    $entries = @(Get-ChildItem -LiteralPath $container -Force)
    if ($entries.Count -ne 1 -or -not $entries[0].PSIsContainer) {
        throw "Expected one common root for container $ContainerSha256"
    }
    return $entries[0].FullName
}

function Write-Tsv {
    param([string]$Path, [string[]]$Headers, [object[]]$Rows)
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add(($Headers -join "`t"))
    foreach ($row in $Rows) {
        $values = foreach ($header in $Headers) {
            $value = [string]$row.$header
            $value.Replace("`t", ' ').Replace("`r", ' ').Replace("`n", ' ')
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

function Normalize-CprimeSpelling {
    param(
        [string]$Root,
        [switch]$NormalizeLineEndings
    )
    $textFiles = Get-ChildItem -LiteralPath $Root -File -Recurse | Where-Object { $_.Extension -in '.md', '.txt', '.tsv', '.csv' }
    foreach ($file in $textFiles) {
        $content = [System.IO.File]::ReadAllText($file.FullName)
        $legacyProjectName = 'C' + [char]0x2032
        $normalized = $content.Replace($legacyProjectName, 'Cprime')
        if ($NormalizeLineEndings) {
            $normalized = $normalized.Replace("`r`n", "`n").Replace("`r", "`n")
        }
        if ($normalized -cne $content) {
            [System.IO.File]::WriteAllText($file.FullName, $normalized, [System.Text.UTF8Encoding]::new($false))
        }
    }
}

$worktreeResolved = [System.IO.Path]::GetFullPath($WorktreeRoot)
$sourceResolved = [System.IO.Path]::GetFullPath($SourceRoot)
$packageResolved = [System.IO.Path]::GetFullPath($PackageRoot)
$auditResolved = [System.IO.Path]::GetFullPath($AuditRoot)

Assert-Directory $worktreeResolved
Assert-Directory $sourceResolved
Assert-Directory $packageResolved
Assert-Directory $auditResolved

foreach ($name in @('docs', 'protocols', 'analysis', 'archive')) {
    if (Test-Path -LiteralPath (Join-Path $worktreeResolved $name)) {
        throw "Target already exists; refusing partial rebuild: $name"
    }
}

Copy-NewTree (Join-Path $packageResolved 'docs') (Join-Path $worktreeResolved 'docs')
if ((Get-FileHash -LiteralPath (Join-Path $packageResolved 'M3_analyze_smd版本迭代确认_v01.md') -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hashAnalyzeVersionReport) {
    throw 'Unexpected source hash for M3_analyze_smd版本迭代确认_v01.md'
}
Copy-NewFile (Join-Path $packageResolved 'M3_analyze_smd版本迭代确认_v01.md') (Join-Path $worktreeResolved 'docs\M3_analyze_smd版本迭代确认_v01.md')
Copy-NewTree (Join-Path $packageResolved 'protocols') (Join-Path $worktreeResolved 'protocols')
Copy-NewTree (Join-Path $packageResolved 'analysis') (Join-Path $worktreeResolved 'analysis')
Copy-NewTree (Join-Path $packageResolved 'structures\construct-X') (Join-Path $worktreeResolved 'structures\construct-X')

foreach ($name in @('pack_migration.sh', 'run_smd.sh', 'smd_pull.mdin')) {
    Copy-NewFile (Join-Path $packageResolved "scripts\$name") (Join-Path $worktreeResolved "scripts\$name")
}
Copy-NewFile (Join-Path $packageResolved 'MANIFEST.md') (Join-Path $worktreeResolved 'MANIFEST.md')
Copy-NewFile (Join-Path $packageResolved 'ITERATION_HISTORY.md') (Join-Path $worktreeResolved 'ITERATION_HISTORY.md')

# Canonical protocol text is normalized before deployment copies are synchronized.
Normalize-CprimeSpelling -Root (Join-Path $worktreeResolved 'protocols') -NormalizeLineEndings

$analysisMappings = @(
    [pscustomobject]@{ Source = 'simulations\construct-X\cleaved\charmm-gui-8643876985\amber\smd_production\smd_curves.dat'; Target = 'analysis\cleaved_smd_v02.dat' },
    [pscustomobject]@{ Source = 'simulations\construct-X\cleaved\charmm-gui-8643876985\amber\smd_production\smd_curves.png'; Target = 'analysis\cleaved_smd_curves_v02.png' },
    [pscustomobject]@{ Source = 'simulations\construct-X\uncleaved\charmm-gui-8644096179\amber\smd_production\smd_curves.dat'; Target = 'analysis\uncleaved_smd_v02.dat' },
    [pscustomobject]@{ Source = 'simulations\construct-X\uncleaved\charmm-gui-8644096179\amber\smd_production\smd_curves.png'; Target = 'analysis\uncleaved_smd_curves_v02.png' }
)
foreach ($mapping in $analysisMappings) {
    Copy-NewFile (Join-Path $worktreeResolved $mapping.Source) (Join-Path $worktreeResolved $mapping.Target)
}

# Synchronize the four P4.1 deployment files that had not reached the baseline.
$deploymentSync = @(
    [pscustomobject]@{ System = 'cleaved'; Job = 'charmm-gui-8643876985'; File = 'run_smd_cleaved.sh' },
    [pscustomobject]@{ System = 'cleaved'; Job = 'charmm-gui-8643876985'; File = 'smd_pull_cleaved.mdin' },
    [pscustomobject]@{ System = 'uncleaved'; Job = 'charmm-gui-8644096179'; File = 'run_smd_uncleaved.sh' },
    [pscustomobject]@{ System = 'uncleaved'; Job = 'charmm-gui-8644096179'; File = 'smd_pull_uncleaved.mdin' }
)
foreach ($item in $deploymentSync) {
    $canonical = Join-Path $worktreeResolved "protocols\construct-X\$($item.System)\$($item.File)"
    $deployed = Join-Path $worktreeResolved "simulations\construct-X\$($item.System)\$($item.Job)\amber\$($item.File)"
    Copy-Item -LiteralPath $canonical -Destination $deployed
    $canonicalHash = (Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash
    $deployedHash = (Get-FileHash -LiteralPath $deployed -Algorithm SHA256).Hash
    if ($canonicalHash -ne $deployedHash) {
        throw "Deployment synchronization failed: $($item.File)"
    }
}

$archiveRoot = Join-Path $worktreeResolved 'archive'
New-Item -ItemType Directory -Path $archiveRoot | Out-Null

Copy-NewTree (Join-Path $packageResolved 'archive\P1_20260813_初始交付_sander兼容版') (Join-Path $archiveRoot 'P1_20260813_初始交付_sander兼容版')
Copy-NewTree (Join-Path $packageResolved 'archive\文档旧版') (Join-Path $archiveRoot '文档旧版')

$p2 = Join-Path $archiveRoot 'P2_20260814_and_end修正'
New-Item -ItemType Directory -Path $p2 | Out-Null
Copy-NewFile (Join-Path $packageResolved 'archive\P2_20260814_and_end修正\说明.md') (Join-Path $p2 '说明.md')
Copy-NewTree (Join-Path $packageResolved 'archive\P2_20260814_and_end修正\cleaved') (Join-Path $p2 'construct-X\cleaved')
Copy-NewTree (Join-Path $packageResolved 'archive\P2_20260814_and_end修正\uncleaved') (Join-Path $p2 'construct-X\uncleaved')

$p3 = Join-Path $archiveRoot 'P3_20260814_分片可重启'
New-Item -ItemType Directory -Path $p3 | Out-Null
Copy-NewFile (Join-Path $packageResolved 'archive\P3_20260814_分片可重启\说明.md') (Join-Path $p3 '说明.md')
Copy-NewTree (Get-ContainerRoot $hashP3Cleaved) (Join-Path $p3 'construct-X\cleaved')
Copy-NewTree (Get-ContainerRoot $hashP3Uncleaved) (Join-Path $p3 'construct-X\uncleaved')
Copy-NewTree (Get-ContainerRoot $hashP3Core) (Join-Path $p3 'core')

$p4Source = Get-ContainerRoot $hashP4
$p4EarlySource = Get-ContainerRoot $hashP4Early
$p4 = Join-Path $archiveRoot 'P4_20260815_核验修订'
New-Item -ItemType Directory -Path $p4 | Out-Null
Copy-NewFile (Join-Path $packageResolved 'archive\P4_20260815_核验修订\说明.md') (Join-Path $p4 '说明.md')
Copy-NewFile (Join-Path $p4Source 'analyze_smd.py') (Join-Path $p4 'common\analyze_smd.py')
Copy-NewFile (Join-Path $p4Source 'run_smd.sh') (Join-Path $p4 'common\run_smd.sh')
Copy-NewFile (Join-Path $p4Source 'run_smd_cleaved.sh') (Join-Path $p4 'construct-X\cleaved\run_smd_cleaved.sh')
Copy-NewFile (Join-Path $p4Source 'smd_pull_cleaved.mdin') (Join-Path $p4 'construct-X\cleaved\smd_pull_cleaved.mdin')
Copy-NewFile (Join-Path $p4Source 'cleaved\smd.RST') (Join-Path $p4 'construct-X\cleaved\smd_cleaved.RST')
Copy-NewFile (Join-Path $p4Source 'run_smd_uncleaved.sh') (Join-Path $p4 'construct-X\uncleaved\run_smd_uncleaved.sh')
Copy-NewFile (Join-Path $p4Source 'smd_pull_uncleaved.mdin') (Join-Path $p4 'construct-X\uncleaved\smd_pull_uncleaved.mdin')
Copy-NewFile (Join-Path $p4Source 'uncleaved\smd.RST') (Join-Path $p4 'construct-X\uncleaved\smd_uncleaved.RST')
Copy-NewFile (Join-Path $p4Source '说明.md') (Join-Path $p4 'source_variants\说明_container_final_82de76be.md')
Copy-NewFile (Join-Path $p4EarlySource '说明.md') (Join-Path $p4 'source_variants\说明_pre_final_bc48c181.md')

$s0 = Join-Path $archiveRoot 'S0_20260811_construct-X_sources'
New-Item -ItemType Directory -Path $s0 | Out-Null

$nonDeliveryDraft = Join-Path $archiveRoot 'non_delivery\analyze_smd_v0_63cdce37'
New-Item -ItemType Directory -Path $nonDeliveryDraft -Force | Out-Null
$hybridSource = Get-ContainerRoot $hashHybridCleaved
Copy-NewFile (Join-Path $hybridSource 'analyze_smd.py') (Join-Path $nonDeliveryDraft 'analyze_smd.py')

$containerRows = Import-Csv -LiteralPath (Join-Path $auditResolved 'reports\ARCHIVE_CONTAINERS.csv')

$sourceDefinitions = @(
    [pscustomobject]@{ Root = $s0; Hashes = @('c690db985aa83b89b0863a7ac0a9069b0f1cbaef36ab9570529ff4e277f6ec74', '29509aa6a105b707ab9fb6b9065eb6cd3199cdb23a589372f9e9b699b18ee6a5'); Role = 'original_source_manifest_only' },
    [pscustomobject]@{ Root = $p3; Hashes = @($hashP3Cleaved, $hashP3Uncleaved, $hashP3Core); Role = 'authoritative_snapshot_source' },
    [pscustomobject]@{ Root = $p4; Hashes = @($hashP4, $hashP4Early); Role = 'authoritative_and_metadata_variant' },
    [pscustomobject]@{ Root = $nonDeliveryDraft; Hashes = @($hashHybridCleaved, $hashHybridUncleaved); Role = 'non_delivery_hybrid_transfer_source' }
)
foreach ($definition in $sourceDefinitions) {
    $rows = @(
        $containerRows |
            Where-Object { $_.sha256 -in $definition.Hashes } |
            Sort-Object archive_path |
            ForEach-Object {
                [pscustomobject]@{
                    source_archive = $_.archive_path
                    bytes = $_.bytes
                    sha256 = $_.sha256
                    role = $definition.Role
                }
            }
    )
    Write-Tsv -Path (Join-Path $definition.Root 'SOURCE_ARCHIVES.tsv') -Headers @('source_archive', 'bytes', 'sha256', 'role') -Rows $rows
}

$p2Sources = @(
    [pscustomobject]@{ source_archive = 'simulations/construct-X/cleaved/cleaved.tgz'; bytes = 7213; sha256 = $hashHybridCleaved; role = 'hybrid_not_authoritative_for_P2' },
    [pscustomobject]@{ source_archive = 'simulations/construct-X/uncleaved/uncleaved.tgz'; bytes = 7213; sha256 = $hashHybridUncleaved; role = 'hybrid_not_authoritative_for_P2' },
    [pscustomobject]@{ source_archive = 'Cprime_migration_20260815/archive/P2_20260814_and_end修正'; bytes = ''; sha256 = ''; role = 'authoritative_reconstructed_tree' }
)
Write-Tsv -Path (Join-Path $p2 'SOURCE_ARCHIVES.tsv') -Headers @('source_archive', 'bytes', 'sha256', 'role') -Rows $p2Sources

$draftRows = @(
    [pscustomobject]@{ canonical_path = 'analyze_smd.py'; sha256 = $hashDraftAnalyze; status = 'identified_non_delivery_draft'; version = 'v0'; formal_delivery = 'no'; evidence = 'docs/M3_analyze_smd版本迭代确认_v01.md'; note = 'Early draft retained for provenance; excluded from the formal v1-to-v2 delivery chain.' }
)
Write-Tsv -Path (Join-Path $nonDeliveryDraft 'PROVENANCE.tsv') -Headers @('canonical_path', 'sha256', 'status', 'version', 'formal_delivery', 'evidence', 'note') -Rows $draftRows

Normalize-CprimeSpelling -Root (Join-Path $worktreeResolved 'archive')
foreach ($snapshot in @($s0, (Join-Path $archiveRoot 'P1_20260813_初始交付_sander兼容版'), $p2, $p3, $p4, $nonDeliveryDraft, (Join-Path $archiveRoot '文档旧版'))) {
    Write-Manifest -Root $snapshot
}

$auditDocs = Join-Path $worktreeResolved 'docs\audits\Cprime_archive_audit_20260817'
New-Item -ItemType Directory -Path $auditDocs -Force | Out-Null
foreach ($name in @('SUMMARY.md', 'ARCHIVE_CONTAINERS.csv', 'TREE_SIGNATURES.csv', 'DUPLICATE_CONTAINERS.csv', 'EQUIVALENT_EXTRACTED_TREES.csv', 'PATH_CONFLICTS.csv')) {
    Copy-NewFile (Join-Path $auditResolved "reports\$name") (Join-Path $auditDocs $name)
}

$provenanceRows = [System.Collections.Generic.List[object]]::new()
foreach ($system in @('cleaved', 'uncleaved')) {
    $job = if ($system -eq 'cleaved') { 'charmm-gui-8643876985' } else { 'charmm-gui-8644096179' }
    $protocolRoot = Join-Path $worktreeResolved "protocols\construct-X\$system"
    foreach ($file in Get-ChildItem -LiteralPath $protocolRoot -File | Sort-Object Name) {
        $simulationRelative = "simulations/construct-X/$system/$job/amber/$($file.Name)"
        $simulationPath = Join-Path $worktreeResolved $simulationRelative.Replace('/', '\')
        $canonicalHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $simulationHash = if (Test-Path -LiteralPath $simulationPath) { (Get-FileHash -LiteralPath $simulationPath -Algorithm SHA256).Hash.ToLowerInvariant() } else { '' }
        $provenanceRows.Add([pscustomobject]@{
            canonical_path = $file.FullName.Substring($worktreeResolved.Length + 1).Replace('\', '/')
            deployed_path = $simulationRelative
            sha256 = $canonicalHash
            deployed_sha256 = $simulationHash
            status = if ($canonicalHash -eq $simulationHash) { 'MATCH' } elseif ($simulationHash) { 'DIFFERENT' } else { 'MISSING' }
        })
    }
}
foreach ($mapping in $analysisMappings) {
    $canonicalPath = Join-Path $worktreeResolved $mapping.Target
    $sourcePath = Join-Path $worktreeResolved $mapping.Source
    $canonicalHash = (Get-FileHash -LiteralPath $canonicalPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $provenanceRows.Add([pscustomobject]@{
        canonical_path = $mapping.Target.Replace('\', '/')
        deployed_path = $mapping.Source.Replace('\', '/')
        sha256 = $canonicalHash
        deployed_sha256 = $sourceHash
        status = if ($canonicalHash -eq $sourceHash) { 'MATCH' } else { 'DIFFERENT' }
    })
}
Write-Tsv -Path (Join-Path $worktreeResolved 'PROVENANCE_MAP.tsv') -Headers @('canonical_path', 'deployed_path', 'sha256', 'deployed_sha256', 'status') -Rows $provenanceRows

Normalize-CprimeSpelling -Root (Join-Path $worktreeResolved 'docs') -NormalizeLineEndings
Normalize-CprimeSpelling -Root (Join-Path $worktreeResolved 'protocols') -NormalizeLineEndings
Normalize-CprimeSpelling -Root (Join-Path $worktreeResolved 'analysis') -NormalizeLineEndings
Normalize-CprimeSpelling -Root (Join-Path $worktreeResolved 'structures\construct-X') -NormalizeLineEndings
Normalize-CprimeSpelling -Root (Join-Path $worktreeResolved 'MANIFEST.md') -NormalizeLineEndings
Normalize-CprimeSpelling -Root (Join-Path $worktreeResolved 'ITERATION_HISTORY.md') -NormalizeLineEndings
foreach ($name in @('pack_migration.sh', 'run_smd.sh', 'smd_pull.mdin')) {
    Normalize-CprimeSpelling -Root (Join-Path $worktreeResolved "scripts\$name") -NormalizeLineEndings
}

Write-Output "Cprime history layout created under: $worktreeResolved"
Write-Output "Provenance rows: $($provenanceRows.Count)"
