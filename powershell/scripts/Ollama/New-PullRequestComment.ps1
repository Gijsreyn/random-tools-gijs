function New-PullRequestComment
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Content
    )

    begin
    {
        Write-Verbose -Message ('{0} started' -f $MyInvocation.MyCommand)
    }

    process 
    {
        try
        {
            $uri = ('{0}{1}/_apis/git/repositories/{2}/pullRequests/{3}/threads?api-version=7.1' -f $Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI, `
                    $Env:SYSTEM_TEAMPROJECTID, `
                    $Env:BUILD_REPOSITORY_NAME, `
                    $Env:SYSTEM_PULLREQUEST_PULLREQUESTID
            )
            Write-Verbose "Using URL: $uri"

            $Body = @{
                comments = @(
                    @{
                        parentCommentId = 0
                        content         = $Content
                        commentType     = 1
                    }
                )
                status   = 1
            }
            $Body = $Body | ConvertTo-Json -Depth 10
    
            $params = @{
                Uri         = $uri
                Method      = 'POST'
                Headers     = @{ Authorization = "Bearer $Env:SYSTEM_ACCESSTOKEN" }
                Body        = $Body
                ContentType = 'application/json'
            }
            Write-Debug -Message ('Posting comment to {0} with' -f $uri)
            Write-Debug -Message ($params | ConvertTo-Json -Depth 10 | Out-String)
            $response = Invoke-RestMethod @params

            $response
    
            if ($null -eq $response)
            {
                Write-Verbose 'Successfully posted the pull request comment.'
            }
        }
        catch
        {
            Write-Error $_
            Write-Error $_.Exception.Message
        }
    }

    end
    {
        Write-Verbose -Message ('{0} ended' -f $MyInvocation.MyCommand)
    }
}