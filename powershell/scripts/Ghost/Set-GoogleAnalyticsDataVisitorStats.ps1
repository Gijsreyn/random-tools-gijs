function Get-GoogleApiAccessToken {
    param (
        [Parameter(Mandatory)]
        [string]$GoogleAccessJson,

        [Parameter(Mandatory = $false)]
        [string]$Scope = "https://www.googleapis.com/auth/analytics.readonly"
    )

    $jsonContent = ConvertFrom-Json -InputObject $GoogleAccessJson -Depth 10
    $ServiceAccountEmail = $jsonContent.client_email
    $PrivateKey = $jsonContent.private_key -replace '-----BEGIN PRIVATE KEY-----\n' -replace '\n-----END PRIVATE KEY-----\n' -replace '\n'
    $header = @{
        alg = "RS256"
        typ = "JWT"
    }
    $headerBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($header | ConvertTo-Json)))
    $timestamp = [Math]::Round((Get-Date -UFormat %s))
    $claimSet = @{
        iss   = $ServiceAccountEmail
        scope = $Scope
        aud   = "https://oauth2.googleapis.com/token"
        exp   = $timestamp + 3600
        iat   = $timestamp
        sub   = $ServiceAccountEmail
    }
    $claimSetBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($claimSet | ConvertTo-Json)))
    $signatureInput = $headerBase64 + "." + $claimSetBase64
    $signatureBytes = [System.Text.Encoding]::UTF8.GetBytes($signatureInput)
    $privateKeyBytes = [System.Convert]::FromBase64String($PrivateKey)
    $rsaProvider = [System.Security.Cryptography.RSA]::Create()
    $bytesRead = $null
    $rsaProvider.ImportPkcs8PrivateKey($privateKeyBytes, [ref]$bytesRead)
    $signature = $rsaProvider.SignData($signatureBytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $signatureBase64 = [System.Convert]::ToBase64String($signature)
    $jwt = $headerBase64 + "." + $claimSetBase64 + "." + $signatureBase64
    $body = @{
        grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer"
        assertion  = $jwt
    }
    $response = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method POST -Body $body -ContentType "application/x-www-form-urlencoded"
    $script:authorizationHeader = @{Authorization = 'Bearer {0}' -f $response.access_token }
}

function Invoke-GoogleAnalyticsReport {
    param(
        [Parameter(Mandatory)]
        [string]$PropertyId,
        [Parameter(Mandatory = $false)]
        [hashtable]$Authorization = $script:authorizationHeader,
        [Parameter(Mandatory=$false)]
        [string]$StartDate = (Get-Date).AddMonths(-1).ToString('yyyy-MM-dd'),
        [Parameter(Mandatory=$false)]
        [string]$EndDate = (Get-Date -Format "yyyy-MM-dd")
    )

    $uri = "https://analyticsdata.googleapis.com/v1beta/properties/$PropertyId`:runReport"

    # Request body
    $body = @{
        dateRanges = @(
            @{
                startDate = $StartDate
                endDate   = $EndDate
            }
        )
        metrics = @(
            @{
                name = "activeUsers"
            }
        )
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $Authorization -Body $body -ContentType "application/json"
        return $response
    }
    catch {
        Throw "Error calling GA4 API: $_"
    }
}

$Command = Get-Command -Name Get-AutomationVariable -ErrorAction SilentlyContinue
# When the command is available (e.g., in Azure Automation), use it to get variables; otherwise, read from local file and hardcoded ID
if ($Command) {
    $GoogleAccessJson = Get-AutomationVariable -Name 'GoogleAccessJson'
    $GA4PropertyId = Get-AutomationVariable -Name 'GA4PropertyId'

    Connect-AzAccount -Identity
} else {
    $GoogleAccessJson = Get-Content -Path "GoogleAccess.json" -Raw
    $GA4PropertyId = $env:GA4PropertyId
}

Write-Information -MessageData "Using GoogleAccessJson: $($GoogleAccessJson.Substring(0, 20))..." -InformationAction Continue
Get-GoogleApiAccessToken -GoogleAccessJson $GoogleAccessJson -Verbose

$response = Invoke-GoogleAnalyticsReport -PropertyId $GA4PropertyId -Verbose

Write-Information -MessageData "Active Users in the last 30 days: $($response.rows[0].metricValues[0].value)" -InformationAction Continue

$filePath = Join-Path -Path $env:TEMP -ChildPath "activeUsers.txt"
Write-Information -MessageData "Writing active users to $filePath" -InformationAction Continue
Set-Content -Path $filePath -Value $response.rows[0].metricValues[0].value -Force -Encoding UTF8

# Get storage account context
$storage = Get-AzStorageAccount -ResourceGroupName "rg-ghost-theme-analytics"
$ctx = $storage.Context

# Upload the file to the blob container
Set-AzStorageBlobContent -File $filePath -Container "analytics" -Blob "activeUsers.txt" -Context $ctx -Force