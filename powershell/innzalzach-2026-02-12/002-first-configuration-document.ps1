#region PowerShell DSC (v2) - The "Old" Way
# PowerShell DSC uses Configuration blocks written in PowerShell
# Compiled to MOF files, Windows-only, requires PowerShell 5.1+

Configuration MyConfiguration
{
    param
    (
        [System.String]
        $ComputerName = 'localhost'
    )
    
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    
    Node $ComputerName
    {
        Registry TestKey
        {
            Key       = 'HKLM:\Software\MyApp'
            ValueName = 'Version'
            ValueData = '1.0.0'
            Ensure    = 'Present'
        }
    }
}

# To use it:
# MyConfiguration -OutputPath C:\DSC
# Start-DscConfiguration -Path C:\DSC -Wait -Verbose
#endregion PowerShell DSC (v2) - The "Old" Way

#region Microsoft DSC (v3) - The "New" Way
# Microsoft DSC uses YAML or JSON configuration documents
# No compilation needed, cross-platform (Windows, Linux, macOS)
# PowerShell not required, uses declarative schema

# Setup VSCode for Microsoft DSC schema IntelliSense
$schema = [ordered]@{
    'json.schemas' = @(
        @{
            fileMatch = @('**/*.dsc.json', '**/*.dsc.config.json')
            url       = 'https://aka.ms/dsc/schemas/v3/bundled/config/document.vscode.json'
        }
    )
    'yaml.schemas' = @{
        'https://aka.ms/dsc/schemas/v3/bundled/config/document.vscode.json' = '**.dsc.{yaml,yml,config.yaml,config.yml}'
    }
} | ConvertTo-Json -Depth 10

$settingsFile = Join-Path (Get-Location) '.vscode' 'settings.json'
if (-not (Test-Path -Path (Join-Path (Get-Location) '.vscode'))) {
    New-Item -Path (Join-Path (Get-Location) '.vscode') -ItemType Directory | Out-Null
}
Set-Content -Path $settingsFile -Value $schema

# Create registry.dsc.config.yaml
New-Item registry.dsc.config.yaml -ItemType File -Force -Value @"
`$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.vscode.json
"@
# Retrieve properties (no IntelliSense yet)
dsc resource schema --resource Microsoft.Windows/Registry 

dsc config test --file registry.dsc.config.yaml
# the _inDesiredState canonical property indicates whether the resource is in the desired state
dsc config set --file registry.dsc.config.yaml

dsc config get --file registry.dsc.config.yaml
# The _exist canonical property is the new way of ensuring presence/absence (Ensure = 'Present'/'Absent' in PowerShell DSC)
