
#region private functions
function Test-Administrator {  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $res = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
    
    if (-not $res) {  
        Throw 'This script must be run as an administrator'  
    }
}

function Test-RequiredModules {
    if (-not (Get-Module -Name PSDscResources -ListAvailable | Where-Object { $_.Version -eq '2.12.0.0' })) {
        Throw 'The module PSDscResources version 2.12.0.0 was not installed. Please install the module and try again.'
    }

    if (-not (Get-Module -Name PSDesiredStateConfiguration -ListAvailable | Where-Object { $_.Version -eq '2.0.7' })) {
        Throw 'The module PSDesiredStateConfiguration version 2.0.7 was not installed. Please install the module and try again.'
    }
}

function Get-BasicLanguageCabFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $LanguageCode,

        [Parameter()]
        [string] $DiskImagePath = 'D:\'
    )

    $cabFiles = Get-ChildItem -Path "$DiskImagePath\LanguagesAndOptionalFeatures" -Recurse -Filter '*.cab'
    $basicCabFile = $cabFiles | Where-Object { $_.Name -match "Microsoft-Windows-LanguageFeatures-Basic-$LanguageCode" } 

    if (-not $basicCabFile) {
        Throw "No basic cab file found for $LanguageCode"
    }

    $files.Add($basicCabFile) | Out-Null
    return $cabFiles
}

function Get-AdditionalLanguageCabFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $LanguageCode,

        [Parameter(Mandatory = $true)]
        [string[]] $CabFiles,

        [Parameter(Mandatory = $true)]
        [ValidateSet('TextToSpeech', 'HandWriting', 'OCR', 'Speech')]
        [string[]] $Features
    )

    foreach ($feature in $Features) {
        $pattern = "Microsoft-Windows-LanguageFeatures-$feature-$LanguageCode"
        Write-Verbose -Message "Searching for additional cab file using $pattern"
        $additionalCabFiles = $cabFiles | Where-Object { $_ -match $pattern }

        Write-Verbose $additionalCabFiles

        if (-not $additionalCabFiles) {
            Write-Warning "No additional cab file found for $LanguageCode and $feature"
            continue
        }

        Write-Verbose -Message "Found additional cab file $additionalCabFiles. Adding to collection..."
        $files.Add($additionalCabFiles) | Out-Null
    }
}

