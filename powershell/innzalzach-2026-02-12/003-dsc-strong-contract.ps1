# Lets take a look at a resource that binds to DSC
$wingetPackageResource = dsc resource list | 
    ConvertFrom-Json | 
    Where-Object -Property type -eq 'Microsoft.WinGet/Package'
$wingetPackageResource

# How did we find it?
Get-Command winget 

$env:path.Split(";")

# Capabilities listed in the resource manifest
$wingetPackageResource.capabilities
# get 
# set 
# setHandlesExist (special capability indicating a resource can delete a resource based on the _exist canonical property)
# test 
# export (new capability introduced in Microsoft DSC)
dsc resource export --resource Microsoft.WinGet/Package # --input '{"name":"<package-name>*"}' # support filtering

# Lets see the setHandlesExist capability in action
dsc resource test --resource Microsoft.WinGet/Package --input '{"id":"Microsoft.OneDrive","_exist":false}'
dsc resource delete --resource Microsoft.WinGet/Package --input '{"id":"Microsoft.OneDrive"}' # error 
dsc resource set --resource Microsoft.WinGet/Package --input '{"id":"Microsoft.OneDrive","_exist":false}' # succeeds
