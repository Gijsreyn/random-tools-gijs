# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
@{
    RootModule           = 'Windows.Setting.Apps.OfflineMaps.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '7f06ce9a-81e8-498d-8919-cfd94cde612e'
    Author               = 'Gijs Reijn'
    Description          = 'DSC module for Windows Settings Apps Offline Maps'
    PowerShellVersion    = '7.4'
    FunctionsToExport    = @(
        'Get-OfflineMapPackage',
        'Get-GeoLocationCoordinate'
    )
    DscResourcesToExport = @(
        'OfflineMap',
        'OfflineMapSettings'
    )
    PrivateData          = @{
        PSData = @{
            Tags       = @(
                'OfflineMap', 'DSC', 'Windows'
            )

            LicenseUri = 'https://github.com/Gijsreyn/random-tools-gijs/tree/main/powershell/modules/Windows.Setting.Apps.OfflineMaps/LICENSE'
            ProjectUri = 'https://github.com/Gijsreyn/random-tools-gijs/tree/main/powershell/modules/Windows.Setting.Apps.OfflineMaps'
        }
    }
}
