# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrEmpty($env:TestRegistryPath))
{
    $global:OfficeRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
    $global:OfficeGroupPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common\OfficeUpdate'
    $global:OfficeProductReleaseIdsPath = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\ProductReleaseIds'
    
}
else
{
    $global:OfficeRegistryPath = $global:OfficeRegistryPath = $global:OfficeProductReleaseIdsPath = $env:TestRegistryPath
}

# Supported Office language IDs: https://learn.microsoft.com/en-us/microsoft-365-apps/deploy/overview-deploying-languages-microsoft-365-apps#languages-culture-codes-and-companion-proofing-languages
$global:supportedLanguages = @(
    'af-ZA', 'sq-AL', 'ar-SA', 'hy-AM', 'as-IN', 'az-Latn-AZ', 'bn-BD', 'bn-IN', 'eu-ES',
    'bs-latn-BA', 'bg-BG', 'ca-ES', 'ca-ES-valencia', 'zh-CN', 'zh-TW', 'hr-HR', 'cs-CZ',
    'da-DK', 'nl-NL', 'en-US', 'en-GB', 'et-EE', 'fi-FI', 'fr-FR', 'fr-CA', 'gl-ES', 'ka-GE',
    'de-DE', 'el-GR', 'gu-IN', 'ha-Latn-NG', 'he-IL', 'hi-IN', 'hu-HU', 'is-IS', 'ig-NG',
    'id-ID', 'ga-IE', 'xh-ZA', 'zu-ZA', 'it-IT', 'ja-JP', 'kn-IN', 'kk-KZ', 'rw-RW', 'sw-KE',
    'kok-IN', 'ko-KR', 'ky-KG', 'lv-LV', 'lt-LT', 'lb-LU', 'mk-MK', 'ms-MY', 'ml-IN', 'mt-MT',
    'mi-NZ', 'mr-IN', 'ne-NP', 'nb-NO', 'nn-NO', 'or-IN', 'ps-AF', 'fa-IR', 'pl-PL', 'pt-PT',
    'pt-BR', 'pa-IN', 'ro-RO', 'rm-CH', 'ru-RU', 'gd-GB', 'sr-cyrl-RS', 'sr-latn-RS',
    'sr-cyrl-BA', 'nso-ZA', 'tn-ZA', 'si-LK', 'sk-SK', 'sl-SI', 'es-ES', 'es-MX', 'sv-SE',
    'ta-IN', 'tt-RU', 'te-IN', 'th-TH', 'tr-TR', 'uk-UA', 'ur-PK', 'uz-Latn-UZ', 'vi-VN',
    'cy-GB', 'wo-SN', 'yo-NG'
)

#region Enums

# ProductId enumeration: https://learn.microsoft.com/en-us/troubleshoot/microsoft-365-apps/office-suite-issues/product-ids-supported-office-deployment-click-to-run
enum ProductId
{
    O365ProPlusEEANoTeamsRetail      # Microsoft 365 Apps for enterprise
    O365ProPlusRetail                # Office 365 Enterprise E3, E5, Microsoft 365 E3, E5, Office 365 E3, E5
    O365BusinessEEANoTeamsRetail     # Microsoft 365 Apps for business
    O365BusinessRetail               # Microsoft 365 Business Standard, Business Premium
}

enum PackageId
{
    Access 
    Excel
    Groove
    Lync
    OneDrive
    OneNote
    Outlook
    OutlookForWindows
    PowerPoint
    Publisher
    Teams
    Word
}

# Channel enumeration: https://learn.microsoft.com/en-us/microsoft-365-apps/deploy/office-deployment-tool-configuration-options#channel-attribute-part-of-add-element
enum Channel
{
    BetaChannel 
    CurrentPreview
    Current
    MonthlyEnterprise
    SemiAnnualPreview
    SemiAnnual
}
#endregion Enums

