@{
    RootModule           = 'OfficeDsc.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '0b08f627-da4b-4232-a14f-df9cb45f5a27'
    Author               = 'Gijs Reijn'
    Copyright            = 'Gijs Reijn. All rights reserved.'
    Description          = 'DSC Resource for Microsoft Office Deployment'
    PowerShellVersion    = '7.2'
    DscResourcesToExport = @(
        'Office365Installer'
    )
    PrivateData          = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = @(
                'PSDscResource_Office365Installer'
            )

            LicenseUri = 'https://github.com/Gijsreyn/random-tools-gijs/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/Gijsreyn/random-tools-gijs/tree/main/powershell/modules/OfficeDsc'
        }
    }
}
