function Get-OllamaModel
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ModelName
    )

    begin 
    {
        $startTime = Get-Date
        Write-Verbose -Message "Start time: $($startTime.ToString('HH:mm:ss'))"
    }

    process
    {
        Write-Verbose -Message "Pulling model: $ModelName."
        & ollama pull $ModelName 

        if ($Lastexitcode -ne 0)
        {
            Write-Error "Failed to pull model: $ModelName. See the error above."
        }
        
    }

    end 
    {
        $endTime = Get-Date
        $elapsedTime = $endTime - $startTime
        Write-Verbose -Message "End time: $($endTime.ToString('HH:mm:ss'))"
        Write-Verbose -Message "Elapsed time: $($elapsedTime.ToString('mm\:ss'))"
    }
}