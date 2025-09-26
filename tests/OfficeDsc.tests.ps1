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
        Install-PSResource -Name PSDesiredStateConfiguration -Version 2.0.7 -Repository $repository -TrustRepository
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
    Context 'Get Method Tests' {
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
            $result.ExcludeApps | Should -BeOfType [System.Array]
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
            $result.LanguageId | Should -BeOfType [System.Array]
        }
    }

    Context 'Test Method Tests' {
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
                $result.InDesiredState | Should -BeOfType [System.Boolean]
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
                $result.InDesiredState | Should -BeOfType [System.Boolean]
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
                $result.InDesiredState | Should -BeOfType [System.Boolean]
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

    Context 'Set Method Tests' {
        It 'Should skip Set method when not running as Administrator' -Skip:$script:isElevated {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Set'
                Property = @{
                    Path = $script:mockOdtPath
                    Exist = $true
                }
            }

            { Invoke-DscResource @dscResourceParameters } | Should -Throw '*administrative privileges*'
        }

        It 'Should attempt to install Office when Exist is true and running as Administrator' -Skip:(-not $script:isElevated) {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Set'
                Property = @{
                    Path = $script:mockOdtPath
                    Exist = $true
                }
            }

            # This will fail because the mock ODT path doesn't exist, but we're testing the flow
            { Invoke-DscResource @dscResourceParameters } | Should -Throw
        }

        It 'Should attempt to uninstall Office when Exist is false and running as Administrator' -Skip:(-not $script:isElevated) {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Set'
                Property = @{
                    Path = $script:mockOdtPath
                    Exist = $false
                }
            }

            # This will fail because the mock ODT path doesn't exist, but we're testing the flow
            { Invoke-DscResource @dscResourceParameters } | Should -Throw
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

        It 'Should validate that Path is an executable file' -Skip:(-not $script:isElevated) {
            $textFilePath = [System.IO.Path]::GetTempFileName()
            try {
                $dscResourceParameters = @{
                    ModuleName = 'OfficeDsc'
                    Name = 'Office365Installer'
                    Method = 'Set'
                    Property = @{
                        Path = $textFilePath
                        Exist = $true
                    }
                }

                { Invoke-DscResource @dscResourceParameters } | Should -Throw '*not an executable file*'
            }
            finally {
                Remove-Item -Path $textFilePath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Integration Tests with Complex Configurations' {
        It 'Should handle complete Office 365 Pro Plus configuration' {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Get'
                Property = @{
                    Path = $script:mockOdtPath
                    ProductId = 'O365ProPlusRetail'
                    Channel = 'MonthlyEnterprise'
                    ExcludeApps = @('Teams', 'OneNote', 'Access')
                    LanguageId = @('en-US', 'fr-FR', 'de-DE')
                    Exist = $true
                }
            }

            $result = Invoke-DscResource @dscResourceParameters
            
            $result | Should -Not -BeNullOrEmpty
            $result.Path | Should -Be $script:mockOdtPath
            $result.ProductId | Should -Be 'O365ProPlusRetail'
        }

        It 'Should handle Office 365 Business configuration' {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Get'
                Property = @{
                    Path = $script:mockOdtPath
                    ProductId = 'O365BusinessRetail'
                    Channel = 'Current'
                    ExcludeApps = @('Teams')
                    LanguageId = @('en-US')
                    Exist = $true
                }
            }

            $result = Invoke-DscResource @dscResourceParameters
            
            $result | Should -Not -BeNullOrEmpty
            $result.ProductId | Should -Be 'O365BusinessRetail'
        }

        It 'Should handle minimal configuration with defaults' {
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

        It 'Should test complete configuration for desired state' {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Test'
                Property = @{
                    Path = $script:mockOdtPath
                    ProductId = 'O365ProPlusEEANoTeamsRetail'
                    Channel = 'SemiAnnual'
                    ExcludeApps = @('OneNote', 'Publisher')
                    LanguageId = @('en-GB', 'fr-FR')
                    Exist = $false
                }
            }

            $result = Invoke-DscResource @dscResourceParameters
            $result.InDesiredState | Should -BeOfType [System.Boolean]
        }
    }

    Context 'Error Handling Tests' {
        It 'Should handle missing mandatory Path parameter' {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Get'
                Property = @{}
            }

            { Invoke-DscResource @dscResourceParameters } | Should -Throw
        }

        It 'Should handle invalid ProductId enum value' {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Get'
                Property = @{
                    Path = $script:mockOdtPath
                    ProductId = 'InvalidProductId'
                }
            }

            { Invoke-DscResource @dscResourceParameters } | Should -Throw
        }

        It 'Should handle invalid Channel enum value' {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Get'
                Property = @{
                    Path = $script:mockOdtPath
                    Channel = 'InvalidChannel'
                }
            }

            { Invoke-DscResource @dscResourceParameters } | Should -Throw
        }

        It 'Should handle invalid ExcludeApps enum values' {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Get'
                Property = @{
                    Path = $script:mockOdtPath
                    ExcludeApps = @('InvalidApp1', 'InvalidApp2')
                }
            }

            { Invoke-DscResource @dscResourceParameters } | Should -Throw
        }
    }

    Context 'Boundary Value Tests' {
        It 'Should handle empty ExcludeApps array' {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Get'
                Property = @{
                    Path = $script:mockOdtPath
                    ExcludeApps = @()
                }
            }

            $result = Invoke-DscResource @dscResourceParameters
            $result.ExcludeApps | Should -Be @()
        }

        It 'Should handle maximum number of excluded apps' {
            $allApps = @('Access', 'Excel', 'Groove', 'Lync', 'OneDrive', 'OneNote', 'Outlook', 'OutlookForWindows', 'PowerPoint', 'Publisher', 'Teams', 'Word')
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Get'
                Property = @{
                    Path = $script:mockOdtPath
                    ExcludeApps = $allApps
                }
            }

            $result = Invoke-DscResource @dscResourceParameters
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should handle empty LanguageId array' {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Get'
                Property = @{
                    Path = $script:mockOdtPath
                    LanguageId = @()
                }
            }

            $result = Invoke-DscResource @dscResourceParameters
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should handle null LanguageId' {
            $dscResourceParameters = @{
                ModuleName = 'OfficeDsc'
                Name = 'Office365Installer'
                Method = 'Get'
                Property = @{
                    Path = $script:mockOdtPath
                    LanguageId = $null
                }
            }

            $result = Invoke-DscResource @dscResourceParameters
            $result | Should -Not -BeNullOrEmpty
        }
    }

    AfterAll {
        # Clean up test registry path
        Remove-Item -Path 'Env:TestRegistryPath' -ErrorAction SilentlyContinue
    }
}