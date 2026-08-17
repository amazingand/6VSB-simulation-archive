[CmdletBinding()]
param(
    [Parameter()]
    [string]$SourceRoot = 'D:\database\6VSB',

    [Parameter()]
    [string]$AuditRoot = 'D:\database\6VSB\work\archive_audit_20260817',

    [Parameter()]
    [string]$WslDistribution = 'Ubuntu-24.04'
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

function ConvertTo-WslPath {
    param([Parameter(Mandatory)][string]$WindowsPath)

    $resolved = [System.IO.Path]::GetFullPath($WindowsPath)
    if ($resolved -notmatch '^([A-Za-z]):\\(.*)$') {
        throw "Unsupported Windows path: $resolved"
    }

    $drive = $Matches[1].ToLowerInvariant()
    $tail = $Matches[2].Replace('\', '/')
    return "/mnt/$drive/$tail"
}

function Get-StringSha256 {
    param([Parameter(Mandatory)][string]$Value)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return [Convert]::ToHexString($hash).ToLowerInvariant()
}

function Get-NormalizedMemberPath {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$CommonRoot
    )

    $portable = $RelativePath.Replace('\', '/')
    if ($CommonRoot -and $portable.StartsWith("$CommonRoot/", [System.StringComparison]::Ordinal)) {
        return $portable.Substring($CommonRoot.Length + 1)
    }
    return $portable
}

$sourceResolved = [System.IO.Path]::GetFullPath($SourceRoot)
$auditResolved = [System.IO.Path]::GetFullPath($AuditRoot)

if (-not (Test-Path -LiteralPath $sourceResolved -PathType Container)) {
    throw "Source root does not exist: $sourceResolved"
}
if (-not $auditResolved.StartsWith("$sourceResolved\work\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Audit root must stay under the source work directory: $auditResolved"
}
if (Test-Path -LiteralPath $auditResolved) {
    throw "Audit root already exists; refusing to overwrite: $auditResolved"
}
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw 'wsl.exe is required.'
}

$reportsRoot = Join-Path $auditResolved 'reports'
$extractRoot = Join-Path $auditResolved 'extracted'
$listingRoot = Join-Path $auditResolved 'listings'
New-Item -ItemType Directory -Path $reportsRoot, $extractRoot, $listingRoot -Force | Out-Null

$archives = @(
    Get-ChildItem -LiteralPath $sourceResolved -File -Recurse |
        Where-Object {
            $_.FullName -notlike "$sourceResolved\.git\*" -and
            $_.FullName -notlike "$sourceResolved\work\*" -and
            ($_.Name.EndsWith('.tgz', [System.StringComparison]::OrdinalIgnoreCase) -or
             $_.Name.EndsWith('.tar.gz', [System.StringComparison]::OrdinalIgnoreCase))
        } |
        Sort-Object FullName
)

if ($archives.Count -eq 0) {
    throw 'No .tgz or .tar.gz files were found.'
}

$containerRows = [System.Collections.Generic.List[object]]::new()
$archiveRecords = [System.Collections.Generic.List[object]]::new()

foreach ($archive in $archives) {
    $sha256 = (Get-FileHash -LiteralPath $archive.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $wslArchive = ConvertTo-WslPath -WindowsPath $archive.FullName
    $members = @(& wsl.exe -d $WslDistribution --exec tar -tf $wslArchive)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to list archive: $($archive.FullName)"
    }
    $verbose = @(& wsl.exe -d $WslDistribution --exec tar -tvf $wslArchive)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read archive metadata: $($archive.FullName)"
    }

    $portableMembers = @($members | ForEach-Object { $_.Replace('\', '/') } | Where-Object { $_ })
    $unsafeAbsolute = @($portableMembers | Where-Object { $_ -match '^(?:/|[A-Za-z]:)' })
    $unsafeTraversal = @($portableMembers | Where-Object { ('/' + $_ + '/') -match '/\.\./' })
    $duplicates = @($portableMembers | Group-Object | Where-Object Count -gt 1)
    $links = @($verbose | Where-Object { $_ -match '^[lh]' })
    $special = @($verbose | Where-Object { $_ -match '^[bcp]' })

    $firstSegments = @(
        $portableMembers |
            ForEach-Object { ($_ -split '/', 2)[0] } |
            Where-Object { $_ } |
            Sort-Object -Unique
    )
    $commonRoot = if ($firstSegments.Count -eq 1) { $firstSegments[0] } else { '' }
    $safe = ($unsafeAbsolute.Count -eq 0 -and $unsafeTraversal.Count -eq 0 -and $duplicates.Count -eq 0 -and $links.Count -eq 0 -and $special.Count -eq 0)

    $listingPath = Join-Path $listingRoot "$sha256.members.txt"
    $verbosePath = Join-Path $listingRoot "$sha256.verbose.txt"
    Write-Utf8LfFile -Path $listingPath -Lines $portableMembers
    Write-Utf8LfFile -Path $verbosePath -Lines $verbose

    $relativeArchive = $archive.FullName.Substring($sourceResolved.Length + 1).Replace('\', '/')
    $containerRows.Add([pscustomobject]@{
        archive_path = $relativeArchive
        bytes = $archive.Length
        sha256 = $sha256
        member_count = $portableMembers.Count
        common_root = $commonRoot
        safe = $safe
        absolute_paths = $unsafeAbsolute.Count
        traversal_paths = $unsafeTraversal.Count
        duplicate_paths = $duplicates.Count
        links = $links.Count
        special_files = $special.Count
    })
    $archiveRecords.Add([pscustomobject]@{
        Archive = $archive
        Sha256 = $sha256
        Members = $portableMembers
        CommonRoot = $commonRoot
        Safe = $safe
    })
}

Write-Utf8LfFile -Path (Join-Path $reportsRoot 'ARCHIVE_CONTAINERS.csv') -Lines @($containerRows | ConvertTo-Csv -NoTypeInformation)

$unsafeArchives = @($archiveRecords | Where-Object { -not $_.Safe })
if ($unsafeArchives.Count -gt 0) {
    throw "Unsafe archive members detected in $($unsafeArchives.Count) archive(s); extraction stopped."
}

$uniqueGroups = @($archiveRecords | Group-Object Sha256 | Sort-Object Name)
$fileRows = [System.Collections.Generic.List[object]]::new()
$treeRows = [System.Collections.Generic.List[object]]::new()

foreach ($group in $uniqueGroups) {
    $representative = $group.Group[0]
    $groupSha = $group.Name
    $destination = Join-Path $extractRoot $groupSha
    New-Item -ItemType Directory -Path $destination | Out-Null

    $wslArchive = ConvertTo-WslPath -WindowsPath $representative.Archive.FullName
    $wslDestination = ConvertTo-WslPath -WindowsPath $destination
    & wsl.exe -d $WslDistribution --exec tar --extract --file $wslArchive --directory $wslDestination --no-same-owner --no-same-permissions --keep-old-files
    if ($LASTEXITCODE -ne 0) {
        throw "Extraction failed: $($representative.Archive.FullName)"
    }

    $signatureLines = [System.Collections.Generic.List[string]]::new()
    foreach ($file in Get-ChildItem -LiteralPath $destination -File -Recurse | Sort-Object FullName) {
        $relative = $file.FullName.Substring($destination.Length + 1).Replace('\', '/')
        $normalized = Get-NormalizedMemberPath -RelativePath $relative -CommonRoot $representative.CommonRoot
        $fileSha = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $signatureLines.Add("$normalized`t$($file.Length)`t$fileSha")
        $fileRows.Add([pscustomobject]@{
            container_sha256 = $groupSha
            representative_archive = $representative.Archive.FullName.Substring($sourceResolved.Length + 1).Replace('\', '/')
            extracted_path = $relative
            normalized_path = $normalized
            bytes = $file.Length
            sha256 = $fileSha
        })
    }

    $treeSignature = Get-StringSha256 -Value (($signatureLines | Sort-Object) -join "`n")
    $treeRows.Add([pscustomobject]@{
        container_sha256 = $groupSha
        physical_archive_count = $group.Count
        representative_archive = $representative.Archive.FullName.Substring($sourceResolved.Length + 1).Replace('\', '/')
        common_root = $representative.CommonRoot
        file_count = $signatureLines.Count
        tree_signature = $treeSignature
    })
}

Write-Utf8LfFile -Path (Join-Path $reportsRoot 'EXTRACTED_FILES.csv') -Lines @($fileRows | ConvertTo-Csv -NoTypeInformation)
Write-Utf8LfFile -Path (Join-Path $reportsRoot 'TREE_SIGNATURES.csv') -Lines @($treeRows | ConvertTo-Csv -NoTypeInformation)

$containerDuplicates = @(
    $containerRows |
        Group-Object sha256 |
        Where-Object Count -gt 1 |
        ForEach-Object {
            [pscustomobject]@{
                sha256 = $_.Name
                count = $_.Count
                archive_paths = (($_.Group.archive_path | Sort-Object) -join '; ')
            }
        }
)
Write-Utf8LfFile -Path (Join-Path $reportsRoot 'DUPLICATE_CONTAINERS.csv') -Lines @($containerDuplicates | ConvertTo-Csv -NoTypeInformation)

$treeEquivalence = @(
    $treeRows |
        Group-Object tree_signature |
        Where-Object Count -gt 1 |
        ForEach-Object {
            [pscustomobject]@{
                tree_signature = $_.Name
                unique_container_count = $_.Count
                container_sha256 = (($_.Group.container_sha256 | Sort-Object) -join '; ')
                representative_archives = (($_.Group.representative_archive | Sort-Object) -join '; ')
            }
        }
)
Write-Utf8LfFile -Path (Join-Path $reportsRoot 'EQUIVALENT_EXTRACTED_TREES.csv') -Lines @($treeEquivalence | ConvertTo-Csv -NoTypeInformation)

$duplicateContent = @(
    $fileRows |
        Group-Object sha256 |
        Where-Object Count -gt 1 |
        ForEach-Object {
            [pscustomobject]@{
                sha256 = $_.Name
                occurrences = $_.Count
                locations = (($_.Group | ForEach-Object { "$($_.container_sha256):$($_.normalized_path)" } | Sort-Object) -join '; ')
            }
        }
)
Write-Utf8LfFile -Path (Join-Path $reportsRoot 'DUPLICATE_FILE_CONTENT.csv') -Lines @($duplicateContent | ConvertTo-Csv -NoTypeInformation)

$pathConflicts = @(
    $fileRows |
        Group-Object normalized_path |
        ForEach-Object {
            $hashes = @($_.Group.sha256 | Sort-Object -Unique)
            if ($hashes.Count -gt 1) {
                [pscustomobject]@{
                    normalized_path = $_.Name
                    distinct_hashes = $hashes.Count
                    occurrences = $_.Count
                    sha256_values = ($hashes -join '; ')
                    containers = (($_.Group.container_sha256 | Sort-Object -Unique) -join '; ')
                }
            }
        }
)
Write-Utf8LfFile -Path (Join-Path $reportsRoot 'PATH_CONFLICTS.csv') -Lines @($pathConflicts | ConvertTo-Csv -NoTypeInformation)

$summary = @(
    '# Cprime 历史压缩包成员级审计摘要'
    ''
    "- 生成时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
    "- 物理压缩包：$($archives.Count)"
    "- 唯一容器内容：$($uniqueGroups.Count)"
    "- 安全性异常：$($unsafeArchives.Count)"
    "- 精确重复容器组：$($containerDuplicates.Count)"
    "- 不同容器但解压树等价组：$($treeEquivalence.Count)"
    "- 解压文件记录：$($fileRows.Count)"
    "- 重复文件内容组：$($duplicateContent.Count)"
    "- 同规范路径异内容组：$($pathConflicts.Count)"
    ''
    '本报告只比较路径、类型、大小、权限记录和 SHA-256，不评价文件所涉及的研究内容。'
)
Write-Utf8LfFile -Path (Join-Path $reportsRoot 'SUMMARY.md') -Lines $summary

Write-Output "Audit complete: $auditResolved"
Write-Output "Physical archives: $($archives.Count)"
Write-Output "Unique containers: $($uniqueGroups.Count)"
Write-Output "Extracted files: $($fileRows.Count)"
Write-Output "Path conflicts: $($pathConflicts.Count)"
