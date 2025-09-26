$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

<#
.Synopsis
   Pester tests related to the OfficeDsc PowerShell module.
#>

BeforeDiscovery {
    if ($IsWindows) {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
        $script:isElevated = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
}

BeforeAll {
    $FullyQualifiedName = @{ModuleName = "PSDesiredStateConfiguration"; ModuleVersion = "2.0.7" }
    if (-not(Get-Module -ListAvailable -FullyQualifiedName $FullyQualifiedName))
    {
        Install-PSResource -Name PSDesiredStateConfiguration -Version 2.0.7 -Repository 'PSGallery' -TrustRepository
    }

    $outFile = Join-Path $env:TEMP 'setup.exe'
    Invoke-RestMethod -Uri 'https://officecdn.microsoft.com/pr/wsus/setup.exe' -OutFile $outFile -ErrorAction Stop
    $script:mockOdtPath = $outFile
}

Describe 'List available DSC resources' {
    It 'Shows DSC Resources' {
        $expectedDSCResources = 'Office365Installer'
        $availableDSCResources = (Get-DscResource -Module OfficeDsc).Name
        $availableDSCResources | Should -Not -BeNullOrEmpty
        $availableDSCResources | Where-Object { $expectedDSCResources -notcontains $_ } | Should -BeNullOrEmpty -ErrorAction Stop
    }
}

Describe 'Office365Installer DSC Resource' {
    Context 'Get' {
        It 'Should return current state with default values when Office is not installed' {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Get'
                Property = @{
                    Path = $script:mockOdtPath
                }
            }

            $result = Invoke-DscResource @dscResourceParameters
            
            $result | Should -Not -BeNullOrEmpty
            $result.Path | Should -Be $script:mockOdtPath
            $result.ProductId | Should -Be 'O365ProPlusRetail'
            $result.Channel | Should -Be 'Current'
            $result.ExcludeApps | Should -Be @()
            $result.Exist | Should -Be $false
        }

        It 'Should return current state with specific ProductId' {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Get'
                Property = @{
                    Path = $script:mockOdtPath
                    ProductId = 'O365BusinessRetail'
                }
            }

            $result = Invoke-DscResource @dscResourceParameters
            
            $result | Should -Not -BeNullOrEmpty
            $result.ProductId | Should -Be 'O365BusinessRetail'
        }

        It 'Should return current state with custom channel' {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Get'
                Property = @{
                    Path = $script:mockOdtPath
                    Channel = 'MonthlyEnterprise'
                }
            }

            $result = Invoke-DscResource @dscResourceParameters
            
            $result | Should -Not -BeNullOrEmpty
            $result.Channel | Should -BeIn @('Current', 'MonthlyEnterprise')
        }

        It 'Should return current state with excluded apps' {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Get'
                Property = @{
                    Path = $script:mockOdtPath
                    ExcludeApps = @('Teams', 'OneNote')
                }
            }

            $result = Invoke-DscResource @dscResourceParameters
            
            $result | Should -Not -BeNullOrEmpty
            $result.ExcludeApps | Should -BeNullOrEmpty # because Office is not installed
        }

        It 'Should return current state with specific language IDs' {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Get'
                Property = @{
                    Path = $script:mockOdtPath
                    LanguageId = @('en-US', 'fr-FR')
                }
            }

            $result = Invoke-DscResource @dscResourceParameters
            
            $result | Should -Not -BeNullOrEmpty
            $result.LanguageId | Should -BeNullOrEmpty # because Office is not installed
        }
    }

    Context 'Test' {
        It 'Should return false when Office is not installed but should exist' {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Test'
                Property = @{
                    Path = $script:mockOdtPath
                    Exist = $true
                }
            }

            $result = Invoke-DscResource @dscResourceParameters
            $result.InDesiredState | Should -Be $false
        }

        It 'Should return true when Office is not installed and should not exist' {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Test'
                Property = @{
                    Path = $script:mockOdtPath
                    Exist = $false
                }
            }

            $result = Invoke-DscResource @dscResourceParameters
            $result.InDesiredState | Should -Be $true
        }

        It 'Should test with different ProductId configurations' {
            $productIds = @('O365ProPlusRetail', 'O365BusinessRetail', 'O365ProPlusEEANoTeamsRetail', 'O365BusinessEEANoTeamsRetail')
            
            foreach ($productId in $productIds) {
                $dscResourceParameters = @{
                    ModuleName = 'OfficeDsc'
                    Name = 'Office365Installer'
                    Method = 'Test'
                    Property = @{
                        Path = $script:mockOdtPath
                        ProductId = $productId
                        Exist = $false
                    }
                }

                $result = Invoke-DscResource @dscResourceParameters
                $result.InDesiredState | Should -Be $true
            }
        }

        It 'Should test with different Channel configurations' {
            $channels = @('Current', 'MonthlyEnterprise', 'SemiAnnual', 'SemiAnnualPreview', 'CurrentPreview', 'BetaChannel')
            
            foreach ($channel in $channels) {
                $dscResourceParameters = @{
                    ModuleName = 'OfficeDsc'
                    Name = 'Office365Installer'
                    Method = 'Test'
                    Property = @{
                        Path = $script:mockOdtPath
                        Channel = $channel
                        Exist = $false
                    }
                }

                $result = Invoke-DscResource @dscResourceParameters
                $result.InDesiredState | Should -Be $true
            }
        }

        It 'Should test with excluded applications' {
            $excludeAppCombinations = @(
                @('Teams'),
                @('OneNote', 'Teams'),
                @('Outlook', 'Teams', 'OneNote'),
                @('Access', 'Publisher')
            )
            
            foreach ($excludeApps in $excludeAppCombinations) {
                $dscResourceParameters = @{
                    ModuleName = 'OfficeDsc'
                    Name = 'Office365Installer'
                    Method = 'Test'
                    Property = @{
                        Path = $script:mockOdtPath
                        ExcludeApps = $excludeApps
                        Exist = $false
                    }
                }

                $result = Invoke-DscResource @dscResourceParameters
                $result.InDesiredState | Should -Be $true
            }
        }

        It 'Should test with language configurations' {
            $languageConfigurations = @(
                @('en-US'),
                @('en-US', 'fr-FR'),
                @('en-US', 'de-DE', 'es-ES')
            )
            
            foreach ($languageIds in $languageConfigurations) {
                $dscResourceParameters = @{
                    ModuleName = 'OfficeDsc'
                    Name = 'Office365Installer'
                    Method = 'Test'
                    Property = @{
                        Path = $script:mockOdtPath
                        LanguageId = $languageIds
                        Exist = $false
                    }
                }

                $result = Invoke-DscResource @dscResourceParameters
                $result.InDesiredState | Should -BeOfType [System.Boolean]
            }
        }
    }

    Context 'Set' {
        It 'Should install office' -Skip:(!$script:isElevated) {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Set'
                Property = @{
                    Path = $script:mockOdtPath
                    Exist = $true
                }
            }

            Invoke-DscResource @dscResourceParameters

            $dscResourceParameters.Method = 'Test'
            $result = Invoke-DscResource @dscResourceParameters
            $result.InDesiredState | Should -Be $true
            $result.Channel | Should -Be 'Current'
            $result.ProductId | Should -Be 'O365ProPlusRetail'
            $result.ExcludeApps | Should -Be @()
            $result.LanguageId | Should -Not -BeNullOrEmpty
        }

        It 'Should uninstall Office when set to false' {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Set'
                Property = @{
                    Path = $script:mockOdtPath
                    Exist = $false
                }
            }

            Invoke-DscResource @dscResourceParameters

            $dscResourceParameters.Method = 'Test'
            $result = Invoke-DscResource @dscResourceParameters
            $result.InDesiredState | Should -Be $true
        }

        It 'Should validate ODT path before attempting installation' -Skip:(-not $script:isElevated) {
            $invalidPath = 'C:\NonExistent\setup.exe'
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Set'
                Property = @{
                    Path = $invalidPath
                    Exist = $true
                }
            }

            { Invoke-DscResource @dscResourceParameters } | Should -Throw '*does not exist*'
        }
    }

    # Context 'Integration Tests with Complex Configurations' {
    #     It 'Should handle complete Office 365 Pro Plus configuration' {
    #         $dscResourceParameters = @{
    #             ModuleName = 'OfficeDsc'
    #             Name = 'Office365Installer'
    #             Method = 'Get'
    #             Property = @{
    #                 Path = $script:mockOdtPath
    #                 ProductId = 'O365ProPlusRetail'
    #                 Channel = 'MonthlyEnterprise'
    #                 ExcludeApps = @('Teams', 'OneNote', 'Access')
    #                 LanguageId = @('en-US', 'fr-FR', 'de-DE')
    #                 Exist = $true
    #             }
    #         }

    #         $result = Invoke-DscResource @dscResourceParameters
            
    #         $result | Should -Not -BeNullOrEmpty
    #         $result.Path | Should -Be $script:mockOdtPath
    #         $result.ProductId | Should -Be 'O365ProPlusRetail'
    #     }

    #     It 'Should handle Office 365 Business configuration' {
    #         $dscResourceParameters = @{
    #             ModuleName = 'OfficeDsc'
    #             Name = 'Office365Installer'
    #             Method = 'Get'
    #             Property = @{
    #                 Path = $script:mockOdtPath
    #                 ProductId = 'O365BusinessRetail'
    #                 Channel = 'Current'
    #                 ExcludeApps = @('Teams')
    #                 LanguageId = @('en-US')
    #                 Exist = $true
    #             }
    #         }

    #         $result = Invoke-DscResource @dscResourceParameters
            
    #         $result | Should -Not -BeNullOrEmpty
    #         $result.ProductId | Should -Be 'O365BusinessRetail'
    #     }

    #     It 'Should handle minimal configuration with defaults' {
    #         $dscResourceParameters = @{
    #             ModuleName = 'OfficeDsc'
    #             Name = 'Office365Installer'
    #             Method = 'Get'
    #             Property = @{
    #                 Path = $script:mockOdtPath
    #             }
    #         }

    #         $result = Invoke-DscResource @dscResourceParameters
            
    #         $result | Should -Not -BeNullOrEmpty
    #         $result.Path | Should -Be $script:mockOdtPath
    #         $result.ProductId | Should -Be 'O365ProPlusRetail'
    #         $result.Channel | Should -Be 'Current'
    #         $result.ExcludeApps | Should -Be @()
    #         $result.Exist | Should -Be $false
    #     }

    #     It 'Should test complete configuration for desired state' {
    #         $dscResourceParameters = @{
    #             ModuleName = 'OfficeDsc'
    #             Name = 'Office365Installer'
    #             Method = 'Test'
    #             Property = @{
    #                 Path = $script:mockOdtPath
    #                 ProductId = 'O365ProPlusEEANoTeamsRetail'
    #                 Channel = 'SemiAnnual'
    #                 ExcludeApps = @('OneNote', 'Publisher')
    #                 LanguageId = @('en-GB', 'fr-FR')
    #                 Exist = $false
    #             }
    #         }

    #         $result = Invoke-DscResource @dscResourceParameters
    #         $result.InDesiredState | Should -BeOfType [System.Boolean]
    #     }
    # }
}