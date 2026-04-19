param(
    [Parameter(Mandatory = $true)]
    [string]$RuleFile,

    [string]$ValueMapFile,

    [switch]$Indented,

    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Web.Extensions
$JsonSerializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$JsonSerializer.MaxJsonLength = 67108864
$JsonArrayWildcardToken = "[*]"

function Get-FileEncodingInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [pscustomobject]@{
            Encoding = [System.Text.UTF8Encoding]::new($true, $true)
            HasBom = $true
        }
    }

    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        return [pscustomobject]@{
            Encoding = [System.Text.UnicodeEncoding]::new($false, $true, $true)
            HasBom = $true
        }
    }

    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        return [pscustomobject]@{
            Encoding = [System.Text.UnicodeEncoding]::new($true, $true, $true)
            HasBom = $true
        }
    }

    try {
        [void][System.Text.UTF8Encoding]::new($false, $true).GetString($bytes)
        return [pscustomobject]@{
            Encoding = [System.Text.UTF8Encoding]::new($false, $true)
            HasBom = $false
        }
    }
    catch [System.Text.DecoderFallbackException] {
        return [pscustomobject]@{
            Encoding = [System.Text.Encoding]::Default
            HasBom = $false
        }
    }
}

function Read-JsonTextFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $encodingInfo = Get-FileEncodingInfo -FilePath $FilePath
    return [pscustomobject]@{
        Content = [System.IO.File]::ReadAllText($FilePath, $encodingInfo.Encoding)
        Encoding = $encodingInfo.Encoding
        HasBom = $encodingInfo.HasBom
    }
}

function Write-JsonTextFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [System.Text.Encoding]$Encoding,

        [Parameter(Mandatory = $true)]
        [bool]$HasBom
    )

    if ($Encoding -is [System.Text.UTF8Encoding]) {
        $Encoding = [System.Text.UTF8Encoding]::new($HasBom)
    }

    [System.IO.File]::WriteAllText($FilePath, $Content, $Encoding)
}

function ConvertFrom-JsonPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "JSON path must not be empty."
    }

    $trimmed = $Path.Trim()
    if ($trimmed.StartsWith("$")) {
        $trimmed = $trimmed.Substring(1)
    }
    if ($trimmed.StartsWith(".")) {
        $trimmed = $trimmed.Substring(1)
    }

    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return @()
    }

    $tokens = New-Object System.Collections.Generic.List[object]
    foreach ($segment in $trimmed.Split(".")) {
        if ([string]::IsNullOrWhiteSpace($segment)) {
            throw "Invalid JSON path '$Path'."
        }

        $rest = $segment
        while ($rest.Length -gt 0) {
            if ($rest -match "^[^\[\]]+") {
                $name = $Matches[0]
                $tokens.Add($name)
                $rest = $rest.Substring($name.Length)
                continue
            }

            if ($rest -match "^\[(\d+)\]") {
                $index = [int]$Matches[1]
                $tokens.Add($index)
                $rest = $rest.Substring($Matches[0].Length)
                continue
            }

            if ($rest.StartsWith($JsonArrayWildcardToken)) {
                $tokens.Add($JsonArrayWildcardToken)
                $rest = $rest.Substring($JsonArrayWildcardToken.Length)
                continue
            }

            throw "Invalid JSON path '$Path'."
        }
    }

    return ,$tokens.ToArray()
}

function Get-JsonValue {
    param(
        [Parameter(Mandatory = $true)]
        $Root,

        [Parameter(Mandatory = $true)]
        [object[]]$Tokens
    )

    $current = $Root
    foreach ($token in $Tokens) {
        if ($token -is [int]) {
            if (-not ($current -is [System.Collections.IList])) {
                return [pscustomobject]@{ Found = $false; Value = $null }
            }

            if ($token -ge $current.Count) {
                return [pscustomobject]@{ Found = $false; Value = $null }
            }

            $current = $current[$token]
            continue
        }

        if (-not ($current -is [System.Collections.IDictionary])) {
            return [pscustomobject]@{ Found = $false; Value = $null }
        }

        if (-not ($current.Keys -contains $token)) {
            return [pscustomobject]@{ Found = $false; Value = $null }
        }

        $current = $current[$token]
    }

    return [pscustomobject]@{ Found = $true; Value = $current }
}

