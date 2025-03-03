function Test-LanguageByFileType
{
    param (
        [Parameter(Mandatory = $true)]
        [System.String]
        $FileExtension,

        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $LanguageData
    )

    $LanguageData.GetEnumerator() | ForEach-Object {
        if ($_.Value -in $FileExtension)
        {
            return $true
        }
    }

    return $false
}

function Get-FileChangesByPullRequestId 
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Id,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $CheckPushCommitDate
    )

    begin
    {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)

        #$BasePath = Split-Path $PSScriptRoot -Parent
        $BasePath = Split-Path $PSScriptRoot -Parent

        # The input object
        $inputObject = @{}
    }

    process
    {
        $pullRequest = Get-VSTeamPullRequest -Id $Id

        if ($pullRequest)
        {
            # Get the last changes URL by merge commit url and store the date
            $res = Invoke-VSTeamRequest -Url $pullRequest.lastMergeCommit.url

            $changesUrl = $res._links.changes.href
            $pushDate = $pullRequest.lastMergeCommit.author.date

            if ($changesUrl)
            {
                # Get the files changes
                $res = Invoke-VSTeamRequest -Url $changesUrl

                foreach ($change in $res.changes) 
                {
                    Write-Verbose -Message ("The following '{0}' file has been changed during this pull request. Checking if it is a file..." -f $change.item.path)
                    $fullPath = Join-Path $BasePath -ChildPath $change.item.path

                    if (Test-Path -Path $FullPath -PathType Leaf)
                    {
                        Write-Verbose -Message ('Captured the following file for potential review: {0}' -f $fullPath)
                        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($fullPath)

                        $object = @{
                            $FileName = @{
                                TargetFile = $fullPath
                            }
     
                        }
                        $inputObject += $object
                    }
                }
            }
        }

        if ($CheckPushCommitDate)
        {
            if ($pushDate -ge $pullRequest.creationDate)
            {
                Write-Verbose -Message 'The push date is after the pull request creation date. Returning empty object.'
                $inputObject = @{}
            }
        }

        return $inputObject
    }

    end
    {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}

function Get-LanguageFileByFileType 
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [AllowNull()]
        [System.Collections.Hashtable[]]
        $FileObject,

        [Parameter()]
        [System.String]
        $LanguageDataFilePath = (Join-Path $PSScriptRoot 'supportedLanguage.psd1')
    )

    begin
    {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)

        $languageDictionary = Import-PowerShellDataFile -Path $LanguageDataFilePath

        # The input object
        $inputObject = @{}
    }

    process
    {
        foreach ($file in $FileObject.Values)
        {
            if ($file.ContainsKey('TargetFile')) 
            {
                Write-Verbose -Message ("Checking file extension to determine if file needs review: '{0}'" -f $file.TargetFile)

                $fileExtension = [System.IO.Path]::GetExtension($file.TargetFile)

                if (Test-LanguageByFileType -FileExtension $fileExtension -LanguageData $languageDictionary)
                {
                    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($file.TargetFile)

                    $object = @{
                        $fileName = @{
                            TargetFile = $file.TargetFile
                        }
                    }
                    
                    $inputObject += $object
                }
            }

        }

        return $inputObject
    }

    end
    {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}