#region Functions
function Get-OfficeGroupPolicyChannelSetting
{
    [OutputType([Channel])]
    [CmdletBinding()]
    param 
    (
    )

    # Registry key found: https://learn.microsoft.com/en-us/troubleshoot/microsoft-365-apps/installation/automatic-updates#resolution
    $channelUri = TryGetRegistryValue -Key $global:OfficeGroupPolicyPath -Property 'updatebranch'
    if ([string]::IsNullOrEmpty($channelUri))
    {
        Write-Verbose -Message 'Group policy is not set, using local channel setting.'
        return Get-OfficeChannel
    }

    # Extra check if Group Policy is setting a different channel
    switch ($channelUri)
    {
        'InsiderFast' { return [Channel]::BetaChannel }
        'FirstReleaseCurrent' { return [Channel]::CurrentPreview }
        'Current' { return [Channel]::Current }
        'MonthlyEnterprise' { return [Channel]::MonthlyEnterprise }
        'FirstReleaseDeferred' { return [Channel]::SemiAnnualPreview }
        'Deferred' { return [Channel]::SemiAnnual }
        default { throw "Unknown channel value found in Group Policy: '$channelUri'" }
    }
}
function Get-OfficeChannel
{
    [OutputType([Channel])]
    [CmdletBinding()]
    param 
    (
    )

    $Uri = TryGetRegistryValue -Key $global:OfficeRegistryPath -Property 'UpdateChannel'

    # Channel URIs: https://learn.microsoft.com/en-us/intune/intune-service/configuration/settings-catalog-update-office#check-the-intune-registry-keys
    $Channel = switch ($Uri)
    {
        'http://officecdn.microsoft.com/pr/5440fd1f-7ecb-4221-8110-145efaa6372f' { [Channel]::BetaChannel }
        'http://officecdn.microsoft.com/pr/64256afe-f5d9-4f86-8936-8840a6a4f5be' { [Channel]::CurrentPreview }
        'http://officecdn.microsoft.com/pr/492350f6-3a01-4f97-b9c0-c7c6ddf67d60' { [Channel]::Current }
        'http://officecdn.microsoft.com/pr/55336b82-a18d-4dd6-b5f6-9e5095c314a6' { [Channel]::MonthlyEnterprise }
        'http://officecdn.microsoft.com/pr/b8f9b850-328d-4355-9145-c59439a0c4cf' { [Channel]::SemiAnnualPreview }
        'http://officecdn.microsoft.com/pr/7ffbc6bf-bc32-4f92-8982-f9dd17fd3114' { [Channel]::SemiAnnual }
        default { [Channel]::Current }
    }

    return $Channel
}
function Get-OfficeInstallation
{
    [OutputType([System.Collections.Hashtable])]
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory = $true)]
        [ProductId]$ProductId
    )
    
    # Find the known key
    $keyPresent = TryGetRegistryValue -Key $global:OfficeRegistryPath -Property 'InstallationPath'

    # Extra check if the product is installed via Click-to-Run
    $installed = $false
    if ($null -ne $keyPresent)
    {
        $installed = Test-Path -Path $keyPresent -ErrorAction Ignore
    }

    $searchProperty = [System.String]::Concat($ProductId, '.ExcludedApps')

    # Go through the excluded apps and filter out the installed apps
    Write-Verbose -Message "Searching for excluded apps with property name: '$searchProperty'."
    $excludedApps = TryGetRegistryValue -Key $global:OfficeRegistryPath -Property $searchProperty
    $appsInstalled = [PackageId]::GetNames([PackageId])
    $excludedAppsArray = @()
    if ($null -ne $excludedApps)
    {
        $textInfo = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo
        $excludedAppsArray = ($excludedApps.Split(',') | ForEach-Object { $textInfo.ToTitleCase($_.Trim()) })
        $appsInstalled = $appsInstalled | Where-Object { $_ -notin $excludedAppsArray }
    }

    return @{
        Installed    = $installed
        Apps         = $appsInstalled
        ExcludedApps = ($null -ne $excludedAppsArray) ? $excludedAppsArray : @() # Nothing was excluded
        ProductId    = $ProductId
    }
}

