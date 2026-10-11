#Requires -Version 7.0
<#
.SYNOPSIS
    Runs the Azure Policy Linter against policy definition files and fails when findings reach a severity threshold.

.DESCRIPTION
    The Azure Policy Linter (policylinter) exits with 0 whenever it ran successfully, even when a policy
    has Error-severity findings. That is by design: the exit code reports whether the tool could do its
    job, not whether the policies are healthy. This wrapper adds the gate a CI pipeline needs:

      1. Discovers *.json and *.jsonc policy definition files under -Path.
      2. Installs the Microsoft.Azure.Policy.PolicyLinter.Cli .NET tool when it isn't available.
      3. Runs the linter in batches and merges the JSON results.
      4. Prints the findings. On an Azure Pipelines agent it also emits ##vso logging commands, so
         findings appear as annotations in the run summary and link back to the source line.
      5. Writes a merged JSON results file and a Markdown summary.
      6. Exits 1 when any finding has a severity at or above -FailOn, unless its rule is in -ExcludeRule.

.PARAMETER Path
    One or more files or folders to lint. Folders are searched recursively.
    Defaults to ./Definitions/policyDefinitions.

.PARAMETER FailOn
    Lowest severity that fails the run: Error, Warning, Informational, or None. Defaults to Warning.

.PARAMETER ExcludeRule
    Rule identifiers whose findings are reported but never fail the run, for example
    field-alias-unavailable-in-old-api-versions. Use this for findings you have reviewed and accepted.

.PARAMETER OutputPath
    Where to write the merged JSON results. The Markdown summary is written next to it.
    Defaults to ./Output/lint/policy-lint-results.json.

.PARAMETER RuleSet
    One or more linter rule sets to apply. When omitted, the linter uses its default rule set.

.PARAMETER ToolVersion
    Pin the linter version. When omitted, the latest version is installed if the tool is missing and an
    existing installation is left untouched.

.PARAMETER SkipInstall
    Never install or update the tool. Fails if policylinter isn't on the PATH.

.PARAMETER BatchSize
    Maximum number of files passed to one policylinter invocation. Keeps the command line short on
    Windows agents. Defaults to 200; the linter itself accepts up to 1,000.

.PARAMETER PassThru
    Also return the findings as objects.

.EXAMPLE
    ./scripts/Invoke-PolicyLinter.ps1

    Lints ./Definitions/policyDefinitions and fails on Warning or Error findings.

.EXAMPLE
    ./scripts/Invoke-PolicyLinter.ps1 -Path ./samples/lint-findings -FailOn None -PassThru |
        Format-Table Severity, RuleIdentifier, Line, File

    Lints the sample files, never fails, and shows the findings as a table.

.EXAMPLE
    ./scripts/Invoke-PolicyLinter.ps1 -ExcludeRule field-alias-unavailable-in-old-api-versions

    Fails on warnings, except for the alias rule you have reviewed and accepted.

.LINK
    https://github.com/Azure/azure-policy-linter
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Console output and ##vso logging commands must go to the host, not the output stream, so -PassThru stays clean.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'RuleSet, ToolVersion and SkipInstall are read inside nested functions.')]
param (
    [Parameter(Position = 0)]
    [string[]] $Path = @('./Definitions/policyDefinitions'),

    [ValidateSet('Error', 'Warning', 'Informational', 'None')]
    [string] $FailOn = 'Warning',

    [string[]] $ExcludeRule = @(),

    [string] $OutputPath = './Output/lint/policy-lint-results.json',

    [string[]] $RuleSet,

    [string] $ToolVersion,

    [switch] $SkipInstall,

    [ValidateRange(1, 1000)]
    [int] $BatchSize = 200,

    [switch] $PassThru
)

$ErrorActionPreference = 'Stop'

$toolPackageId = 'Microsoft.Azure.Policy.PolicyLinter.Cli'
$severityRank = @{ Unknown = 0; Informational = 1; Warning = 2; Error = 3; Critical = 4 }
$severityColor = @{ Unknown = 'Gray'; Informational = 'Cyan'; Warning = 'Yellow'; Error = 'Red'; Critical = 'Red' }
$isAzurePipelines = $env:TF_BUILD -eq 'True'
$sourcesRoot = if ($env:BUILD_SOURCESDIRECTORY) { $env:BUILD_SOURCESDIRECTORY } else { (Get-Location).ProviderPath }

