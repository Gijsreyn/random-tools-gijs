@{
    RootModule        = 'OfflineLanguageInstaller.psm1'
    ModuleVersion     = '1.0.1'
    GUID              = 'ac157b21-34fa-4dd3-8479-418ab0f1bc99'
    Author            = 'Gijs Reijn'
    Description       = 'Install languages on Windows 11 from an ISO file leveraging DISM/DSC'
    RequiredModules   = @('PSDscResources', 'PSDesiredStateConfiguration')
    FunctionsToExport = 'Install-LanguageFromIso'
    PrivateData       = @{
        PSData = @{
            Tags       = @('Language', 'Windows11', 'DISM', 'DSC', 'Offline')
            LicenseUri = 'https://github.com/Gijsreyn/random-tools-gijs/tree/main/powershell/modules/OfflineLanguageInstaller/LICENSE'
            ProjectUri = 'https://github.com/Gijsreyn/random-tools-gijs/tree/main/powershell/modules/OfflineLanguageInstaller'
            # IconUri = ''
        }
    }
}

