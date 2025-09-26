class GitHubPullRequest
{
    [int]$Number
    [string]$Title
    [string]$Url
    [string]$MergeableState
    [string]$MergeStateStatus
    [bool]$IsMergeable
    [string]$StatusDescription
    [string]$MergeableDescription

    GitHubPullRequest([int]$number, [string]$title, [string]$url, [string]$mergeableState, [string]$mergeStateStatus)
    {
        $this.Number = $number
        $this.Title = $title
        $this.Url = $url
        $this.MergeableState = $mergeableState
        $this.MergeStateStatus = $mergeStateStatus
        $this.IsMergeable = ($mergeableState -eq 'MERGEABLE')
        $this.StatusDescription = switch ($mergeStateStatus)
        {
            'BEHIND' { 'The head ref is out of date' }
            'BLOCKED' { 'The merge is blocked' }
            'CLEAN' { 'Mergeable and passing commit status' }
            'DIRTY' { 'The merge commit cannot be cleanly created' }
            'DRAFT' { 'The merge is blocked due to the pull request being a draft' }
            'HAS_HOOKS' { 'Mergeable with passing commit status and pre-receive hooks' }
            'UNKNOWN' { 'The state cannot currently be determined' }
            'UNSTABLE' { 'Mergeable with non-passing commit status' }
            default { 'Unknown status' }
        }
        $this.MergeableDescription = switch ($mergeableState)
        {
            'CONFLICTING' { 'The pull request cannot be merged due to merge conflicts' }
            'MERGEABLE' { 'The pull request can be merged' }
            'UNKNOWN' { 'The mergeability of the pull request is still being calculated' }
            default { 'Unknown mergeable state' }
        }
    }
}

function New-PullRequest
{
    param (
        [int]$number,
        [string]$title,
        [string]$url,
        [string]$mergeableState,
        [string]$mergeStateStatus
    )
    return [GitHubPullRequest]::new($number, $title, $url, $mergeableState, $mergeStateStatus)
}

function Find-MergeableGitHubPullRequests
{
    <#
    .SYNOPSIS
        Find mergeable GitHub pull requests for a repository.
    
    .DESCRIPTION
        The function Find-MergeableGitHubPullRequests finds mergeable GitHub pull requests for a specified repository using the GitHub CLI (gh).
    
    .PARAMETER Owner
        The owner of the repository.

    .PARAMETER Name
        The name of the repository.

    .EXAMPLE
        PS C:\> Find-MergeableGitHubPullRequests -Owner "PowerShell" -Name "DSC"

    .NOTES
        Tags: GitHub
        Author: @GijsReyn
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Owner,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Name
    )

    begin
    { 
        Write-Verbose -Message "Starting $($MyInvocation.MyCommand.Name)"
        $repo = "$Owner/$Name"

        # the fields we want to retrieve from GitHub
        $jsonProps = "url,title,mergeStateStatus,mergeable,number"
    }

    process
    {
        Write-Verbose -Message "Finding mergeable pull requests in repository '$repo'"
        $pullRequests = gh pr list --repo $repo --author "@me" --state open --json $jsonProps | ConvertFrom-Json
        if (-not $pullRequests -or $pullRequests.Count -eq 0) { return }

        foreach ($pr in $pullRequests)
        {
            [GitHubPullRequest]::new($pr.number, 
                $pr.title, 
                $pr.url, 
                $pr.mergeable, 
                $pr.mergeStateStatus
            )
        }
    }

    end 
    {
        Write-Verbose -Message "Ending $($MyInvocation.MyCommand.Name)"
    }
}

function Merge-OrRebasePullRequests
{
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [GitHubPullRequest[]]
        $PullRequests,

        [Parameter()]
        [switch]
        $DeleteBranch
    )

    begin
    {
        Write-Verbose -Message "Starting $($MyInvocation.MyCommand.Name)"
    }

    process
    {
        foreach ($pr in $PullRequests)
        {
            $urlParts = $pr.Url -split '/'
            $repoOwner = $urlParts[3]
            $repoName = $urlParts[4]
            $repoFullName = "$repoOwner/$repoName"
            
            if ($pr.MergeStateStatus -eq 'CLEAN')
            {
                Write-Verbose -Message "Rebasing PR #$($pr.Number): $($pr.Title)"
                if ($PSCmdlet.ShouldProcess("PR #$($pr.Number) - $($pr.Title)", "Rebase and merge"))
                {
                    try
                    {
                        $mergeArgs = @('pr', 'merge', $pr.Number, '--repo', $repoFullName, '--rebase')
                        if ($DeleteBranch.IsPresent)
                        {
                            $mergeArgs += '--delete-branch'
                        }
                        
                        Write-Verbose -Message "Executing: gh $($mergeArgs -join ' ')"
                        & gh @mergeArgs
                        
                        if ($LASTEXITCODE -eq 0)
                        {
                            Write-Information -MessageData "Successfully rebased and merged PR '#$($pr.Number)'" -InformationAction Continue
                        }
                        else
                        {
                            Write-Error -Message "Failed to rebase and merge PR '#$($pr.Number)'. Exit code: $LASTEXITCODE"
                        }
                    }
                    catch
                    {
                        Write-Error -Message "Error rebasing PR '#$($pr.Number)': $($_.Exception.Message)"
                    }
                }
            }
            elseif ($pr.MergeStateStatus -eq 'BLOCKED' -and $pr.IsMergeable)
            {
                Write-Verbose -Message "Merging PR '#$($pr.Number)': $($pr.Title)"
                if ($PSCmdlet.ShouldProcess("PR #$($pr.Number) - $($pr.Title)", "Merge"))
                {
                    try
                    {
                        $mergeArgs = @('pr', 'merge', $pr.Number, '--repo', $repoFullName, '--merge')
                        if ($DeleteBranch.IsPresent)
                        {
                            $mergeArgs += '--delete-branch'
                        }
                        
                        Write-Verbose -Message "Executing: gh $($mergeArgs -join ' ')"
                        & gh @mergeArgs
                        
                        if ($LASTEXITCODE -eq 0)
                        {
                            Write-Information -MessageData "Successfully merged PR '#$($pr.Number)'" -InformationAction Continue
                        }
                        else
                        {
                            Write-Error -Message "Failed to merge PR '#$($pr.Number)'. Exit code: $LASTEXITCODE"
                        }
                    }
                    catch
                    {
                        Write-Error -Message "Error merging PR '#$($pr.Number)': $($_.Exception.Message)"
                    }
                }
            }
            elseif ($pr.MergeStateStatus -eq 'UNSTABLE' -and $pr.IsMergeable)
            {
                Write-Warning -Message "PR '#$($pr.Number)' has unstable status but is mergeable. Consider manual review."
                Write-Verbose -Message "Skipping PR '#$($pr.Number)': $($pr.Title) (MergeStateStatus=$($pr.MergeStateStatus))"
            }
            else
            {
                Write-Verbose -Message "Skipping PR '#$($pr.Number)': $($pr.Title) (MergeStateStatus=$($pr.MergeStateStatus), Mergeable=$($pr.IsMergeable))"
                Write-Information -MessageData "Skipped PR '#$($pr.Number)': $($pr.StatusDescription)" -InformationAction Continue
            }
        }
    }

    end
    {
        Write-Verbose -Message "Ending $($MyInvocation.MyCommand.Name)"
    }
}