function Get-RelativePath {
    param ([string] $FullPath)
    $relative = [System.IO.Path]::GetRelativePath($sourcesRoot, $FullPath)
    return $relative.Replace('\', '/')
}

function Install-PolicyLinter {
    # Global .NET tools live in ~/.dotnet/tools, which isn't always on the PATH of a fresh pipeline step.
    $toolsDir = Join-Path $HOME '.dotnet/tools'
    if ((Test-Path $toolsDir) -and (($env:PATH -split [System.IO.Path]::PathSeparator) -notcontains $toolsDir)) {
        $env:PATH = "$toolsDir$([System.IO.Path]::PathSeparator)$env:PATH"
    }

    $existing = Get-Command policylinter -ErrorAction SilentlyContinue
    if ($existing -and -not $ToolVersion) {
        return
    }
    if ($SkipInstall) {
        throw "policylinter was not found on the PATH and -SkipInstall was specified. Install it with: dotnet tool install --global $toolPackageId"
    }
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        throw 'The .NET SDK is required to install the Azure Policy Linter. Install .NET 8 or later, or add a UseDotNet task before this step.'
    }

    $verb = if ($existing) { 'update' } else { 'install' }
    $arguments = @('tool', $verb, '--global', $toolPackageId)
    if ($ToolVersion) {
        $arguments += @('--version', $ToolVersion)
    }
    Write-Host "Running: dotnet $($arguments -join ' ')"
    & dotnet @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet tool $verb failed with exit code $LASTEXITCODE."
    }
    if (-not (Get-Command policylinter -ErrorAction SilentlyContinue)) {
        throw "policylinter is still not on the PATH after installation. Add $toolsDir to the PATH and retry."
    }
}

function Get-PolicyDefinitionFile {
    param ([string[]] $Paths)
    $files = foreach ($candidate in $Paths) {
        if (-not (Test-Path $candidate)) {
            Write-Warning "Path not found: $candidate"
            continue
        }
        $item = Get-Item $candidate
        if ($item.PSIsContainer) {
            Get-ChildItem -Path $item.FullName -Recurse -File | Where-Object { $_.Extension -in '.json', '.jsonc' }
        }
        else {
            $item
        }
    }
    return $files | Sort-Object FullName -Unique
}

function Invoke-LinterBatch {
    param ([string[]] $Files, [string] $ResultPath)

    $arguments = @($Files) + @('--output', $ResultPath)
    foreach ($name in $RuleSet) {
        $arguments += @('--rule-set', $name)
    }

    $consoleOutput = & policylinter @arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("policylinter exited with code $LASTEXITCODE. A non-zero exit code means the tool could not complete " +
            "(unreadable file, unknown rule set, or unwritable output), not that a policy has findings.`n" +
            ($consoleOutput -join [Environment]::NewLine))
    }
    $consoleOutput | ForEach-Object { Write-Verbose $_ }

    if (-not (Test-Path $ResultPath)) {
        throw "policylinter did not write $ResultPath."
    }
    return Get-Content -Path $ResultPath -Raw | ConvertFrom-Json -AsHashtable
}

Install-PolicyLinter
$toolVersionText = ((& policylinter --version 2>$null | Select-Object -First 1) -split '\+')[0]
$files = @(Get-PolicyDefinitionFile -Paths $Path)
if ($files.Count -eq 0) {
    Write-Warning "No .json or .jsonc files found under: $($Path -join ', ')"
    exit 0
}
Write-Host "Azure Policy Linter $toolVersionText, linting $($files.Count) file(s), failing on '$FailOn' or higher."
if ($ExcludeRule.Count -gt 0) {
    Write-Host "Excluded from the gate: $($ExcludeRule -join ', ')"
}

$outputFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
$outputFolder = Split-Path -Path $outputFile -Parent
New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null

$tempFolder = Join-Path ([System.IO.Path]::GetTempPath()) "policylinter-$([guid]::NewGuid().ToString('n'))"
New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null

$merged = [ordered]@{}
try {
    $batchIndex = 0
    for ($start = 0; $start -lt $files.Count; $start += $BatchSize) {
        $end = [Math]::Min($start + $BatchSize, $files.Count) - 1
        $batch = @($files[$start..$end] | ForEach-Object { $_.FullName })
        $result = Invoke-LinterBatch -Files $batch -ResultPath (Join-Path $tempFolder "batch-$batchIndex.json")
        foreach ($key in $result.Keys) {
            $merged[$key] = $result[$key]
        }
        $batchIndex++
    }
}
finally {
    Remove-Item -Path $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
}

$findings = foreach ($file in $merged.Keys) {
    foreach ($entry in @($merged[$file])) {
        [pscustomobject]@{
            Severity         = [string] $entry.severity
            RuleIdentifier   = $entry.ruleIdentifier
            Title            = $entry.title
            Description      = $entry.description
            File             = Get-RelativePath -FullPath $file
            Line             = $entry.lineNumber
            Column           = $entry.linePosition
            JsonPath         = $entry.path
            DocumentationUrl = $entry.documentationUrl
            Excluded         = $entry.ruleIdentifier -in $ExcludeRule
        }
    }
}
$findings = @($findings | Sort-Object @{ Expression = { $severityRank[$_.Severity] }; Descending = $true }, File, Line)