function Mount-Iso ($IsoPath) {
    Write-Verbose -Message 'Retrieving current volumes'
    $Volumes = (Get-Volume).Where({ $_.DriveLetter }).DriveLetter
    Write-Verbose -Message "Mounting $IsoPath"
    Mount-DiskImage -ImagePath $IsoPath | Out-Null
    Write-Verbose 'Determining drive letter for ISO'
    $ISO = (Compare-Object -ReferenceObject $Volumes -DifferenceObject (Get-Volume).Where({ $_.DriveLetter }).DriveLetter).InputObject.ToString().Insert(1, ':\')
    return $Iso
}

function Invoke-Dsc {
    [CmdletBinding()]
    param (
        [Parameter()]
        [hashtable]$Property
    )

    $functionInput = @{
        Name       = 'WindowsPackageCab'
        ModuleName = 'PSDscResources'
        Method     = 'Test'
        Property   = $Property
    }

    $testResult = Invoke-DscResource @functionInput

    if ($testResult.InDesiredState) {
        Write-Verbose -Message 'The package is already installed'
        return
    }

    $functionInput.Method = 'Set'

    Write-Verbose -Message 'Invoking DSC resource with the following properties:'
    Write-Verbose -Message ($Property | ConvertTo-Json | Out-String)
    Invoke-DscResource @functionInput
}
#endregion private functions

#region public functions
function Install-LanguageFromIso {
    <#
    .SYNOPSIS
        Install languages on Windows 11 from an ISO file leveraging DISM/DSC
    
    .DESCRIPTION
        The function Install-LanguageFromIso installs language packs on Windows 11 from an ISO file. The function does the following: 
        
        * Mounts the ISO file
        * Retrieves the basic language cab file
        * Optionally additional cab files for features like TextToSpeech, Handwriting, OCR, and Speech. 
        
        The cab files are copied to a temporary directory and installed using the DSC resource WindowsPackageCab.
    
    .PARAMETER IsoPath
        The path to the ISO file containing the language cab files
    
    .PARAMETER LanguageCode
        The language code of the language to install e.g. en-us
    
    .PARAMETER Features
        The features to install. The following features are supported: TextToSpeech, Handwriting, OCR, and Speech
    
    .PARAMETER AddToUserLanguageList
        Switch to add the language to the user language list
    
    .EXAMPLE
        PS C:\> Install-LanguageFromIso -IsoPath 'C:\ISOs\26100.1.240331-1435.ge_release_amd64fre_CLIENT_LOF_PACKAGES_OEM.iso' -LanguageCode 'en-us' -Features 'TextToSpeech', 'Handwriting'

        This example installs the English language pack with the features TextToSpeech and Handwriting from the specified ISO file.

    .EXAMPLE 
        PS C:\> Install-LanguageFromIso -IsoPath 'C:\ISOs\26100.1.240331-1435.ge_release_amd64fre_CLIENT_LOF_PACKAGES_OEM.iso' -LanguageCode 'en-us'

        This example installs the English language pack without any additional features from the specified ISO file.

    .EXAMPLE
        PS C:\> Install-LanguageFromIso -IsoPath 'C:\ISOs\26100.1.240331-1435.ge_release_amd64fre_CLIENT_LOF_PACKAGES_OEM.iso' -LanguageCode 'en-GB' -AddToUserLanguageList

        This example installs the English (United Kingdom) language pack and adds it to the user language list.
    
    .NOTES
        Author: Gijs Reijn
        Version: 1.0.0
        Date: 2025-01-07
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({
                if (-Not ($_ | Test-Path -PathType Leaf) ) { throw 'The Path argument must be a file. Folder paths are not allowed.' }
                if ($_ -notmatch '\.iso$') { throw 'The file specified in the path argument must be type .iso' }
                return $true
            })]
        [System.IO.FileInfo]
        $IsoPath,

        [Parameter(Mandatory = $true)]
        [string] $LanguageCode,

        [Parameter()]
        [ValidateSet('TextToSpeech', 'Handwriting', 'OCR', 'Speech')]
        [string[]] $Features,

        [Parameter()]
        [switch] $AddToUserLanguageList
    )

    begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand.Name)

        Test-Administrator
        Test-RequiredModules 

        $global:files = [System.Collections.ArrayList]@()
    }

    process {
        # Mount the ISO
        $diskImagePath = Mount-Iso -IsoPath $IsoPath

        # Get the basic language cab file
        $cabFiles = Get-BasicLanguageCabFile -LanguageCode $LanguageCode -DiskImagePath $diskImagePath

        # Get additional language cab files if features are specified
        if ($Features) {
            Get-AdditionalLanguageCabFiles -LanguageCode $LanguageCode -CabFiles $cabFiles -Features $Features
        }

        # Copy the cab files to the destination path
        $destinationPath = Join-Path $env:TEMP -ChildPath 'LanguageCabFiles'
        New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null

        $sourcePaths = foreach ($file in $files) {
            Write-Verbose -Message "Copying $file to $destinationPath"
            Copy-Item -Path $file -Destination $destinationPath -PassThru -Force
        }

        # Dismount the ISO
        Write-Verbose -Message 'Dismounting ISO'
        Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue | Out-Null

        # Call the DSC resource to install the cab files
        foreach ($sourcePath in $sourcePaths) {
            $property = @{
                Name       = $sourcePath.Name
                Ensure     = 'Present'
                SourcePath = $sourcePath.FullName
                LogPath    = (Join-Path -Path $env:TEMP -ChildPath 'WindowsPackageCab.log')
            }

            if ($PSCmdlet.ShouldProcess($sourcePath, 'Install')) {
                Invoke-Dsc -Property $property
            }
        }

        if ($AddToUserLanguageList.IsPresent) {
            $currentList = Get-WinUserLanguageList
            Write-Verbose -Message "Adding $LanguageCode to the user language list"
            $currentList.Add($LanguageCode)

            #  Set the user language list
            Set-WinUserLanguageList -LanguageList $currentList -Force
        }
    }
    
    end {
        Write-Verbose -Message ('Ending {0}' -f $MyInvocation.MyCommand)
    }
}
#endregion public functions