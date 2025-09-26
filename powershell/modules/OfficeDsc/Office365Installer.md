---
Module Name: OfficeDsc
date: 09/26/2025
title: Office365Installer
---

# Office365Installer

## SYNOPSIS

The `Office365Installer` DSC Resource allows you to install and uninstall Microsoft Office 365 products using
the Office Deployment Tool (ODT).

## DESCRIPTION

The `Office365Installer` DSC Resource provides a way to manage Microsoft Office 365 installations using
PowerShell Desired State Configuration (DSC) or Microsoft DSC v3. It leverages the Office Deployment Tool (ODT)
to install, configure, and uninstall Office products with support for multiple languages, channels, and application
exclusions.

## PARAMETERS

| **Parameter** | **Attribute** | **DataType** | **Description**                                                                                                                                                             | **Allowed Values**                                                                                                                     |
|---------------|---------------|--------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| `Path`        | Key           | String       | The full path to the Office Deployment Tool setup executable (setup.exe). This parameter is mandatory and serves as the unique identifier for the resource.                 | Valid file path to ODT setup.exe                                                                                                       |
| `ProductId`   | Optional      | ProductId    | The Office product identifier to install or remove. Defaults to `O365ProPlusRetail`.                                                                                        | `O365ProPlusEEANoTeamsRetail`, `O365ProPlusRetail`, `O365BusinessEEANoTeamsRetail`, `O365BusinessRetail`                               |
| `ExcludeApps` | Optional      | PackageId[]  | Array of Office applications to exclude from installation. Defaults to empty array (no exclusions).                                                                         | `Access`, `Excel`, `Groove`, `Lync`, `OneDrive`, `OneNote`, `Outlook`, `OutlookForWindows`, `PowerPoint`, `Publisher`, `Teams`, `Word` |
| `Channel`     | Optional      | Channel      | The Office update channel to use for installation and updates. Defaults to `Current`.                                                                                       | `BetaChannel`, `CurrentPreview`, `Current`, `MonthlyEnterprise`, `SemiAnnualPreview`, `SemiAnnual`                                     |
| `LanguageId`  | Optional      | String[]     | Array of language identifiers to install with the Office product. If not specified, uses current system culture or validates against available languages for the ProductId. | Valid Office language codes (e.g., `en-US`, `fr-FR`, `de-DE`, `es-ES`)                                                                 |
| `Exist`       | Optional      | Boolean      | Indicates whether Office should be installed (`$true`) or uninstalled (`$false`). Defaults to `$true`.                                                                      | `$true`, `$false`                                                                                                                      |

## SUPPORTED OFFICE LANGUAGES

The resource supports the following Office language identifiers:

`af-ZA`, `sq-AL`, `ar-SA`, `hy-AM`, `as-IN`, `az-Latn-AZ`, `bn-BD`, `bn-IN`, `eu-ES`, `bs-latn-BA`, `bg-BG`, `ca-ES`, `ca-ES-valencia`, `zh-CN`, `zh-TW`, `hr-HR`, `cs-CZ`, `da-DK`, `nl-NL`, `en-US`, `en-GB`, `et-EE`, `fi-FI`, `fr-FR`, `fr-CA`, `gl-ES`, `ka-GE`, `de-DE`, `el-GR`, `gu-IN`, `ha-Latn-NG`, `he-IL`, `hi-IN`, `hu-HU`, `is-IS`, `ig-NG`, `id-ID`, `ga-IE`, `xh-ZA`, `zu-ZA`, `it-IT`, `ja-JP`, `kn-IN`, `kk-KZ`, `rw-RW`, `sw-KE`, `kok-IN`, `ko-KR`, `ky-KG`, `lv-LV`, `lt-LT`, `lb-LU`, `mk-MK`, `ms-MY`, `ml-IN`, `mt-MT`, `mi-NZ`, `mr-IN`, `ne-NP`, `nb-NO`, `nn-NO`, `or-IN`, `ps-AF`, `fa-IR`, `pl-PL`, `pt-PT`, `pt-BR`, `pa-IN`, `ro-RO`, `rm-CH`, `ru-RU`, `gd-GB`, `sr-cyrl-RS`, `sr-latn-RS`, `sr-cyrl-BA`, `nso-ZA`, `tn-ZA`, `si-LK`, `sk-SK`, `sl-SI`, `es-ES`, `es-MX`, `sv-SE`, `ta-IN`, `tt-RU`, `te-IN`, `th-TH`, `tr-TR`, `uk-UA`, `ur-PK`, `uz-Latn-UZ`, `vi-VN`, `cy-GB`, `wo-SN`, `yo-NG`

## EXAMPLES

### EXAMPLE 1