$counted = @($findings | Where-Object { -not $_.Excluded })
$errorCount = @($counted | Where-Object { $_.Severity -in 'Error', 'Critical' }).Count
$warningCount = @($counted | Where-Object { $_.Severity -eq 'Warning' }).Count
$infoCount = @($counted | Where-Object { $_.Severity -eq 'Informational' }).Count
$excludedCount = $findings.Count - $counted.Count

foreach ($group in ($findings | Group-Object -Property File)) {
    Write-Host ''
    Write-Host $group.Name -ForegroundColor Magenta
    foreach ($finding in $group.Group) {
        $location = if ($finding.Line) { "line $($finding.Line), column $($finding.Column)" } else { '' }
        $label = if ($finding.Excluded) { "$($finding.Severity), excluded" } else { $finding.Severity }
        $color = if ($finding.Excluded) { 'Gray' } else { $severityColor[$finding.Severity] }
        Write-Host ("  [{0}] {1} ({2}) {3}" -f $label, $finding.Title, $finding.RuleIdentifier, $location) -ForegroundColor $color
        Write-Host "      $($finding.Description)"

        if ($isAzurePipelines -and -not $finding.Excluded) {
            $issueType = switch ($finding.Severity) {
                { $_ -in 'Error', 'Critical' } { 'error' }
                'Warning' { 'warning' }
                default { $null }
            }
            if ($issueType) {
                $properties = "type=$issueType;sourcepath=$($finding.File);code=$($finding.RuleIdentifier)"
                if ($finding.Line) {
                    $properties += ";linenumber=$($finding.Line);columnnumber=$($finding.Column)"
                }
                Write-Host "##vso[task.logissue $properties]$($finding.Title): $($finding.Description)"
            }
        }
    }
}

$relativeResults = [ordered]@{}
foreach ($file in $merged.Keys) {
    $relativeResults[(Get-RelativePath -FullPath $file)] = $merged[$file]
}
$relativeResults | ConvertTo-Json -Depth 20 | Set-Content -Path $outputFile -Encoding utf8

$summaryPath = Join-Path $outputFolder 'policy-lint-summary.md'
$summary = [System.Text.StringBuilder]::new()
[void] $summary.AppendLine('# Azure Policy Linter')
[void] $summary.AppendLine()
[void] $summary.AppendLine("Linted $($files.Count) file(s) with policylinter $toolVersionText. Fail threshold: $FailOn.")
[void] $summary.AppendLine()
[void] $summary.AppendLine('| Errors | Warnings | Informational | Excluded |')
[void] $summary.AppendLine('|---:|---:|---:|---:|')
[void] $summary.AppendLine("| $errorCount | $warningCount | $infoCount | $excludedCount |")
if ($findings.Count -gt 0) {
    [void] $summary.AppendLine()
    [void] $summary.AppendLine('| Severity | File | Line | Rule | Description |')
    [void] $summary.AppendLine('|---|---|---:|---|---|')
    foreach ($finding in $findings) {
        $rule = if ($finding.DocumentationUrl) { "[$($finding.RuleIdentifier)]($($finding.DocumentationUrl))" } else { $finding.RuleIdentifier }
        $severity = if ($finding.Excluded) { "$($finding.Severity) (excluded)" } else { $finding.Severity }
        $description = ($finding.Description -replace '\|', '\|')
        [void] $summary.AppendLine("| $severity | ``$($finding.File)`` | $($finding.Line) | $rule | $description |")
    }
}
$summary.ToString() | Set-Content -Path $summaryPath -Encoding utf8
if ($isAzurePipelines) {
    Write-Host "##vso[task.uploadsummary]$summaryPath"
}

Write-Host ''
Write-Host ("Findings: {0} error(s), {1} warning(s), {2} informational, {3} excluded. Results written to {4}" -f $errorCount, $warningCount, $infoCount, $excludedCount, $outputFile)

if ($PassThru) {
    $findings
}

$threshold = if ($FailOn -eq 'None') { [int]::MaxValue } else { $severityRank[$FailOn] }
$blocking = @($counted | Where-Object { $severityRank[$_.Severity] -ge $threshold })
if ($blocking.Count -gt 0) {
    Write-Host "$($blocking.Count) finding(s) at severity '$FailOn' or higher. Fix them, add their rule to -ExcludeRule after review, or lower -FailOn." -ForegroundColor Red
    exit 1
}

Write-Host 'Policy lint passed.' -ForegroundColor Green
exit 0