function New-ContainerForNextToken {
    param(
        [Parameter(Mandatory = $true)]
        $NextToken
    )

    if ($NextToken -is [int]) {
        return (New-Object System.Collections.ArrayList)
    }

    return @{}
}

function Set-ListSize {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IList]$List,

        [Parameter(Mandatory = $true)]
        [int]$Index
    )

    while ($List.Count -le $Index) {
        [void]$List.Add($null)
    }
}

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

function ConvertTo-JsonLiteral {
    param(
        [Parameter(Mandatory = $true)]
        $Value
    )

    return $JsonSerializer.Serialize($Value)
}

function Format-JsonValue {
    param(
        [Parameter(Mandatory = $true)]
        $Value,

        [Parameter(Mandatory = $true)]
        [int]$Level
    )

    if ($null -eq $Value) {
        return "null"
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $keys = @($Value.Keys)
        if ($keys.Count -eq 0) {
            return "{}"
        }

        $indent = ("  " * $Level)
        $childIndent = ("  " * ($Level + 1))
        $lines = New-Object System.Collections.Generic.List[string]
        foreach ($key in $keys) {
            $formattedValue = Format-JsonValue -Value $Value[$key] -Level ($Level + 1)
            $lines.Add($childIndent + (ConvertTo-JsonLiteral -Value ([string]$key)) + ": " + $formattedValue)
        }

        return "{`n" + ($lines -join ",`n") + "`n" + $indent + "}"
    }

    if (($Value -is [System.Collections.IList]) -and -not ($Value -is [string])) {
        if ($Value.Count -eq 0) {
            return "[]"
        }

        $indent = ("  " * $Level)
        $childIndent = ("  " * ($Level + 1))
        $lines = New-Object System.Collections.Generic.List[string]
        foreach ($item in $Value) {
            $lines.Add($childIndent + (Format-JsonValue -Value $item -Level ($Level + 1)))
        }

        return "[`n" + ($lines -join ",`n") + "`n" + $indent + "]"
    }

    return (ConvertTo-JsonLiteral -Value $Value)
}

function Set-JsonValue {
    param(
        [Parameter(Mandatory = $true)]
        $Root,

        [Parameter(Mandatory = $true)]
        [object[]]$Tokens,

        [Parameter(Mandatory = $true)]
        $Value
    )

    if ($Tokens.Count -eq 0) {
        throw "An empty target path is not supported."
    }

    $current = $Root
    for ($i = 0; $i -lt $Tokens.Count - 1; $i++) {
        $token = $Tokens[$i]
        $nextToken = $Tokens[$i + 1]

        if ($token -is [int]) {
            if (-not ($current -is [System.Collections.IList])) {
                throw "Cannot create path. Expected a list."
            }

                Set-ListSize -List $current -Index $token
            if ($null -eq $current[$token]) {
                $current[$token] = New-ContainerForNextToken -NextToken $nextToken
            }
            $current = $current[$token]
            continue
        }

        if (-not ($current -is [System.Collections.IDictionary])) {
            throw "Cannot create path. Expected an object."
        }

        if (-not ($current.Keys -contains $token) -or $null -eq $current[$token]) {
            $current[$token] = New-ContainerForNextToken -NextToken $nextToken
        }
        $current = $current[$token]
    }

    $lastToken = $Tokens[$Tokens.Count - 1]
    if ($lastToken -is [int]) {
        if (-not ($current -is [System.Collections.IList])) {
            throw "Target path ends with an index, but the target is not a list."
        }

        Set-ListSize -List $current -Index $lastToken
        $current[$lastToken] = $Value
        return
    }

    if (-not ($current -is [System.Collections.IDictionary])) {
        throw "Target path ends with a property, but the target is not an object."
    }

    $current[$lastToken] = $Value
}

