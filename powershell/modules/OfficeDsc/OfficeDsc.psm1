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

    if ([string]::IsNullOrEmpty($Uri))
    {
        Write-Verbose -Message 'No channel URI found in registry, defaulting to Current channel.'
        return [Channel]::Current
    }

    # Channel URIs: https://learn.microsoft.com/en-us/intune/intune-service/configuration/settings-catalog-update-office#check-the-intune-registry-keys
    $Channel = switch ($Uri)
    {
        'http://officecdn.microsoft.com/pr/5440fd1f-7ecb-4221-8110-145efaa6372f' { [Channel]::BetaChannel }
        'http://officecdn.microsoft.com/pr/64256afe-f5d9-4f86-8936-8840a6a4f5be' { [Channel]::CurrentPreview }
        'http://officecdn.microsoft.com/pr/492350f6-3a01-4f97-b9c0-c7c6ddf67d60' { [Channel]::Current }
        'http://officecdn.microsoft.com/pr/55336b82-a18d-4dd6-b5f6-9e5095c314a6' { [Channel]::MonthlyEnterprise }
        'http://officecdn.microsoft.com/pr/b8f9b850-328d-4355-9145-c59439a0c4cf' { [Channel]::SemiAnnualPreview }
        'http://officecdn.microsoft.com/pr/7ffbc6bf-bc32-4f92-8982-f9dd17fd3114' { [Channel]::SemiAnnual }
        default { throw "Unknown channel URI found in registry: '$Uri'" }
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
    
    # find the known key
    $keyPresent = TryGetRegistryValue -Key $global:OfficeRegistryPath -Property 'InstallationPath'

    # extra check if the product is installed via Click-to-Run
    $installed = $false
    if ($null -ne $keyPresent)
    {
        $installed = Test-Path -Path $keyPresent -ErrorAction Ignore
    }

    $searchProperty = [System.String]::Concat($ProductId, '.ExcludedApps')

    # go through the excluded apps and filter out the installed apps
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

        # TODO: Can be improved by checking for specific output lines
        if ($output[1] -ne 'Office Deployment Tool')
        {
            throw "The executable at '$Path' does not appear to be the Office Deployment Tool."
        }
    }
    catch
    {
        throw "Failed to validate Office Deployment Tool setup: $($_.Exception.Message)"
    }
}

<#
    .SYNOPSIS
        Creates an Office Deployment Tool configuration XML file for installation.

    .DESCRIPTION
        Generates a configuration XML file for the Office Deployment Tool (ODT) to install 
        Microsoft Office products. The XML includes product specifications, languages, 
        excluded applications, and display settings.

    .PARAMETER ProductId
        The Office product identifier to install.

    .PARAMETER ExcludeApps
        Array of Office applications to exclude from installation.

    .PARAMETER Channel
        The Office update channel to use. Default is Current channel.

    .PARAMETER LanguageId
        Array of language identifiers to install. Default is the current system culture.

    .INPUTS
        None

        This function does not accept pipeline input.

    .OUTPUTS
        System.String

        Path to the temporary configuration XML file.

    .EXAMPLE
        New-OfficeInstallationConfigurationFile -ProductId O365ProPlusRetail
        Creates installation configuration for Office 365 Pro Plus with current system language.

    .EXAMPLE
        New-OfficeInstallationConfigurationFile -ProductId O365ProPlusRetail -ExcludeApps @('Teams', 'OneNote') -LanguageId @('en-US', 'fr-FR')
        Creates installation configuration excluding Teams and OneNote with English and French languages.
