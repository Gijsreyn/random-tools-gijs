#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Creates the two management groups that back the EPAC environments (dev and prod) if they don't exist yet.

.DESCRIPTION
    Idempotent bootstrap for the pipeline. Existing management groups are left untouched and reported.
    Missing ones are created under -ParentManagementGroupId, which defaults to the tenant root group.
    After creating a group the script waits until it can be read back, because a brand-new management
    group can take a short while before Azure Policy accepts it as a scope.

    The identity running the script needs the Management Group Contributor role on the parent
    management group. The tenant setting "Require write permissions for creating new management groups"
    only changes who may create groups directly under the root; writing into an existing parent always
    needs that role.

.PARAMETER ParentManagementGroupId
    Name (ID) of the parent management group. Empty or omitted means the tenant root group, whose ID
    equals the tenant ID.

.PARAMETER DevManagementGroupName
    ID of the development management group. Defaults to mg-epac-dev.

.PARAMETER DevDisplayName
    Display name of the development management group. Defaults to "EPAC Dev".

.PARAMETER ProdManagementGroupName
    ID of the production management group. Defaults to mg-epac-prod.

.PARAMETER ProdDisplayName
    Display name of the production management group. Defaults to "EPAC Prod".

.PARAMETER TimeoutSeconds
    How long to wait for a newly created management group to become readable. 0 disables the wait.
    Defaults to 180.

.EXAMPLE
    Connect-AzAccount
    ./scripts/New-PolicyManagementGroups.ps1 -WhatIf

    Shows which management groups would be created under the tenant root group.

.EXAMPLE
    ./scripts/New-PolicyManagementGroups.ps1 -ParentManagementGroupId 000000000-0000-0000-0000-000000000000

    Creates mg-epac-dev and mg-epac-prod under the specified management group.

.OUTPUTS
    One object per management group with Environment, Name, DisplayName, Id, and Status (Exists or Created).
#>
[CmdletBinding(SupportsShouldProcess)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Progress messages belong in the pipeline log, while the output stream carries the result objects.')]
param (
    [string] $ParentManagementGroupId,
    [string] $DevManagementGroupName = 'mg-epac-dev',
    [string] $DevDisplayName = 'EPAC Dev',
    [string] $ProdManagementGroupName = 'mg-epac-prod',
    [string] $ProdDisplayName = 'EPAC Prod',
    [ValidateRange(0, 900)]
    [int] $TimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'

$context = Get-AzContext
if (-not $context) {
    throw 'No Azure context found. Run Connect-AzAccount first, or run this script from an AzurePowerShell task.'
}

if ([string]::IsNullOrWhiteSpace($ParentManagementGroupId)) {
    $ParentManagementGroupId = $context.Tenant.Id
    Write-Host "No parent management group specified. Using the tenant root group ($ParentManagementGroupId)."
}
$parentResourceId = "/providers/Microsoft.Management/managementGroups/$ParentManagementGroupId"

function Get-ManagementGroupOrNull {
    param ([string] $Name)
    try {
        return Get-AzManagementGroup -GroupName $Name -ErrorAction Stop
    }
    catch {
        if ($_.Exception.Message -match 'NotFound|not found|does not exist') {
            return $null
        }
        throw
    }
}

function Wait-ManagementGroup {
    param ([string] $Name, [int] $Timeout)
    $deadline = (Get-Date).AddSeconds($Timeout)
    do {
        $group = Get-ManagementGroupOrNull -Name $Name
        if ($group) {
            return $group
        }
        Write-Host "Waiting for management group '$Name' to become readable..."
        Start-Sleep -Seconds 10
    } while ((Get-Date) -lt $deadline)
    throw "Management group '$Name' was created but not readable within $Timeout seconds."
}

$targets = @(
    [pscustomobject]@{ Environment = 'epac-dev'; Name = $DevManagementGroupName; DisplayName = $DevDisplayName }
    [pscustomobject]@{ Environment = 'epac-prod'; Name = $ProdManagementGroupName; DisplayName = $ProdDisplayName }
)

foreach ($target in $targets) {
    $existing = Get-ManagementGroupOrNull -Name $target.Name
    if ($existing) {
        if ($existing.ParentId -and $existing.ParentId -ne $parentResourceId) {
            Write-Warning "Management group '$($target.Name)' already exists under '$($existing.ParentId)', not under '$parentResourceId'. Leaving it where it is."
        }
        else {
            Write-Host "Management group '$($target.Name)' already exists."
        }
        [pscustomobject]@{
            Environment = $target.Environment
            Name        = $existing.Name
            DisplayName = $existing.DisplayName
            Id          = $existing.Id
            Status      = 'Exists'
        }
        continue
    }

    if (-not $PSCmdlet.ShouldProcess("$($target.Name) ('$($target.DisplayName)') under $parentResourceId", 'Create management group')) {
        continue
    }

    Write-Host "Creating management group '$($target.Name)' under '$parentResourceId'..."
    $created = New-AzManagementGroup -GroupName $target.Name -DisplayName $target.DisplayName -ParentId $parentResourceId
    if ($TimeoutSeconds -gt 0) {
        $created = Wait-ManagementGroup -Name $target.Name -Timeout $TimeoutSeconds
    }

    [pscustomobject]@{
        Environment = $target.Environment
        Name        = $created.Name
        DisplayName = $created.DisplayName
        Id          = $created.Id
        Status      = 'Created'
    }
}
