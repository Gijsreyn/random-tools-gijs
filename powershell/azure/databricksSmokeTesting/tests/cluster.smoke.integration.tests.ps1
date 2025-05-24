param (
    [Parameter(Mandatory = $true)]
    $AzureResourceID
)

$script:toolDirectory = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'tools'
$script:testCaseDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) 'testcases'

Write-Verbose -Message "Storing tools in: '$toolDirectory'" -Verbose
Write-Verbose -Message "Test cases directory: '$testCaseDirectory'" -Verbose

BeforeDiscovery {
    $OldPSModulePath = $env:PSModulePath
    
    $env:PSModulePath += [System.IO.Path]::PathSeparator + $toolDirectory
    if (!(Get-Module -Name 'DatabricksPS' -ListAvailable)) {
        if (-not (Test-Path $toolDirectory -ErrorAction SilentlyContinue)) {
            New-Item -Path $toolDirectory -ItemType Directory -Force | Out-Null
        }
        Save-PSResource -Name 'DatabricksPS' -Path $toolDirectory -TrustRepository -Repository PSGallery
    }

    # Always authenticate first
    Set-DatabricksEnvironment -AzureResourceID $AzureResourceID -UsingAzContext
}

Describe "Cluster integration tests" {
    Context "Connectivity" {
        It "Should be able to authenticate to Databricks and get the workspace configuration" {
            $workspace = Get-DatabricksWorkspaceConfig
            $workspace | Should -Not -BeNullOrEmpty
        }
    }

    Context "ExternalLocations" {
        BeforeDiscovery {
            $unityExternalLocation = Get-UnityCatalogExternalLocation
        }

        It 'Should be able to pass all rules on : <_.name>' -ForEach $unityExternalLocation {
            $body = @{
                credential_name        = $_.credential_name
                external_location_name = $_.name
                read_only              = $false
            }

            # Check all the results
            try {
                $res = Invoke-DatabricksApiRequest -Method POST -EndPoint '2.1/unity-catalog/validate-credentials' -Body $body -ErrorAction Stop  
            }
            catch {
                $errorMessage = ($Error[0].ErrorDetails.Message | ConvertFrom-Json).details.reason
                Write-Verbose -Message "Error occured: $errorMessage" -Verbose
            }
            $res.results | Should -Not -BeNullOrEmpty
            $res.results[0].result | Should -Be 'PASS' # READ
            $res.results[1].result | Should -Be 'PASS' # LIST
            $res.results[2].result | Should -Be 'PASS' # WRITE
            $res.results[3].result | Should -Be 'PASS' # DELETE
            $res.results[4].result | Should -Be 'PASS' # PATH_EXISTS
            $res.results[5].result | Should -Be 'PASS' # HIERARCHAL_NAMESPACE_ENABLED
        }
    }

    Context "Workflow execution" {
        BeforeDiscovery {
            $unityExternalLocation = Get-UnityCatalogExternalLocation

            # Start the cluster
            $clusterConfig = Join-Path $testCaseDirectory 'testCase1ClusterConfig.json'
            $clusterConfiguration = Get-Content $clusterConfig | ConvertFrom-Json -AsHashtable

            $clusters = Get-DatabricksCluster
            $cluster = $clusters | Where-Object { $_.cluster_name -in $clusterConfiguration.cluster_name } | Select-Object -First 1
            if (!$cluster) {
                Write-Verbose -Message "Creating cluster $($clusterConfiguration.cluster_name)" -Verbose
                $functionInput = @{
                    Method   = 'Post'
                    Body     = $clusterConfiguration
                    EndPoint = '2.1/clusters/create'
                }
                $res = Invoke-DatabricksApiRequest @functionInput

                $cluster = Get-DatabricksCluster -ClusterID $res.cluster_id
            }

            if ($cluster.state -ne 'RUNNING') {
                Write-Verbose -Message "Starting cluster $($clusterConfiguration.cluster_name)" -Verbose
                $functionInput = @{
                    Method   = 'Post'
                    Body     = @{
                        cluster_id = $cluster.cluster_id
                    }
                    EndPoint = '2.1/clusters/start'
                }
                Write-Verbose -Message ($functionInput | ConvertTo-Json -Depth 10) -Verbose
                # Sometimes the cluster is in pending state and we only need to wait for it to start
                try {
                    Invoke-DatabricksApiRequest @functionInput -ErrorAction Stop     
                }
                catch {
                    Write-Warning -Message "Failed to start cluster $($clusterConfiguration.cluster_name). Error: $($_.Exception.Message)"
                }

                do {
                    Write-Verbose -Message 'Waiting for cluster to start' -Verbose
                    Start-Sleep -Seconds 30
                    $cluster = Get-DatabricksCluster -ClusterID $cluster.cluster_id
                    Write-Verbose -Message "Cluster state: $($cluster.state)" -Verbose
                } while ($cluster.state -ne 'RUNNING')
            }
        }

        It 'Should be able to run testCase1 in a job workflow on the cluster using : <_.name>' -ForEach $unityExternalLocation {
            
            # Create a new directory to load data in
            Add-DatabricksWorkspaceDirectory -Path '/testcases'

            # Import the item
            $localPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'testcases/testCase1.txt'

            $content = Get-Content $localPath -Raw
            $content = $content -replace '_REPLACEME_', $_.url 

            $newPath = Join-Path $testDrive 'testCase1.txt'
            $content | Set-Content -Path $newPath -Force

            $importParams = @{
                Path      = '/testcases/testCase1'
                Format    = 'SOURCE'
                Language  = 'PYTHON'
                Overwrite = $true
                LocalPath = $newPath
            }
            Write-Verbose -Message "Importing $localPath with" -Verbose
            Write-Verbose -Message ($importParams | ConvertTo-Json -Depth 10 | Out-String) -Verbose
            Import-DatabricksWorkspaceItem @importParams | Out-Null

            # Add databricks job pointing to the notebook
            $clusterConfig = Join-Path $testCaseDirectory 'testCase1ClusterConfig.json'
            $clusterConfiguration = Get-Content $clusterConfig | ConvertFrom-Json -AsHashtable

            $clusters = Get-DatabricksCluster
            $cluster = $clusters | Where-Object { $_.cluster_name -in $clusterConfiguration.cluster_name } | Select-Object -First 1
            
            Write-Verbose -Message 'Adding job to run the notebook' -Verbose
            $job = Add-DatabricksJob -Name 'testcase1' -NotebookPath '/Workspace/testcases/testCase1' -ClusterID $cluster.cluster_id
        
            # Run the job
            Write-Verbose -Message "Starting job $($job.job_id)" -Verbose
            $jobStart = Start-DatabricksJob -JobID $job.job_id

            # Wait for the job to finish we try 10 times
            $maxRetries = 10
            $retryCount = 0
            do {
                Start-Sleep -Seconds 10
                $jobState = Get-DatabricksJobRunOutput -JobRunId $jobStart.run_id
                Write-Verbose -Message "Job state: $($jobState.metadata.status.state)" -Verbose
                $retryCount++
            } while ($jobState.metadata.status.state -ne 'TERMINATED' -and $retryCount -lt $maxRetries)

            $jobState = Get-DatabricksJobRunOutput -JobRunId $jobStart.run_id
            $jobState.metadata.status.termination_details.code | Should -Be 'SUCCESS'
        }

        AfterAll {
            Get-DatabricksJob | Where-Object { $_.settings.name -eq 'testcase1' } | Remove-DatabricksJob
            Remove-DatabricksWorkspaceItem -Path '/testcases/testCase1' -Recursive $true

            # Uncomment the following line to remove the cluster after the test
            # Get-DatabricksCluster | Where-Object { $_.cluster_name -eq $clusterConfiguration.cluster_name } | Remove-DatabricksCluster
        }
    }
}

AfterAll {
    $env:PSModulePath = $OldPSModulePath
}