```powershell
Invoke-DscResource -ModuleName OfficeDsc -Name Office365Installer -Method Get -Property @{ 
    Path = 'C:\ODT\setup.exe' 
}

# This example gets the current state of Office installation using the default configuration.
# Returns information about installed Office products, languages, channels, and excluded apps.
```

### EXAMPLE 2

```powershell
Invoke-DscResource -ModuleName OfficeDsc -Name Office365Installer -Method Set -Property @{
    Path = 'C:\ODT\setup.exe'
    ProductId = 'O365ProPlusRetail'
    Channel = 'Current'
    LanguageId = @('en-US')
}

# This example installs Office 365 Pro Plus with Current channel and English (US) language.
```

> [!NOTE]
> The `en-US` language should be installed on your system.

### EXAMPLE 3

```powershell
Invoke-DscResource -ModuleName OfficeDsc -Name Office365Installer -Method Set -Property @{
    Path = 'C:\ODT\setup.exe'
    ProductId = 'O365BusinessRetail'
    Channel = 'MonthlyEnterprise'
    LanguageId = @('en-US', 'fr-FR')
    ExcludeApps = @('Teams', 'OneNote')
}

# This example installs Office 365 Business with Monthly Enterprise channel, 
# English and French languages, excluding Teams and OneNote applications.
```

> [!NOTE]
> The `en-US` and `fr-FR` languages should be installed on your system.

### EXAMPLE 4

```powershell
Invoke-DscResource -ModuleName OfficeDsc -Name Office365Installer -Method Set -Property @{
    Path = 'C:\ODT\setup.exe'
    ProductId = 'O365ProPlusEEANoTeamsRetail'
    Channel = 'SemiAnnual'
    ExcludeApps = @('Access', 'Publisher')
}

# This example installs Office 365 Pro Plus (EEA No Teams) with Semi-Annual channel,
# excluding Access and Publisher.
```

### EXAMPLE 5

```powershell
Invoke-DscResource -ModuleName OfficeDsc -Name Office365Installer -Method Test -Property @{
    Path = 'C:\ODT\setup.exe'
    ProductId = 'O365ProPlusRetail'
    Channel = 'Current'
    ExcludeApps = @('Teams')
}

# This example tests whether the current Office installation matches the desired configuration.
# Returns $true if in desired state, $false if changes are needed.
```

### EXAMPLE 6

```powershell
Invoke-DscResource -ModuleName OfficeDsc -Name Office365Installer -Method Set -Property @{
    Path = 'C:\ODT\setup.exe'
    ProductId = 'O365ProPlusRetail'
    Exist = $false
}

# This example uninstalls all Office 365 Pro Plus products and languages.
```

### EXAMPLE 7

```powershell
Invoke-DscResource -ModuleName OfficeDsc -Name Office365Installer -Method Set -Property @{
    Path = 'C:\ODT\setup.exe'
    ProductId = 'O365ProPlusRetail'
    LanguageId = @('fr-FR')
    Exist = $false
}

# This example performs targeted removal of French language pack from Office 365 Pro Plus.
```

### EXAMPLE 8

```powershell
Invoke-DscResource -ModuleName OfficeDsc -Name Office365Installer -Method Set -Property @{
    Path = 'C:\ODT\setup.exe'
    ProductId = 'O365BusinessEEANoTeamsRetail'
    Channel = 'BetaChannel'
    LanguageId = @('en-US', 'es-ES', 'pt-BR')
    ExcludeApps = @('Access', 'Publisher', 'OneNote')
}

# This example installs Office 365 Business (EEA No Teams) with Beta channel,
# multiple languages (English, Spanish, Portuguese), and excludes several applications.
```

## NOTES

- **Administrator privileges:** The resource requires to run elevated for `Set` operations.
- **ODT path validation:** The resource requires a valid Office Click-To-Run `setup.exe` file.
- **Language validation:** The resource validates the specified languages installed on the systems.
- **Channel management:** The resource respects Group Policy channel settings.

## RELATED LINKS

- [Office Deployment Tool Documentation][00]
- [Office 365 Product IDs][01]
- [Office Language Support][02]
- [PowerShell DSC Resources][03]

<!-- Link reference definitions -->
[00]: https://learn.microsoft.com/en-us/microsoft-365-apps/deploy/overview-office-deployment-tool
[01]: https://learn.microsoft.com/en-us/troubleshoot/microsoft-365-apps/office-suite-issues/product-ids-supported-office-deployment-click-to-run
[02]: https://learn.microsoft.com/en-us/microsoft-365-apps/deploy/overview-deploying-languages-microsoft-365-apps
[03]: https://learn.microsoft.com/en-us/powershell/dsc/concepts/resources