function Add-JsonMatches {
    param(
        [Parameter(Mandatory = $true)]
        $Current,

        [object[]]$RemainingTokens,

        [object[]]$ResolvedTokens,

        [System.Collections.ArrayList]$MatchList
    )

    if ($RemainingTokens.Count -eq 0) {
        [void]$MatchList.Add([pscustomobject]@{
            Value = $Current
            ResolvedTokens = $ResolvedTokens
        })
        return
    }

    $token = $RemainingTokens[0]
    $nextTokens = @()
    if ($RemainingTokens.Count -gt 1) {
        $nextTokens = @($RemainingTokens[1..($RemainingTokens.Count - 1)])
    }

    if ($token -eq $JsonArrayWildcardToken) {
        if (-not ($Current -is [System.Collections.IList])) {
            return
        }

        for ($i = 0; $i -lt $Current.Count; $i++) {
            Add-JsonMatches -Current $Current[$i] -RemainingTokens $nextTokens -ResolvedTokens ($ResolvedTokens + $i) -MatchList $MatchList
        }
        return
    }

    if ($token -is [int]) {
        if (-not ($Current -is [System.Collections.IList])) {
            return
        }

        if ($token -ge $Current.Count) {
            return
        }

        Add-JsonMatches -Current $Current[$token] -RemainingTokens $nextTokens -ResolvedTokens ($ResolvedTokens + $token) -MatchList $MatchList
        return
    }

    if (-not ($Current -is [System.Collections.IDictionary])) {
        return
    }

    if (-not ($Current.Keys -contains $token)) {
        return
    }

    Add-JsonMatches -Current $Current[$token] -RemainingTokens $nextTokens -ResolvedTokens ($ResolvedTokens + $token) -MatchList $MatchList
}

function Get-JsonMatches {
    param(
        [Parameter(Mandatory = $true)]
        $Root,

        [Parameter(Mandatory = $true)]
        [object[]]$Tokens
    )

    $matchList = New-Object System.Collections.ArrayList
    Add-JsonMatches -Current $Root -RemainingTokens $Tokens -ResolvedTokens @() -MatchList $matchList
    return @($matchList)
}

function Get-WildcardCount {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Tokens
    )

    $count = 0
    foreach ($token in $Tokens) {
        if ($token -eq $JsonArrayWildcardToken) {
            $count++
        }
    }

    return $count
}

function Resolve-TargetTokens {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$SourceTemplateTokens,

        [Parameter(Mandatory = $true)]
        [object[]]$TemplateTokens,

        [Parameter(Mandatory = $true)]
        [object[]]$ResolvedSourceTokens
    )

    $resolvedTargetTokens = New-Object System.Collections.Generic.List[object]
    $wildcardIndexes = New-Object System.Collections.Generic.List[object]

    for ($i = 0; $i -lt $SourceTemplateTokens.Count; $i++) {
        if ($SourceTemplateTokens[$i] -eq $JsonArrayWildcardToken) {
            $wildcardIndexes.Add($ResolvedSourceTokens[$i]) | Out-Null
        }
    }

    $wildcardPosition = 0
    foreach ($token in $TemplateTokens) {
        if ($token -eq $JsonArrayWildcardToken) {
            if ($wildcardPosition -ge $wildcardIndexes.Count) {
                throw "Target path wildcard count does not match the source path."
            }

            $resolvedTargetTokens.Add($wildcardIndexes[$wildcardPosition]) | Out-Null
            $wildcardPosition++
            continue
        }

        $resolvedTargetTokens.Add($token) | Out-Null
    }

    return ,$resolvedTargetTokens.ToArray()
}

function Test-IgnoredRuleValue {
    param(
        $Value,
        $IgnoredValues
    )

    if ($null -eq $IgnoredValues) {
        return $false
    }

    $ignoredValuesArray = @($IgnoredValues)
    if ($ignoredValuesArray.Count -eq 0) {
        return $false
    }

    foreach ($ignoredValue in $ignoredValuesArray) {
        if ($null -eq $Value -and $null -eq $ignoredValue) {
            return $true
        }

        if ($null -ne $Value -and $Value -eq $ignoredValue) {
            return $true
        }
    }

    return $false
}

function Get-OptionalRuleProperty {
    param(
        [Parameter(Mandatory = $true)]
        $Rule,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName
    )

    $property = $Rule.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Get-ValueMapLookupTable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MapName,

        [Parameter(Mandatory = $true)]
        $ValueMapConfig
    )

    $namedMap = $ValueMapConfig.PSObject.Properties[$MapName]
    if ($null -eq $namedMap) {
        throw "Value map '$MapName' not found in the configured value map file."
    }

    if ($namedMap.Value -isnot [System.Collections.IDictionary] -and $namedMap.Value -isnot [pscustomobject]) {
        throw "Value map '$MapName' in the configured value map file must be a JSON object."
    }

    return $namedMap.Value
}