function Assert-OfficeDeploymentToolSetup
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Path
    )

    try
    {
        if (-not (Test-Path -Path $Path -PathType Leaf))
        {
            throw "The specified path '$Path' does not exist."
        }

        if ([System.IO.Path]::GetExtension($Path) -ne '.exe')
        {
            throw "The specified path '$Path' is not an executable file."
        }

        # Run setup.exe with '/?' to verify it is the Office Deployment Tool
        $output = & $Path '/?' 2>&1

        if ($LASTEXITCODE -ne 0)
        {
            throw "The executable at '$Path' did not exit successfully. ExitCode: $LASTEXITCODE"
        }

        if ($output -notmatch 'Office Deployment Tool')
        {
            throw "The executable at '$Path' does not appear to be the Office Deployment Tool."
        }
    }
    catch
    {
        throw "Failed to validate Office Deployment Tool setup: $($_.Exception.Message)"
    }
}

function New-OfficeConfigurationXml
{
    [OutputType([System.String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [System.String]
        $ProductId,

        [Parameter()]
        [System.String[]]
        $ExcludeApps = @(),

        [Parameter()]
        [Channel]
        $Channel = [Channel]::Current, # Default is current

        [Parameter()]
        [System.String[]]
        $LanguageId = (@([System.Globalization.CultureInfo]::CurrentCulture.Name)), # Default to current system culture

        [System.Management.Automation.SwitchParameter]
        $Remove
    )

    if ($null -eq $LanguageId -or $LanguageId -eq '')
    {
        # Default to current
        $LanguageId = [System.Globalization.CultureInfo]::GetCultureInfo.Name
        Write-Verbose -Message "Using current system culture as language ID: '$LanguageId'."
    }

    # Get the bitness
    $bitness = [Environment]::Is64BitOperatingSystem ? '64' : '32'

    # Build the document
    $xml = New-Object System.Xml.XmlDocument

    $config = $xml.CreateElement('Configuration')
    $xml.AppendChild($config) | Out-Null

    $parentNodeName = $Remove ? 'Remove' : 'Add'
    $parentNode = $xml.CreateElement($parentNodeName)
    $parentNode.SetAttribute('OfficeClientEdition', $bitness)
    $parentNode.SetAttribute('Channel', $Channel)
    $config.AppendChild($parentNode) | Out-Null

    $product = $xml.CreateElement('Product')
    $product.SetAttribute('ID', $ProductId)
    $parentNode.AppendChild($product) | Out-Null

    foreach ($lang in $LanguageId)
    {
        $language = $xml.CreateElement('Language')
        $language.SetAttribute('ID', $lang)
        $product.AppendChild($language) | Out-Null
    }

    foreach ($app in $ExcludeApps)
    {
        $exclude = $xml.CreateElement('ExcludeApp')
        $exclude.SetAttribute('ID', $app)
        $product.AppendChild($exclude) | Out-Null
    }

    $display = $xml.CreateElement('Display')
    $display.SetAttribute('Level', 'None')
    if (-not $Remove.IsPresent) 
    {
        $display.SetAttribute('AcceptEULA', 'TRUE')
    }
    $config.AppendChild($display) | Out-Null

    $stringWriter = New-Object System.IO.StringWriter
    $xmlWriter = New-Object System.Xml.XmlTextWriter($stringWriter)
    $xmlWriter.Formatting = 'Indented'
    $xml.WriteTo($xmlWriter)
    $xmlWriter.Flush()
    $configXml = $stringWriter.ToString()
    $xmlWriter.Close()

    Write-Verbose -Message "Generated Office configuration XML:`n$configXml"
    # write the config file to a temp location
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "ODT_Install_$(Get-Random).xml"
    try
    {
        Set-Content -Path $tempDir -Value $configXml -Encoding UTF8 -Force
    }
    catch
    {
        throw "Failed to create temporary configuration file: '$tempDir'"
    }

    Write-Verbose -Message "Temporary configuration file created at: '$tempDir'."
    return $tempDir
}

function Assert-LanguageInstalled
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]] $LanguageId
    )

    $installedLanguages = (Get-CimInstance Win32_OperatingSystem).MUILanguages
    $missing = $LanguageId | Where-Object { $_ -notin $installedLanguages }

    if ($missing)
    {
        throw "The following languages are not installed on the system: $($missing -join ', ')"
    }
}

