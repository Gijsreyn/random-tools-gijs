Describe 'OfflineMap' {
    Context 'Package availability' {
        $testCases = Get-GeoLocationCoordinate -ReturnAddress

        It '[<_>] Get offline map package availability' -TestCases $testCases {
            param (
                [string]$Address
            )

            $offlineMap = Get-OfflineMapPackage -Address $_
            $offlineMap.Packages | Should -Not -BeNullOrEmpty
        }
    }
}
