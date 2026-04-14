param(
    [Parameter(Mandatory = $true)]
    [string]$RuleFile,

    [string]$OutputFile = "",

    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-ConfigPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigFilePath,

        [Parameter(Mandatory = $true)]
        [string]$ConfiguredPath
    )

    if ([System.IO.Path]::IsPathRooted($ConfiguredPath)) {
        return $ConfiguredPath
    }

    $configDirectory = Split-Path -Path $ConfigFilePath -Parent
    return [System.IO.Path]::GetFullPath((Join-Path -Path $configDirectory -ChildPath $ConfiguredPath))
}

function Expand-ConfigEnvironmentVariables {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputText
    )

    return ([System.Text.RegularExpressions.Regex]::Replace(
        $InputText,
        '\$\{env:([^}]+)\}',
        {
            param($match)

            $variableName = $match.Groups[1].Value
            $variableValue = [System.Environment]::GetEnvironmentVariable($variableName)
            if ($null -eq $variableValue) {
                throw "Unknown environment variable '$variableName' in value '$InputText'."
            }

            return [string]$variableValue
        }
    ))
}

function Get-ArchiveEntryPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfiguredPath,

        [Parameter(Mandatory = $true)]
        [string]$ResolvedPath
    )

    if ([System.IO.Path]::IsPathRooted($ConfiguredPath)) {
        $drive = [System.IO.Path]::GetPathRoot($ResolvedPath).TrimEnd("\", ":")
        $rest = $ResolvedPath.Substring([System.IO.Path]::GetPathRoot($ResolvedPath).Length).TrimStart("\")
        if ([string]::IsNullOrWhiteSpace($rest)) {
            return "absolute/$drive"
        }

        return ("absolute/{0}/{1}" -f $drive, ($rest -replace "\\", "/"))
    }

    return ($ConfiguredPath -replace "\\", "/")
}

if (-not (Test-Path -LiteralPath $RuleFile -PathType Leaf)) {
    throw "Rule file not found: $RuleFile"
}

if ([string]::IsNullOrWhiteSpace($OutputFile)) {
    $ruleDirectory = Split-Path -Path $RuleFile -Parent
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputFile = Join-Path -Path $ruleDirectory -ChildPath ("json-sources-backup-{0}.tar.gz" -f $timestamp)
}

$resolvedOutputFile = [System.IO.Path]::GetFullPath($OutputFile)
$ruleConfig = Get-Content -LiteralPath $RuleFile -Raw | ConvertFrom-Json
$fileEntries = @($ruleConfig.files)
if ($fileEntries.Count -eq 0) {
    throw "The rule file does not contain any file entries."
}

$backupItems = New-Object System.Collections.Generic.List[object]
$seenPaths = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

foreach ($fileEntry in $fileEntries) {
    if ([string]::IsNullOrWhiteSpace($fileEntry.path)) {
        throw "Each file entry must contain 'path'."
    }

    $sourcePath = Expand-ConfigEnvironmentVariables -InputText ([string]$fileEntry.path)
    $resolvedSourceFilePath = Resolve-ConfigPath -ConfigFilePath $RuleFile -ConfiguredPath $sourcePath
    if (-not (Test-Path -LiteralPath $resolvedSourceFilePath -PathType Leaf)) {
        throw "Configured file not found: $resolvedSourceFilePath"
    }

    if ($seenPaths.Add($resolvedSourceFilePath)) {
        $backupItems.Add([pscustomobject]@{
            SourcePath = $resolvedSourceFilePath
            ArchivePath = Get-ArchiveEntryPath -ConfiguredPath $sourcePath -ResolvedPath $resolvedSourceFilePath
        }) | Out-Null
    }
}

if ($backupItems.Count -eq 0) {
    throw "No source files found to back up."
}

if ($WhatIf) {
    Write-Host "[WhatIf] Would create archive: $resolvedOutputFile"
    foreach ($item in $backupItems) {
        Write-Host ("[WhatIf] Would include: {0} -> {1}" -f $item.SourcePath, $item.ArchivePath)
    }
    exit 0
}

$outputDirectory = Split-Path -Path $resolvedOutputFile -Parent
if (-not [string]::IsNullOrWhiteSpace($outputDirectory) -and -not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $outputDirectory -Force)
}

$stagingDirectory = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid().ToString("N"))
[void](New-Item -ItemType Directory -Path $stagingDirectory -Force)

try {
    foreach ($item in $backupItems) {
        $stagedFilePath = Join-Path -Path $stagingDirectory -ChildPath ($item.ArchivePath -replace "/", "\")
        $stagedDirectory = Split-Path -Path $stagedFilePath -Parent
        if (-not (Test-Path -LiteralPath $stagedDirectory -PathType Container)) {
            [void](New-Item -ItemType Directory -Path $stagedDirectory -Force)
        }

        Copy-Item -LiteralPath $item.SourcePath -Destination $stagedFilePath -Force
    }

    if (Test-Path -LiteralPath $resolvedOutputFile -PathType Leaf) {
        Remove-Item -LiteralPath $resolvedOutputFile -Force
    }

    & tar -czf $resolvedOutputFile -C $stagingDirectory .
    if ($LASTEXITCODE -ne 0) {
        throw "tar failed with exit code $LASTEXITCODE."
    }

    Write-Host "Created backup: $resolvedOutputFile"
    Write-Host ("Included source files: {0}" -f $backupItems.Count)
}
finally {
    if (Test-Path -LiteralPath $stagingDirectory -PathType Container) {
        Remove-Item -LiteralPath $stagingDirectory -Recurse -Force
    }
}
