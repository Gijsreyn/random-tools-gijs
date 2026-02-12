# How does Microsoft DSC support backwards compatibility with PowerShell DSC?
$adapters = dsc resource list |
    ConvertFrom-Json | 
    Where-Object -Property kind -eq 'adapter'

# Three adapters shipped with Microsoft DSC
$adapters # WMI, PowerShell, WindowsPowerShell

# PowerShell adapters
# Microsoft.DSC/PowerShell # Only supports class-based DSC resources 
# Microsoft.Windows/WindowsPowerShell # Supports MOF-based and class-based DSC resources
$powerShell = $adapters | Where-Object -Property type -eq 'Microsoft.DSC/PowerShell'

# It's a resource manifest execution a PowerShell script
Get-Content -Path $powerShell.path  

# See the modules
$psDscModulePath = Join-Path (Split-Path (Get-Command dsc).Path -Parent) 'psDscAdapter'
Invoke-Item $psDscModulePath

$scriptPath = Join-Path $psDscModulePath 'powershell.resource.ps1'

# It needs to speak the language of Microsoft DSC: JSON input/output so lets look
$resources = . $scriptPath -Operation list
$resources 

# Looks familiar? It has adapted to the schemantics of DSC
$converted = $resources | ConvertFrom-Json

# Refresh cache by installing new module
$resources.Count
Install-PSResource -Name Microsoft.WinGet.DSC -Repository PSGallery -TrustRepository

$resources = . $scriptPath -Operation list
$resources.Count

# Do the same as we did with Microsoft.WinGet/Package
$jsonString = @{
    Id = 'Microsoft.PowerShell'
} | ConvertTo-Json -Compress
$out = . $scriptPath -Operation Get -JsonInput $jsonString -ResourceType 'Microsoft.WinGet.DSC/WinGetPackage' | ConvertFrom-Json
$out

# Do it through DSC's engine
$document = @{
    '$schema' = 'https://aka.ms/dsc/schemas/v3/bundled/config/document.json'
    metadata  = @{
        'Microsoft.DSC' = @{}
    }
    resources = @(
        @{
            name       = 'Use class PowerShell resources'
            type       = 'Microsoft.DSC/PowerShell'
            properties = @{
                resources = @(
                    @{
                        name       = 'PowerShell package'
                        type       = 'Microsoft.WinGet.DSC/WinGetPackage'
                        properties = @{
                            Id = 'Microsoft.PowerShell'
                        }
                    }
                )
            }
        }
    )
} | ConvertTo-Json -Depth 10 -Compress
dsc config get --input $document

# One good difference to keep in mind
Install-PSResource -Name SqlServerDsc -Repository PSGallery -TrustRepository 

# Re-list through class-based
$sqlServerClassBased = dsc resource list --adapter Microsoft.DSC/PowerShell |
    ConvertFrom-Json |
    Where-Object -Like *SqlServerDsc* # Not all resources available

# Copy the SQLServerDsc module to Windows PowerShell and run list
dsc resource list --adapter Microsoft.Windows/WindowsPowerShell # This is going to take some time (Get-DscResource from PSDesiredStateConfiguration v1.1)