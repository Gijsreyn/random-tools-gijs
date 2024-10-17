# VSCodeSettingDSC

`VSCodeSettingDSC` is a project aimed at managing and automating Visual Studio Code user settings using Desired State Configuration (DSC). This project helps in maintaining consistent development environments across different machines by ensuring that VS Code settings are configured as per the desired state.

Visual Studio Code has two options to configure settings. Either through the user interface or modifying the `settings.json`. The `settings.json` can be workspace or user specific. User specific settings are stored in `$env:APPDATA\Roaming\Code\User\settings.json`.

Using the `VSCodeSettingDSC` module, always manipulation in the `settings.json` file through a `configuration`.

## Features

- **Automated Configuration**: Automatically apply VS Code settings across multiple machines
- **Consistency**: Ensure consistent development environments
- **90+ settings**: Many settings available with `enums` to simplify coding
- **Ease of Use**: Simplify the process of setting up VS Code for new environments

## Installation

This module is published to the PSGallery. You can install the module on PowerShell 7+ using the following command:

```powershell
Install-PSResource -Name VSCodeSettingDSC
```

## Usage examples

To get started with the `VSCodeSettingDSC` module, you require the latest `PSDesiredStateConfiguration` module installed or use `dsc.exe`.

```powershell
# install both modules from the PSGallery
Install-PSResource -Name PSDesiredStateConfiguration, PSDSC

# to install 'dsc.exe', use the Install-DscCli command
Install-DscCli

# discover the available DSC resources
(Get-Module VSCodeSettingDSC).ExportedDscResources

# construct default parameters
$property = @{}

$state = Invoke-DscResource -ModuleName VSCodeSettingDSC -Name VSCodeDiffEditorSetting -Method Get -Property $property

$property.Add('CodeLens', $true)

# set the codelens property
Invoke-DscResource -ModuleName VSCodeSettingDSC -Name VSCodeDiffEditorSetting -Method Set -Property $property

# wanna use 'dsc.exe'
"{'CodeLens': true}" | dsc resource get -r 'VSCodeSettingDSC/VSCodeDiffEditorSetting'

# or document
$document = @'
$schema: https://raw.githubusercontent.com/PowerShell/DSC/main/schemas/2024/04/config/document.json
resources:
- name: Working with VSCodeSettingDSC
  type: Microsoft.DSC/PowerShell
  properties:
    resources:
    - name: VSCodeDiffEditorSetting
      type: VSCodeSettingDSC/VSCodeDiffEditorSetting
      properties:
        CodeLens: true
'@
dsc config get --document $document
```

## DSC class generator

The module is created with best effort using PowerShell. Visual Studio Code has a ton of settings. One of the best locations to search for all these settings, is the `settings.md` file located at [GitHub](https://raw.githubusercontent.com/microsoft/vscode-docs/df02860db4c0d9043660b07829b442978f2434c8/docs/getstarted/settings.md).

With scripting, it was possible to fetch all default settings including the possible values that can be set. To demonstrate, you need to know that the `Get-VSCodeSettings` function was exported for the `VSCodeSettingDSC` module.

To get all settings, run the following command:

```powershell
$settings = Get-VSCodeSettings
```

You can group all settings together and filter out special cases.

```powershell
$groups = $settings | Sort-Object -Property Setting -Unique | Group-Object -Property Category
$filter = $groups | Where-Object { $_.Name -notin @('_os', '_vscode') -and $_.Name -notlike '`[*' -and $_.Name -notlike '`**' }
```

You now have a filtered object group of all Visual Studio Code Settings. The `New-VSCodeSettingClass` allows you to dynamically generated the DSC class resource.

```powershell
foreach ($group in $filter)
{
    $class = New-VSCodeSettingClass -settings $group.Group
    try {
        $class | Out-File -FilePath "$env:TEMP\$($group.Name)Setting.ps1" -ErrorAction Stop
    } 
        . $filePath

        $content = Get-Content $filePath -Raw
        $content | Add-Content -Path (Join-Path $env:TEMP 'module.psm1')
    catch {
        Write-Host "Error loading $($group.Name)Setting.ps1"
        Write-Host $_.Exception.Message
    }
}
```

## Contributing

Contributions are welcome! Please follow these steps to contribute:

1. Fork the repository
2. Create a new branch (git checkout -b feature-branch)
3. Make your changes
4. Commit your changes (git commit -m 'Add some feature')
5. Push to the branch (git push origin feature-branch)
6. Open a pull request

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Contact

For any questions or suggestions, please open an issue.