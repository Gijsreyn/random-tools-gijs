# Use the $DSC_RESOURCE_PATH variable
Get-ChildItem 'C:\OpenDsc' | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination (Split-Path (Get-Command dsc).Path -Parent) -Force
}

# List the resources
dsc resource list 

# Say we wanna create a database
dsc resource schema --resource 'OpenDsc.SqlServer/Database' | 
    ConvertFrom-Json | 
    Select-Object -Property required

$in = @{
    serverInstance = '.'
    name = 'DSCDemo'
} | ConvertTo-Json -Compress
dsc resource get --resource 'OpenDsc.SqlServer/Database' --input $in

# Create it
dsc resource set --resource 'OpenDsc.SqlServer/Database' --input $in

# Create configuration document with IntelliSense