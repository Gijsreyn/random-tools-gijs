# OfficeDsc

This folder contains the `OfficeDsc` PowerShell module for various DSC resources
that configures Microsoft Office. The `OfficeDsc` PowerShell module contains the
following class-based DSC resource(s):

- **Office365Installer:** Allows you to configure Office 365 Click-To-Run
  installations.

## Getting started

Before you're getting started, there are multiple ways of invoking DSC resources:

1. Install the latest [PSDesiredStateConfiguration][00] module:

    ```powershell
    Install-PSResource -Name PSDesiredStateConfiguration
    ```

2. Install [Microsoft DSC v3][01] executable:

    ```powershell
    # Install PSDSC module
    Install-PSResource -Name PSDSC

    # Install executable
    Install-DscExe
    ```

You can now install the module running: `Install-PSResource -Name OfficeDsc`.
When the module is installed, you can use a sanitized URL to download the
latest version of the Office Deployment Tool (ODT):

```powershell
$outFile = Join-Path $env:TEMP 'setup.exe'
Invoke-RestMethod -Uri 'https://officecdn.microsoft.com/pr/wsus/setup.exe' -OutFile $outFile -ErrorAction Stop
```

## Examples

Each DSC resource exposed in the module contains it's own help Markdown file:

- [Office365Installer][02]

## Running WinGet configurations

You can also use the `OfficeDsc` module with [WinGet Configuration][03] to
declaratively manage Office installations. WinGet Configuration uses DSC
resources to define and apply system configurations.

Here's an example configuration file that installs Office 365 Pro Plus:

```yaml
# yaml-language-server: $schema=https://aka.ms/configuration-dsc-schema/0.2

###########################################################################################################################################
# This configuration will install Microsoft Office 365 Pro Plus using the Office Deployment Tool                                          #
# Reference: https://learn.microsoft.com/en-us/microsoft-365-apps/deploy/overview-office-deployment-tool                                  #
#                                                                                                                                         #
# This will:                                                                                                                              #
#     * Download the Office Deployment Tool                                                                                               #
#     * Install Office 365 Pro Plus with Current channel                                                                                  #
#     * Configure English (US) language                                                                                                   #
#     * Exclude Teams from installation                                                                                                   #
#                                                                                                                                         #
###########################################################################################################################################

properties:
  resources:
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      directives:
        description: Download Office Deployment Tool
      settings:
        id: Microsoft.OfficeDeploymentTool
        source: winget
        ensure: Present
    
    - resource: OfficeDsc/Office365Installer
      directives:
        description: Install Office 365 Pro Plus
        dependsOn:
          - Microsoft.WinGet.DSC/WinGetPackage
      settings:
        Path: 'C:\Program Files\OfficeDeploymentTool\setup.exe'
        ProductId: O365ProPlusRetail
        Channel: Current
        LanguageId: 
          - en-US
        ExcludeApps:
          - Teams
        Exist: true
```

To run this configuration:

1. Save the configuration to a file (e.g., `office-config.dsc.yaml`)
2. Run the configuration using WinGet:

    ```cmd
    winget configure --file office-config.dsc.yaml
    ```

For more information about WinGet Configuration, see the [official documentation][03].

## Running with Microsoft DSC v3

You can also use the `OfficeDsc` module with [Microsoft DSC v3][01] for
cross-platform configuration management. DSC v3 provides a modern,
schema-driven approach to system configuration.

Here's an example DSC v3 configuration that manages Office 365 installation:

```yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
parameters:
  officeChannel:
    type: string
    defaultValue: Current
    allowedValues:
      - Current
      - MonthlyEnterprise
      - SemiAnnual
      - SemiAnnualPreview
      - CurrentPreview
      - BetaChannel
  excludeTeams:
    type: boolean
    defaultValue: true
resources:
- name: Office 365 Management
  type: Microsoft.DSC/PowerShell
  properties:
    resources:
    - name: Download Office Deployment Tool
      type: Microsoft.WinGet.DSC/WinGetPackage
      properties:
        Id: Microsoft.OfficeDeploymentTool
        Ensure: Present
    - name: Install Office 365 Pro Plus
      type: OfficeDsc/Office365Installer
      properties:
        Path: 'C:\Program Files\OfficeDeploymentTool\setup.exe'
        ProductId: O365ProPlusRetail
        Channel: "[parameters('officeChannel')]"
        LanguageId: 
          - en-US
          - fr-FR
        ExcludeApps: "[if(parameters('excludeTeams'), createArray('Teams'), createArray())]"
        Exist: true
```

To run this configuration with DSC v3:

1. Save the configuration to a file (e.g., `office-config.dsc.yaml`)
2. Apply the configuration using DSC v3:

    ```powershell
    # Get current configuration state
    dsc config get --path office-config.dsc.yaml

    # Test if configuration is in desired state
    dsc config test --path office-config.dsc.yaml

    # Apply the configuration
    dsc config set --path office-config.dsc.yaml
    ```

For more information about Microsoft DSC v3, see the [official repository][01].

<!-- Link reference definitions -->
[00]: https://www.powershellgallery.com/packages/PSDesiredStateConfiguration/2.0.7
[01]: https://github.com/PowerShell/DSC/
[02]: ./Office365Installer.md
[03]: https://learn.microsoft.com/en-us/windows/package-manager/configuration/
