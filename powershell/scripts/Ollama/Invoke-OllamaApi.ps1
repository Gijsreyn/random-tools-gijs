function Invoke-OllamaApi
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Model,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Prompt,

        [Parameter()]
        [System.String]
        $HostName = 'http://localhost:11434'
    )

    begin
    {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)
    }

    process
    {
        $data = @{
            model  = $Model
            prompt = $Prompt
            stream = $false
        }
    
        $splatRestMethod = @{
            Method      = 'POST'
            Uri         = "$HostName/api/generate"
            Body        = ConvertTo-Json -InputObject $data
            ContentType = 'application/json; charset=utf-8'
        }
        Write-Verbose -Message "Invoking Ollama API with the following parameters: `n$($splatRestMethod | ConvertTo-Json | Out-String)"
        $response = Invoke-RestMethod @splatRestMethod
    
        return $response
    }

    end
    {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}