#requires -Version 5.1
function Initialize-UserAdminModule {
    <#
    .SYNOPSIS
        One-time setup that configures UserAdminModule for a new administrator.

    .DESCRIPTION
        Sets up the UserAdminModule framework for first use by:
          - Storing the custom submodules path in $env:APPDATA\UserAdminModule\config.json
          - Creating the custom path directory if it does not already exist
          - Optionally writing 'Import-Module UserAdminModule' to $PROFILE

        Once configured, Import-PersonalModules and Invoke-PersonalModulesMenu will
        automatically discover any submodules you create under the configured path.
        Use New-PSM1Module to scaffold your first submodule.

        Reference: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/import-module

    .PARAMETER Path
        The folder where your custom submodule folders will be stored.
        Example: C:\MyModules

    .PARAMETER UpdateProfile
        If specified, appends 'Import-Module UserAdminModule' to the current user's
        PowerShell profile ($PROFILE). A .bak backup of the existing profile is
        created before any change is made.

    .EXAMPLE
        Initialize-UserAdminModule -Path 'C:\MyModules'

        Configures the custom modules path. Submodules created here are auto-discovered
        by Import-PersonalModules and Invoke-PersonalModulesMenu.

    .EXAMPLE
        Initialize-UserAdminModule -Path 'C:\MyModules' -UpdateProfile

        Configures the custom path and adds the Import-Module line to $PROFILE so
        UserAdminModule loads automatically in every new session.

    .EXAMPLE
        Initialize-UserAdminModule -Path 'C:\MyModules' -WhatIf

        Shows what would happen without making any changes.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Properties: CustomModulesPath, ConfigPath, ProfileUpdated

    .NOTES
        Author:    Luke Leigh
        Config:    $env:APPDATA\UserAdminModule\config.json
        Tested on: PowerShell 5.1 and 7+

        Reference: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/import-module

    .LINK
        Get-UserAdminModuleConfig
        Import-PersonalModules
        New-PSM1Module
        Invoke-PersonalModulesMenu
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0, HelpMessage = 'Path to store your custom submodule folders.')]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [switch]$UpdateProfile
    )

    begin {
        trap {
            Write-Error "Failed to initialise UserAdminModule: $_"
            break
        }

        $configDir  = Join-Path $env:APPDATA 'UserAdminModule'
        $configPath = Join-Path $configDir 'config.json'
    }

    process {
        trap {
            Write-Error "Failed during UserAdminModule initialisation: $_"
            continue
        }

        # 1 — Resolve and create the custom modules directory
        $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)

        if (-not (Test-Path $resolvedPath)) {
            if ($PSCmdlet.ShouldProcess($resolvedPath, 'Create custom modules directory')) {
                New-Item -Path $resolvedPath -ItemType Directory -Force | Out-Null
                Write-Verbose "Created custom modules directory: $($resolvedPath)"
            }
        }
        else {
            Write-Verbose "Custom modules directory already exists: $($resolvedPath)"
        }

        # 2 — Create config directory and write config
        if (-not (Test-Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        }

        $config = [PSCustomObject]@{
            CustomModulesPath = $resolvedPath
            ConfigVersion     = '1.0'
        }

        if ($PSCmdlet.ShouldProcess($configPath, 'Write UserAdminModule config')) {
            $config | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8 -Force
            Write-Verbose "Config written to: $($configPath)"
        }

        # 3 — Optionally update $PROFILE
        $profileUpdated = $false

        if ($UpdateProfile) {
            $importLine  = 'Import-Module UserAdminModule -ErrorAction SilentlyContinue'
            $profilePath = $PROFILE

            if (-not (Test-Path $profilePath)) {
                if ($PSCmdlet.ShouldProcess($profilePath, 'Create PowerShell profile file')) {
                    New-Item -Path $profilePath -ItemType File -Force | Out-Null
                }
            }

            $existingContent = Get-Content -Path $profilePath -Raw -ErrorAction SilentlyContinue

            if ($existingContent -notmatch 'Import-Module UserAdminModule') {
                if ($PSCmdlet.ShouldProcess($profilePath, 'Add Import-Module line to profile')) {
                    $backupPath = "$profilePath.bak"
                    if (Test-Path $profilePath) {
                        Copy-Item -Path $profilePath -Destination $backupPath -Force
                        Write-Verbose "Profile backup created at: $($backupPath)"
                    }
                    Add-Content -Path $profilePath -Value "`n$importLine" -Encoding UTF8
                    Write-Verbose "Added Import-Module line to: $($profilePath)"
                    $profileUpdated = $true
                }
            }
            else {
                Write-Verbose 'Profile already contains Import-Module UserAdminModule — no change made.'
                $profileUpdated = $true
            }
        }

        # 4 — Return result object
        [PSCustomObject]@{
            CustomModulesPath = $resolvedPath
            ConfigPath        = $configPath
            ProfileUpdated    = $profileUpdated
        }
    }

    end {
        trap {
            Write-Error "Failed in Initialize-UserAdminModule end block: $_"
            continue
        }

        Write-Information "UserAdminModule configured. Custom modules path: $($resolvedPath)" -InformationAction Continue
        Write-Information "Next: use New-PSM1Module -folderPath '$($resolvedPath)\MyCategory' to scaffold your first submodule." -InformationAction Continue
        Write-Verbose 'Initialize-UserAdminModule completed.'
    }
}