function Assert-OfficeLanguageSupported
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]] $LanguageId
    )

    $unsupported = $LanguageId | Where-Object { $_ -notin $global:supportedLanguages }

    if ($unsupported)
    {
        throw "The following languages are not supported by Office: $($unsupported -join ', ')"
    }
}

function Test-SupportedLanguageId
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$LanguageId
    )

    return ($LanguageId | ForEach-Object { $global:supportedLanguages -contains $_ }) -notcontains $false
}

function Install-OfficeProduct
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [ProductId] $ProductId,

        [Parameter()]
        [Channel] $Channel = [Channel]::Current,

        [Parameter()]
        [string[]] $LanguageId,

        [Parameter()]
        [PackageId[]] $ExcludeApps = @()
    )

    $configFilePath = New-OfficeConfigurationXml -ProductId $ProductId -Channel $Channel -ExcludeApps $ExcludeApps -LanguageId $LanguageId

    if ($null -ne $LanguageId -or $LanguageId -ne '')
    {
        Assert-LanguageInstalled -LanguageId $LanguageId
        Assert-OfficeLanguageSupported -LanguageId $LanguageId
    }

    $arguments = "/configure `"$configFilePath`""
    Write-Verbose "Launching Office setup: $Path $arguments"
    Start-Process -FilePath $Path -ArgumentList $arguments -Wait -NoNewWindow
}

function Uninstall-Office
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [ProductId]
        $ProductId,

        [Parameter()]
        [PackageId[]]
        $ExcludeApps = @()
    )

    $configFilePath = New-OfficeConfigurationXml -ProductId $ProductId -ExcludeApps $ExcludeApps -Remove

    $arguments = "/configure $configFilePath"
    Write-Verbose -Message "Starting Office uninstallation at path '$Path' with arguments: '$arguments'"
    Start-Process -FilePath $Path -ArgumentList $arguments -Wait -NoNewWindow
}

function TryGetRegistryValue
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Property
    )

    if (Test-Path -Path $Key)
    {
        try
        {
            return (Get-ItemProperty -Path $Key | Select-Object -ExpandProperty $Property)
        }
        catch
        {
            Write-Verbose "Property `"$($Property)`" could not be found."
        }
    }
    else
    {
        Write-Verbose 'Registry key does not exist.'
    }
}


function Assert-Administrator
{
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $user

    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator))
    {
        throw "The current user is not running with administrative privileges. Please re-run PowerShell as Administrator."
    }
}

function Get-LanguageId
{
    [OutputType([System.String[]])]
    [CmdletBinding()]
    param 
    (
        [Parameter()]
        [System.String[]]
        $LanguageId,

        [Parameter(Mandatory = $true)]
        [ProductId]
        $ProductId
    )

    $validLanguages = @()
    
    try
    {
        $languagePaths = Get-ChildItem -Path $global:OfficeProductReleaseIdsPath -Recurse -ErrorAction Stop
    }
    catch
    {
        Write-Error -Message "Failed to access Office ProductReleaseIds registry path: '$global:OfficeProductReleaseIdsPath'" -Category ObjectNotFound -ErrorId 'RegistryPathNotFound' -TargetObject $global:OfficeProductReleaseIdsPath -Exception $_.Exception
        return @()
    }

    $productFilter = { $_.Name -like "*$ProductId*" }
    $productLanguagePaths = $languagePaths | Where-Object $productFilter

    if (-not $productLanguagePaths)
    {
        Write-Warning -Message "No language paths found for ProductId: '$ProductId'"
        return @()
    }

    if ($null -eq $LanguageId -or $LanguageId.Count -eq 0)
    {
        Write-Verbose -Message 'No LanguageId specified, returning all valid languages for the ProductId.'
        
        foreach ($languagePath in $productLanguagePaths)
        {
            $languageCode = $languagePath.PSChildName
            if (Test-SupportedLanguageId -LanguageId $languageCode)
            {
                $validLanguages += $languageCode
            }
        }
    }
    else
    {
        foreach ($requestedLanguage in $LanguageId)
        {
            $matchingLanguagePath = $productLanguagePaths | Where-Object { $_.Name -like "*$requestedLanguage*" }
            
            if ($matchingLanguagePath)
            {
                Write-Verbose -Message "Valid language found: '$requestedLanguage' for ProductId: '$ProductId' at: '$matchingLanguagePath'"
                $validLanguages += $requestedLanguage
            }
            else
            {
                Write-Warning -Message "Language '$requestedLanguage' is not valid for ProductId: '$ProductId'"
            }
        }
    }

    return $validLanguages
}

