#requires -Version 5.1
function Get-UserAdminModuleConfig {
    <#
    .SYNOPSIS
        Reads the UserAdminModule configuration from the user's AppData folder.

    .DESCRIPTION
        Returns the stored configuration object for UserAdminModule, which includes the
        custom modules path recorded by Initialize-UserAdminModule. If no config file
        exists a default object is returned with an empty CustomModulesPath so callers
        never need to handle a null return.

        Config file location: $env:APPDATA\UserAdminModule\config.json

        Reference: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-content

    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Properties:
          CustomModulesPath [string] — path to the user's custom submodule folder.
          ConfigVersion     [string] — config schema version.

    .EXAMPLE
        Get-UserAdminModuleConfig

        Returns the stored config, or a default config if none exists.

    .EXAMPLE
        (Get-UserAdminModuleConfig).CustomModulesPath

        Returns the configured custom modules path string.

    .NOTES
        Author:    Luke Leigh
        Config:    $env:APPDATA\UserAdminModule\config.json
        Tested on: PowerShell 5.1 and 7+

        This is a private helper consumed by Import-PersonalModules,
        Invoke-PersonalModulesMenu, and Invoke-FunctionIndexRegeneration.

        Reference: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-content

    .LINK
        Initialize-UserAdminModule
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    begin {
        trap {
            Write-Error "Failed to read UserAdminModule config: $_"
            break
        }

        $configPath = Join-Path $env:APPDATA 'UserAdminModule\config.json'
    }

    process {
        trap {
            Write-Error "Failed to process UserAdminModule config: $_"
            continue
        }

        if (Test-Path $configPath) {
            Write-Verbose "Reading config from $($configPath)"
            $raw    = Get-Content -Path $configPath -Raw -Encoding UTF8
            $config = $raw | ConvertFrom-Json
            return $config
        }
        else {
            Write-Verbose "No config found at $($configPath). Returning defaults."
            return [PSCustomObject]@{
                CustomModulesPath = ''
                ConfigVersion     = '1.0'
            }
        }
    }

    end {
        Write-Verbose 'Get-UserAdminModuleConfig completed.'
    }
}