#>
function New-OfficeInstallationConfigurationFile
{
    [OutputType([System.String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ProductId]
        $ProductId,

        [Parameter()]
        [System.String[]]
        $ExcludeApps = @(),

        [Parameter()]
        [Channel]
        $Channel = [Channel]::Current,

        [Parameter()]
        [System.String[]]
        $LanguageId
    )

    if ([string]::IsNullOrEmpty($LanguageId))
    {
        $currentCulture = [System.Globalization.CultureInfo]::CurrentCulture.Name
        Write-Verbose -Message "No LanguageId specified, defaulting to current system culture: '$currentCulture'."
        $LanguageId = @($currentCulture)
    }

    $bitness = [Environment]::Is64BitOperatingSystem ? '64' : '32'
    $xml = [System.Xml.XmlDocument]::new()

    $configuration = $xml.CreateElement('Configuration')
    $xml.AppendChild($configuration) | Out-Null

    $addNode = $xml.CreateElement('Add')
    $addNode.SetAttribute('OfficeClientEdition', $bitness)
    $addNode.SetAttribute('Channel', $Channel)
    $configuration.AppendChild($addNode) | Out-Null

    $product = $xml.CreateElement('Product')
    $product.SetAttribute('ID', $ProductId)
    $addNode.AppendChild($product) | Out-Null

    foreach ($languageCode in $LanguageId)
    {
        $language = $xml.CreateElement('Language')
        $language.SetAttribute('ID', $languageCode)
        $product.AppendChild($language) | Out-Null
    }

    foreach ($applicationId in $ExcludeApps)
    {
        $excludeApplication = $xml.CreateElement('ExcludeApp')
        $excludeApplication.SetAttribute('ID', $applicationId)
        $product.AppendChild($excludeApplication) | Out-Null
    }

    $display = $xml.CreateElement('Display')
    $display.SetAttribute('Level', 'None')
    $display.SetAttribute('AcceptEULA', 'TRUE')
    $configuration.AppendChild($display) | Out-Null

    $stringWriter = [System.IO.StringWriter]::new()
    $xmlWriter = [System.Xml.XmlTextWriter]::new($stringWriter)
    $xmlWriter.Formatting = 'Indented'
    $xml.WriteTo($xmlWriter)
    $xmlWriter.Flush()
    $configurationXml = $stringWriter.ToString()
    $xmlWriter.Close()

    Write-Verbose -Message "Generated Office installation configuration XML:`n$configurationXml"
    
    $tempFilePath = Join-Path ([System.IO.Path]::GetTempPath()) "ODT_Install_$(Get-Random).xml"
    try
    {
        Set-Content -Path $tempFilePath -Value $configurationXml -Encoding UTF8 -Force -ErrorAction Stop
        Write-Verbose -Message "Temporary configuration file created at: '$tempFilePath'."
        return $tempFilePath
    }
    catch
    {
        Write-Error -Message "Failed to create temporary configuration file: '$tempFilePath'" -Category WriteError -ErrorId 'TempFileCreationFailed' -TargetObject $tempFilePath -Exception $_.Exception
        return $null
    }
}

<#
    .SYNOPSIS
        Creates an Office Deployment Tool configuration XML file for removal.

    .DESCRIPTION
        Generates a configuration XML file for the Office Deployment Tool (ODT) to remove 
        Microsoft Office products. If no LanguageId is specified, sets All="TRUE" to remove 
        all Office products and languages. If LanguageId is specified, sets All="FALSE" 
        for targeted removal of specific languages.

    .PARAMETER ProductId
        The Office product identifier to remove.

    .PARAMETER LanguageId
        Array of language identifiers to remove. If not specified, removes all Office 
        products and languages (All="TRUE"). If specified, performs targeted removal (All="FALSE").

    .INPUTS
        None

        This function does not accept pipeline input.

    .OUTPUTS
        System.String

        Path to the temporary configuration XML file.

    .EXAMPLE
        New-OfficeRemovalConfigurationFile -ProductId O365ProPlusRetail
        Creates removal configuration that removes all Office products and languages (All="TRUE").

    .EXAMPLE
        New-OfficeRemovalConfigurationFile -ProductId O365ProPlusRetail -LanguageId @('en-US', 'fr-FR')
        Creates removal configuration for specific languages with targeted removal (All="FALSE").
#>
function New-OfficeRemovalConfigurationFile
{
    [OutputType([System.String])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ProductId]
        $ProductId,

        [Parameter()]
        [System.String[]]
        $LanguageId
    )

    $bitness = [Environment]::Is64BitOperatingSystem ? '64' : '32'
    $xml = [System.Xml.XmlDocument]::new()

    $configuration = $xml.CreateElement('Configuration')
    $xml.AppendChild($configuration) | Out-Null

    $removeNode = $xml.CreateElement('Remove')
    $removeNode.SetAttribute('OfficeClientEdition', $bitness)
    
    if ($null -eq $LanguageId -or $LanguageId.Count -eq 0)
    {
        $removeNode.SetAttribute('All', 'TRUE')
        Write-Verbose -Message 'No LanguageId specified for removal. Setting All="TRUE" to remove all Office products and languages.'
    }
    else
    {
        $removeNode.SetAttribute('All', 'FALSE')
        Write-Verbose -Message 'LanguageId specified for removal. Setting All="FALSE" for targeted removal.'
        
        $product = $xml.CreateElement('Product')
        $product.SetAttribute('ID', $ProductId)
        $removeNode.AppendChild($product) | Out-Null

        foreach ($languageCode in $LanguageId)
        {
            $language = $xml.CreateElement('Language')
            $language.SetAttribute('ID', $languageCode)
            $product.AppendChild($language) | Out-Null
        }
    }
    
    $configuration.AppendChild($removeNode) | Out-Null

    $display = $xml.CreateElement('Display')
    $display.SetAttribute('Level', 'None')
    $configuration.AppendChild($display) | Out-Null

    $stringWriter = [System.IO.StringWriter]::new()
    $xmlWriter = [System.Xml.XmlTextWriter]::new($stringWriter)
    $xmlWriter.Formatting = 'Indented'
    $xml.WriteTo($xmlWriter)
    $xmlWriter.Flush()
    $configurationXml = $stringWriter.ToString()
    $xmlWriter.Close()

    Write-Verbose -Message "Generated Office removal configuration XML:`n$configurationXml"
    
    $tempFilePath = Join-Path ([System.IO.Path]::GetTempPath()) "ODT_Remove_$(Get-Random).xml"
    try
    {
        Set-Content -Path $tempFilePath -Value $configurationXml -Encoding UTF8 -Force -ErrorAction Stop
        Write-Verbose -Message "Temporary configuration file created at: '$tempFilePath'."
        return $tempFilePath
    }
    catch
    {
        Write-Error -Message "Failed to create temporary configuration file: '$tempFilePath'" -Category WriteError -ErrorId 'TempFileCreationFailed' -TargetObject $tempFilePath -Exception $_.Exception
        return $null
    }
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
        [string] 
        $Path,

        [Parameter(Mandatory)]
        [ProductId] 
        $ProductId,

        [Parameter()]
        [Channel] 
        $Channel = [Channel]::Current,

        [Parameter()]
        [AllowNull()]
        [string[]] 
        $LanguageId,

        [Parameter()]
        [PackageId[]] 
        $ExcludeApps = @()
    )

    $configurationFileParameters = @{
        ProductId   = $ProductId
        Channel     = $Channel
        LanguageId  = $LanguageId
        ExcludeApps = $ExcludeApps
    }
    $configurationFilePath = New-OfficeInstallationConfigurationFile @configurationFileParameters

    if (-not ([string]::IsNullOrEmpty($LanguageId)))
    {
        Write-Verbose -Message "Validating specified LanguageId(s): $($LanguageId -join ', ')"
        Assert-LanguageInstalled -LanguageId $LanguageId
        Assert-OfficeLanguageSupported -LanguageId $LanguageId
    }

    $arguments = "/configure `"$configurationFilePath`""
    Invoke-OfficeDeploymentTool -Path $Path -Arguments $arguments -Operation 'Installation'
}

function Uninstall-OfficeProduct
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
        [string[]] 
        $LanguageId,

        [Parameter()]
        [Channel] 
        $Channel = [Channel]::Current
    )

    $configurationFileParameters = @{
        ProductId  = $ProductId
        LanguageId = $LanguageId
    }
    $configurationFilePath = New-OfficeRemovalConfigurationFile @configurationFileParameters

    if (-not ([string]::IsNullOrEmpty($LanguageId)))
    {
        Write-Verbose -Message "Validating specified LanguageId(s): $($LanguageId -join ', ')"
        Assert-LanguageInstalled -LanguageId $LanguageId
        Assert-OfficeLanguageSupported -LanguageId $LanguageId
    }

    $arguments = "/configure `"$configurationFilePath`""
    Invoke-OfficeDeploymentTool -Path $Path -Arguments $arguments -Operation 'Uninstallation'
}