function Resolve-RuleOutputValue {
    param(
        [Parameter(Mandatory = $true)]
        $Rule,

        [Parameter(Mandatory = $true)]
        $InputValue,

        $ValueMapConfig
    )

    $mapName = Get-OptionalRuleProperty -Rule $Rule -PropertyName "replaceFromMap"
    if ([string]::IsNullOrWhiteSpace($mapName)) {
        return $InputValue
    }

    if ($null -eq $ValueMapConfig) {
        throw "Rule with replaceFromMap '$mapName' requires -ValueMapFile."
    }

    $lookupTable = Get-ValueMapLookupTable -MapName ([string]$mapName) -ValueMapConfig $ValueMapConfig
    if ($null -eq $InputValue) {
        return $InputValue
    }

    $lookupKey = [string]$InputValue
    if ($lookupTable -is [System.Collections.IDictionary]) {
        if ($lookupTable.Contains($lookupKey)) {
            return $lookupTable[$lookupKey]
        }

        return $InputValue
    }

    if ([string]::IsNullOrEmpty($lookupKey)) {
        return $InputValue
    }

    $mappedProperty = $lookupTable.PSObject.Properties | Where-Object { $_.Name -eq $lookupKey } | Select-Object -First 1
    if ($null -ne $mappedProperty) {
        return $mappedProperty.Value
    }

    return $InputValue
}

function Update-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFilePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationFilePath,

        [Parameter(Mandatory = $true)]
        [object[]]$Rules,

        $ValueMapConfig,

        [switch]$UseIndentedFormatting,

        [switch]$PreviewOnly
    )

    $inputFile = Read-JsonTextFile -FilePath $SourceFilePath
    $document = $JsonSerializer.DeserializeObject($inputFile.Content)
    $changed = $false

    foreach ($rule in $Rules) {
        if ([string]::IsNullOrWhiteSpace($rule.sourcePath)) {
            throw "Rule for '$SourceFilePath' is missing 'sourcePath'."
        }

        if ([string]::IsNullOrWhiteSpace($rule.targetPath)) {
            throw "Rule for '$SourceFilePath' is missing 'targetPath'."
        }

        $sourceTokens = ConvertFrom-JsonPath -Path $rule.sourcePath
        $targetTokens = ConvertFrom-JsonPath -Path $rule.targetPath
        $ignoredValues = Get-OptionalRuleProperty -Rule $rule -PropertyName "ignoreValues"
        $sourceWildcardCount = Get-WildcardCount -Tokens $sourceTokens
        $targetWildcardCount = Get-WildcardCount -Tokens $targetTokens

        if ($targetWildcardCount -gt 0 -and $sourceWildcardCount -ne $targetWildcardCount) {
            throw "Rule for '$SourceFilePath' must use the same number of wildcards in sourcePath and targetPath."
        }

        if ($sourceWildcardCount -gt 0) {
            $jsonMatches = @(Get-JsonMatches -Root $document -Tokens $sourceTokens)
            if ($jsonMatches.Count -eq 0) {
                Write-Warning "Source path not found: '$($rule.sourcePath)' in '$SourceFilePath'"
                continue
            }

            foreach ($match in $jsonMatches) {
                if (Test-IgnoredRuleValue -Value $match.Value -IgnoredValues $ignoredValues) {
                    continue
                }

                $outputValue = Resolve-RuleOutputValue -Rule $rule -InputValue $match.Value -ValueMapConfig $ValueMapConfig
                $resolvedTargetTokens = Resolve-TargetTokens -SourceTemplateTokens $sourceTokens -TemplateTokens $targetTokens -ResolvedSourceTokens $match.ResolvedTokens
                Set-JsonValue -Root $document -Tokens $resolvedTargetTokens -Value $outputValue
                $changed = $true
            }
            continue
        }

        $result = Get-JsonValue -Root $document -Tokens $sourceTokens

        if (-not $result.Found) {
            Write-Warning "Source path not found: '$($rule.sourcePath)' in '$SourceFilePath'"
            continue
        }

        if (Test-IgnoredRuleValue -Value $result.Value -IgnoredValues $ignoredValues) {
            continue
        }

        $outputValue = Resolve-RuleOutputValue -Rule $rule -InputValue $result.Value -ValueMapConfig $ValueMapConfig
        Set-JsonValue -Root $document -Tokens $targetTokens -Value $outputValue
        $changed = $true
    }

    if (-not $changed) {
        return $false
    }

    if ($PreviewOnly) {
        if ($SourceFilePath -eq $DestinationFilePath) {
            Write-Host "[WhatIf] Would update file: $DestinationFilePath"
        }
        else {
            Write-Host "[WhatIf] Would write file: $DestinationFilePath (source: $SourceFilePath)"
        }
        return $true
    }

    $destinationDirectory = Split-Path -Path $DestinationFilePath -Parent
    if (-not [string]::IsNullOrWhiteSpace($destinationDirectory) -and -not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $destinationDirectory -Force)
    }

    $updatedJson = $JsonSerializer.Serialize($document)
    if ($UseIndentedFormatting) {
        $updatedJson = Format-JsonValue -Value $document -Level 0
    }

    Write-JsonTextFile -FilePath $DestinationFilePath -Content $updatedJson -Encoding $inputFile.Encoding -HasBom $inputFile.HasBom

    if ($SourceFilePath -eq $DestinationFilePath) {
        Write-Host "Updated: $DestinationFilePath"
    }
    else {
        Write-Host "Written: $DestinationFilePath (source: $SourceFilePath)"
    }

    return $true
}

