function Get-LanguagePrompt
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Python')]
        [System.String]
        $Language,

        [Parameter(Mandatory = $true)]
        [System.String]
        $PromptName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $CodeSnippet,

        [Parameter()]
        [System.String]
        $PromptFilePath = (Join-Path $PSScriptRoot 'promptString.data.psd1')
    )

    if (-not (Test-Path $PromptFilePath -ErrorAction SilentlyContinue))
    {
        throw "Cannot find file: $PromptFilePath." 
    }

    $promptData = Import-PowerShellDataFile -Path $PromptFilePath

    if ($promptData.ContainsKey($Language))
    {
        $languagePrompts = $promptData[$Language].Prompts
        foreach ($prompt in $languagePrompts)
        {
            if ($prompt.Name -eq $PromptName)
            {
                return ($prompt.Description -f $CodeSnippet)
            }
        }
    }
}