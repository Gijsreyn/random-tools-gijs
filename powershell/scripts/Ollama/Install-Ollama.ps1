function Install-Ollama
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Serve
    )

    process
    {
        if ($IsLinux)
        {
            Write-Verbose -Message 'Installing Ollama on Linux.'
            Invoke-Expression 'curl -fsSL https://ollama.com/install.sh | sh'
        }
        elseif ($IsWindows)
        {
            Write-Verbose -Message 'Installing Ollama on Windows.'
            $winGetPath = (Get-Command WinGet -ErrorAction SilentlyContinue).Path
            if (-not (Test-Path $winGetPath -ErrorAction SilentlyContinue))
            {
                Write-Verbose -Message "WinGet not found, checking if it can be installed using 'Microsoft.WinGet.Client' module."

                Install-Module -Name 'Microsoft.WinGet.Client' -Force -Scope CurrentUser -Repository PSGallery

                try
                {
                    Repair-WinGetPackageManager -Force
                    $wingetPath = (Get-Command winget -ErrorAction SilentlyContinue).Path
                }
                catch
                {
                    Throw 'Failed to repair/install WinGet package manager.'
                }
            }

            $params = @{
                Id     = 'Ollama.Ollamas'
                Source = 'winget'
            }
            $package = Get-WinGetPackage @params

            # TODO: Check for upgrade.
            if (-not $package)
            {
                Write-Verbose -Message 'Installing Ollama using WinGet with.'
                Write-Verbose -Message ($params | ConvertTo-Json | Out-String)
                Install-WinGetPackage @params -Force
            }
        }
        else
        {
            return 'Unsupported operating system.'
        }

        if ($Serve.IsPresent)
        {
            & ollama serve
        }
    }
}