if (-not (Test-Path -LiteralPath $RuleFile -PathType Leaf)) {
    throw "Rule file not found: $RuleFile"
}

$resolvedValueMapFilePath = $null
$valueMapConfig = $null
if (-not [string]::IsNullOrWhiteSpace($ValueMapFile)) {
    $expandedValueMapPath = Expand-ConfigEnvironmentVariables -InputText $ValueMapFile
    $resolvedValueMapFilePath = Resolve-ConfigPath -ConfigFilePath $RuleFile -ConfiguredPath $expandedValueMapPath
    if (-not (Test-Path -LiteralPath $resolvedValueMapFilePath -PathType Leaf)) {
        throw "Value map file not found: $resolvedValueMapFilePath"
    }

    $valueMapFileContent = Read-JsonTextFile -FilePath $resolvedValueMapFilePath
    $valueMapConfig = $valueMapFileContent.Content | ConvertFrom-Json
}

$ruleFileContent = Read-JsonTextFile -FilePath $RuleFile
$ruleConfig = $ruleFileContent.Content | ConvertFrom-Json
$fileEntries = @($ruleConfig.files)
if ($fileEntries.Count -eq 0) {
    throw "The rule file does not contain any file entries."
}

$processed = 0
foreach ($fileEntry in $fileEntries) {
    if ([string]::IsNullOrWhiteSpace($fileEntry.path)) {
        throw "Each file entry must contain 'path'."
    }

    $rules = @($fileEntry.rules)
    if ($rules.Count -eq 0) {
        throw "File entry '$($fileEntry.path)' does not contain any rules."
    }

    $sourcePath = Expand-ConfigEnvironmentVariables -InputText ([string]$fileEntry.path)
    $resolvedSourceFilePath = Resolve-ConfigPath -ConfigFilePath $RuleFile -ConfiguredPath $sourcePath
    if (-not (Test-Path -LiteralPath $resolvedSourceFilePath -PathType Leaf)) {
        throw "Configured file not found: $resolvedSourceFilePath"
    }

    # Default to in-place updates when no file-level targetPath is configured.
    $resolvedDestinationFilePath = $resolvedSourceFilePath
    $targetPath = Get-OptionalRuleProperty -Rule $fileEntry -PropertyName "targetPath"
    if (-not [string]::IsNullOrWhiteSpace($targetPath)) {
        $destinationPath = Expand-ConfigEnvironmentVariables -InputText ([string]$targetPath)
        $resolvedDestinationFilePath = Resolve-ConfigPath -ConfigFilePath $RuleFile -ConfiguredPath $destinationPath
    }

    if (Update-JsonFile -SourceFilePath $resolvedSourceFilePath -DestinationFilePath $resolvedDestinationFilePath -Rules $rules -ValueMapConfig $valueMapConfig -UseIndentedFormatting:$Indented -PreviewOnly:$WhatIf) {
        $processed++
    }
}

Write-Host "Done. Changed files: $processed"