#endregion Functions

#region Classes
[DSCResource()]
class Office365Installer
{
    [DscProperty(Key, Mandatory = $true)]
    [System.String] 
    $Path

    [DscProperty()]
    [ProductId] 
    $ProductId = 'O365ProPlusRetail'

    [DscProperty()]
    [PackageId[]]
    $ExcludeApps = @()

    [DscProperty()]
    [Channel]
    $Channel = [Channel]::Current

    [DscProperty()]
    [System.String[]]
    $LanguageId

    [DscProperty()]
    [System.Boolean]
    $Exist = $true


    Office365Installer()
    {
    }

    [Office365Installer] Get()
    {
        $currentState = [Office365Installer]::new()
        # TODO: Have to validate if it can contain multiple ProductIds
        $currentState.ProductId = TryGetRegistryValue -Key $global:OfficeRegistryPath -Property 'ProductReleaseIds'

        $officeInstalled = Get-OfficeInstallation -ProductId $this.ProductId
        $currentState.ExcludeApps = $officeInstalled.ExcludedApps
        $currentState.Exist = $officeInstalled.Installed
        $currentState.Path = $this.Path
        $currentState.Channel = Get-OfficeGroupPolicyChannelSetting
        $currentState.LanguageId = Get-LanguageId -LanguageId $this.LanguageId -ProductId $this.ProductId
        return $currentState
    }

    [bool] Test()
    {
        $currentState = $this.Get()

        if ($currentState.Exist -ne $this.Exist)
        {
            return $false
        }

        if ($currentState.ExcludeApps -ne $this.ExcludeApps)
        {
            return $false
        }

        if ($currentState.Channel -ne $this.Channel)
        {
            return $false
        }

        if ($currentState.ProductId -ne $this.ProductId)
        {
            return $false
        }

        if ($currentState.LanguageId -ne $this.LanguageId)
        {
            return $false
        }
        
        return $true
    }

    [void] Set()
    {
        if ($this.Test())
        {
            return
        }

        # before installing, ensure we have admin rights (known issue with ODT)
        Assert-Administrator

        # check if the path is actually the ODT setup.exe
        Assert-OfficeDeploymentToolSetup -Path $this.Path

        if ($this.Exist)
        {
            $this.Install($false)
        }
        else
        {
            $this.Uninstall($false)
        }
    }

    [void] Install([bool] $preTest)
    {
        if ($preTest -and $this.Test())
        {
            return
        }

        $installParams = @{
            Path        = $this.Path
            ProductId   = $this.ProductId
            Channel     = $this.Channel
            LanguageId  = $this.LanguageId
            ExcludeApps = $this.ExcludeApps
        }

        Install-Office @installParams
    }

    [void] Install()
    {
        $this.Install($true)
    }

    [void] Uninstall([bool] $preTest)
    {
        Uninstall-Office -Path $this.Path -ProductId $this.ProductId -ExcludeApps $this.ExcludeApps
    }

    [void] Uninstall()
    {
        $this.Uninstall($true)
    }
    #endregion Classes
}