<#
    .SYNOPSIS
        Executes the Office Deployment Tool with error handling and logging.

    .DESCRIPTION
        A wrapper function that executes the Office Deployment Tool setup.exe with the 
        specified arguments. Provides logging of the operation and validates
        the exit code. Throws a terminating error if the ODT process fails or returns
        a non-zero exit code.

    .PARAMETER Path
        The full path to the Office Deployment Tool setup executable (setup.exe).

    .PARAMETER Arguments
        The command-line arguments to pass to the ODT setup executable.

    .PARAMETER Operation
        A descriptive name for the operation being performed (e.g., 'Installation', 'Uninstallation').

    .INPUTS
        None

        This function does not accept pipeline input.

    .OUTPUTS
        None

        This function does not return output.

    .EXAMPLE
        Invoke-OfficeDeploymentTool -Path 'C:\ODT\setup.exe' -Arguments '/configure "config.xml"' -Operation 'Installation'
        Executes the ODT with the specified configuration file for installation.
#>
function Invoke-OfficeDeploymentTool
{
    [CmdletBinding()]
    [OutputType()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Arguments,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Operation
    )

    Write-Verbose -Message "Starting Office $Operation using ODT at: '$Path'"
    Write-Verbose -Message "ODT Arguments: $Arguments"

    try
    {
        $processInfo = Start-Process -FilePath $Path -ArgumentList $Arguments -Wait -NoNewWindow -PassThru -ErrorAction Stop
        
        Write-Verbose -Message "Office $Operation process completed with exit code: $($processInfo.ExitCode)"

        if ($processInfo.ExitCode -ne 0)
        {
            $errorMessage = "Office $Operation failed. ODT setup.exe returned exit code: $($processInfo.ExitCode)"
            
            # Common ODT exit codes for better error messages
            switch ($processInfo.ExitCode)
            {
                30174 { $errorMessage += ' (Another installation is already in progress)' }
                30175 { $errorMessage += ' (This product is not supported on this operating system)' }
                30180 { $errorMessage += ' (Insufficient system resources)' }
                17002 { $errorMessage += ' (Invalid configuration XML)' }
                17004 { $errorMessage += ' (Required update channel not available)' }
                default { $errorMessage += ' (See ODT documentation for exit code details)' }
            }

            throw $errorMessage
        }

        Write-Verbose -Message "Office $Operation completed successfully."
    }
    catch
    {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            $_.Exception,
            "OfficeDeploymentToolFailed",
            [System.Management.Automation.ErrorCategory]::OperationStopped,
            $Path
        )
        
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
}

function TryGetRegistryValue
{
    param (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Key,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Property
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
        Write-Verbose -Message (
            "Failed to access Office ProductReleaseIds registry path: '{0}'" -f $global:OfficeProductReleaseIdsPath
        )
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
        Write-Verbose -Message 'No LanguageId specified, returning all valid languages.'
        
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
        $productReleaseIds = TryGetRegistryValue -Key $global:OfficeProductReleaseIdsPath -Property 'ProductReleaseIds'
        $currentState.ProductId = ($null -ne $productReleaseIds) ? ([ProductId]($productReleaseIds)) : $this.ProductId

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

        Install-OfficeProduct @installParams
    }

    [void] Install()
    {
        $this.Install($true)
    }

    [void] Uninstall([bool] $preTest)
    {
        $uninstallParams = @{
            Path       = $this.Path
            ProductId  = $this.ProductId
            Channel    = $this.Channel
            LanguageId = $this.LanguageId
        }
        Uninstall-OfficeProduct @uninstallParams
    }

    [void] Uninstall()
    {
        $this.Uninstall($true)
    }
    #endregion Classes
}