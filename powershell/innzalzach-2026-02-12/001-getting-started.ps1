#region Installing Microsoft DSC
$uri = 'https://github.com/PowerShell/DSC/releases/download/v3.2.0-preview.11/DSC-3.2.0-preview.11-aarch64-pc-windows-msvc.zip'
$outFile = Join-Path -Path $env:TEMP -ChildPath 'DSC-3.2.0-preview.11-aarch64-pc-windows-msvc.zip'
Invoke-RestMethod -Uri $uri -OutFile $outFile

# Or use PSDSC module (not to confuse with PowerShell DSC)
Install-PSResource -Name PSDSC 

Install-DscExe -IncludePrerelease
#endregion Installing Microsoft DSC

#region Discovering resources 
# Old method
Get-DscResource # PowerShell DSC resources

# New method
dsc resource list # Microsoft DSC searches resource manifest on the system

$registryResource = dsc resource list | 
    ConvertFrom-Json | 
    Where-Object -Property type -eq 'Microsoft.Windows/Registry'

$registryResource # everything that ends with *.dsc.resource.json, .dsc.resource.yaml, .dsc.resource.yml will be found

Get-Content -Path $registryResource.path

registry --help # shows help for the registry resource executable
#endregion Discovering resources

#region Using a resource
# How do we use a resource?

# PowerShell DSC way
Invoke-DscResource -Name 'WindowsFeature' -Method 'Get' -Property @{
    # IntelliSense does not work here
} -ModuleName 'PSDesiredStateConfiguration'

# Find the properties
Get-DscResource -Name 'WindowsFeature' -Module PSDesiredStateConfiguration | Select-Object -ExpandProperty Properties

$properties = @{
    Name = 'Web-Server'
} # the properties we can use
Invoke-DscResource -Name 'WindowsFeature' -Method 'Get' -Property $properties -ModuleName 'PSDesiredStateConfiguration'

# Microsoft DSC way
# None actually exists yet, we have to do it with the schema contract
dsc resource get --resource Microsoft.Windows/Registry --input '{}' # no Intellisense

$json = @{
    keyPath = 'HKCU\Software\MyApplication'
} | ConvertTo-Json -Compress 
dsc resource test --resource Microsoft.Windows/Registry --input $json
#endregion Using a resource