
#requires -Version 5.1
function Invoke-UserAdminModuleRequiredModules {
    <#
    .SYNOPSIS
        Installs, updates, or removes required PowerShell modules for UserAdminModule submodules.
    .DESCRIPTION
        Ensures all required modules for UserAdminModule submodules are installed, updated, or removed as specified. Supports:
        - Installing missing modules
        - Updating existing modules to minimum required versions
        - Removing specified modules
        The required modules list is maintained in the function for now, but can be externalized later.
        Reference: https://learn.microsoft.com/en-us/powershell/module/powershellget/install-module
    .PARAMETER Action
        The action to perform: Install, Update, Remove. Default is Install.
    .PARAMETER Scope
        Installation scope: CurrentUser or AllUsers. Default is CurrentUser.
    .PARAMETER Force
        Forces reinstallation or removal even if already present or in use.
    .PARAMETER SkipPublisherCheck
        Skips the publisher signature check during installation.
    .PARAMETER ModuleName
        One or more module names to target. If omitted, all required modules are processed.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    .EXAMPLE
        Invoke-UserAdminModuleRequiredModules -Action Install
    .EXAMPLE
        Invoke-UserAdminModuleRequiredModules -Action Update -Scope AllUsers -Force
    .EXAMPLE
        Invoke-UserAdminModuleRequiredModules -Action Remove -Force
    .NOTES
        Author: Copilot (2026)
        Reference: https://learn.microsoft.com/en-us/powershell/module/powershellget/install-module
    .LINK
        Install-Module
        Uninstall-Module
        Get-Module
    #>
    [CmdletBinding()]
    [Alias('iumrm')]
    param(
        [Parameter(Position=0)]
        [ValidateSet('Install','Update','Remove')]
        [string]$Action = 'Install',
        [Parameter(Position=1)]
        [ValidateSet('CurrentUser','AllUsers')]
        [string]$Scope = 'CurrentUser',
        [Parameter()]
        [switch]$Force,
        [Parameter()]
        [switch]$SkipPublisherCheck
    )

    dynamicparam {
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $false
        $ParameterAttribute.HelpMessage = 'Specify one or more module names to target. If omitted, all required modules are processed.'

        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $AttributeCollection.Add($ParameterAttribute)

        $RequiredModulesList = @(
            @{ Name = 'Az'; MinimumVersion = '10.0.0' }
            @{ Name = 'Microsoft.Graph'; MinimumVersion = '2.0.0' }
            @{ Name = 'ExchangeOnlineManagement'; MinimumVersion = '3.0.0' }
            @{ Name = 'MicrosoftTeams'; MinimumVersion = '5.0.0' }
            @{ Name = 'ConnectExchangeOnPrem'; MinimumVersion = '1.0.0' }
            @{ Name = 'ActiveDirectory'; MinimumVersion = '1.0.0.0' }
            @{ Name = 'PSReadline'; MinimumVersion = '2.2.6' }
            @{ Name = 'PSMenu' }
            @{ Name = 'PoshLog' }
            @{ Name = 'GroupPolicy' }
            @{ Name = 'ADCSAdministration' }
            @{ Name = 'PSPKI' }
            @{ Name = 'VMware.PowerCLI' }
            @{ Name = 'VMware.VimAutomation.Core' }
            @{ Name = 'AsBuiltReport.Microsoft.AD' }
            @{ Name = 'AsBuiltReport.Microsoft.Windows' }
            @{ Name = 'AsBuiltReport.Microsoft.Azure' }
            @{ Name = 'AsBuiltReport.Microsoft.DHCP' }
            @{ Name = 'AsBuiltReport.Microsoft.SCVMM' }
            @{ Name = 'AsBuiltReport.VMware.ESXi' }
            @{ Name = 'AsBuiltReport.VMware.Horizon' }
            @{ Name = 'AsBuiltReport.VMware.SRM' }
            @{ Name = 'AsBuiltReport.VMware.UAG' }
            @{ Name = 'AsBuiltReport.VMware.AppVolumes' }
            @{ Name = 'AsBuiltReport.VMware.vSphere' }
            @{ Name = 'AsBuiltReport.Veeam.VBR' }
            @{ Name = 'AsBuiltReport.Veeam.VB365' }
            @{ Name = 'AsBuiltReport.NetApp.ONTAP' }
            @{ Name = 'GoogleDynamicDNSTools' }
            @{ Name = 'IconExport' }
            @{ Name = 'Microsoft.PowerShell.Archive' }
            @{ Name = 'Pester' }
        )
        $moduleNames = $RequiredModulesList | ForEach-Object { $_.Name }
        $ValidateSet = New-Object System.Management.Automation.ValidateSetAttribute($moduleNames)
        $AttributeCollection.Add($ValidateSet)
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter('ModuleName', [string[]], $AttributeCollection)
        $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $paramDictionary.Add('ModuleName', $RuntimeParameter)
        return $paramDictionary
    }

    begin {
        trap {
            Write-Error "Failed to $($Action) UserAdminModule required modules: $_"
            break
        }
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()
        # Use the same RequiredModulesList as in dynamicparam
        $script:RequiredModulesList = @(
            @{ Name = 'Az'; MinimumVersion = '10.0.0' }
            @{ Name = 'Microsoft.Graph'; MinimumVersion = '2.0.0' }
            @{ Name = 'Microsoft.Entra'; MinimumVersion = '1.0.0' }
            @{ Name = 'ExchangeOnlineManagement'; MinimumVersion = '3.0.0' }
            @{ Name = 'MicrosoftTeams'; MinimumVersion = '5.0.0' }
            @{ Name = 'ConnectExchangeOnPrem'; MinimumVersion = '1.0.0' }
            @{ Name = 'ActiveDirectory'; MinimumVersion = '1.0.0.0' }
            @{ Name = 'PSReadline'; MinimumVersion = '2.2.6' }
            @{ Name = 'PSMenu' }
            @{ Name = 'PoshLog' }
            @{ Name = 'GroupPolicy' }
            @{ Name = 'ADCSAdministration' }
            @{ Name = 'PSPKI' }
            @{ Name = 'VMware.PowerCLI' }
            @{ Name = 'VMware.VimAutomation.Core' }
            @{ Name = 'AsBuiltReport.Microsoft.AD' }
            @{ Name = 'AsBuiltReport.Microsoft.Windows' }
            @{ Name = 'AsBuiltReport.Microsoft.Azure' }
            @{ Name = 'AsBuiltReport.Microsoft.DHCP' }
            @{ Name = 'AsBuiltReport.Microsoft.SCVMM' }
            @{ Name = 'AsBuiltReport.VMware.ESXi' }
            @{ Name = 'AsBuiltReport.VMware.Horizon' }
            @{ Name = 'AsBuiltReport.VMware.SRM' }
            @{ Name = 'AsBuiltReport.VMware.UAG' }
            @{ Name = 'AsBuiltReport.VMware.AppVolumes' }
            @{ Name = 'AsBuiltReport.VMware.vSphere' }
            @{ Name = 'AsBuiltReport.Veeam.VBR' }
            @{ Name = 'AsBuiltReport.Veeam.VB365' }
            @{ Name = 'AsBuiltReport.NetApp.ONTAP' }
            @{ Name = 'GoogleDynamicDNSTools' }
            @{ Name = 'IconExport' }
            @{ Name = 'Microsoft.PowerShell.Archive' }
            @{ Name = 'Pester' }
        )
    }

    process {
        trap {
            Write-Error "Failed to process $($Action) UserAdminModule required modules: $_"
            continue
        }
        $targetModules = if ($PSBoundParameters.ContainsKey('ModuleName') -and $PSBoundParameters['ModuleName']) {
            $script:RequiredModulesList | Where-Object { $_.Name -in $PSBoundParameters['ModuleName'] }
        } else {
            $script:RequiredModulesList
        }

        foreach ($module in $targetModules) {
            $name = $module.Name
            $minVersion = $module.MinimumVersion
            $installedModule = Get-Module -ListAvailable -Name $name | Sort-Object Version -Descending | Select-Object -First 1

            switch ($Action) {
                'Install' {
                    if ($installedModule -and $minVersion -and ($installedModule.Version -ge [version]$minVersion) -and -not $Force) {
                        $results.Add([PSCustomObject]@{
                            ModuleName = $name
                            Status     = 'AlreadyInstalled'
                            Version    = $installedModule.Version.ToString()
                            Message    = "Module already installed and meets minimum version requirement"
                        })
                        continue
                    }
                    $installParams = @{
                        Name           = $name
                        Scope          = $Scope
                        AllowClobber   = $true
                        ErrorAction    = 'Stop'
                    }
                    if ($minVersion) { $installParams.MinimumVersion = $minVersion }
                    if ($Force) { $installParams.Force = $true }
                    if ($SkipPublisherCheck) { $installParams.SkipPublisherCheck = $true }
                    Write-Verbose "Installing/Updating module $name..."
                    Install-Module @installParams
                    $installed = Get-Module -ListAvailable -Name $name | Sort-Object Version -Descending | Select-Object -First 1
                    if ($installed) {
                        $results.Add([PSCustomObject]@{
                            ModuleName = $name
                            Status     = 'Installed'
                            Version    = $installed.Version.ToString()
                            Message    = 'Module installed/updated successfully'
                        })
                    } else {
                        $results.Add([PSCustomObject]@{
                            ModuleName = $name
                            Status     = 'Failed'
                            Version    = $null
                            Message    = 'Module installation completed but module not found afterward'
                        })
                    }
                }
                'Update' {
                    if (($installedModule -and $minVersion -and ($installedModule.Version -lt [version]$minVersion)) -or $Force) {
                        $updateParams = @{
                            Name           = $name
                            Scope          = $Scope
                            AllowClobber   = $true
                            ErrorAction    = 'Stop'
                        }
                        if ($minVersion) { $updateParams.MinimumVersion = $minVersion }
                        if ($Force) { $updateParams.Force = $true }
                        if ($SkipPublisherCheck) { $updateParams.SkipPublisherCheck = $true }
                        Write-Verbose "Updating module $name..."
                        Install-Module @updateParams
                        $updated = Get-Module -ListAvailable -Name $name | Sort-Object Version -Descending | Select-Object -First 1
                        if ($updated) {
                            $results.Add([PSCustomObject]@{
                                ModuleName = $name
                                Status     = 'Updated'
                                Version    = $updated.Version.ToString()
                                Message    = 'Module updated successfully'
                            })
                        } else {
                            $results.Add([PSCustomObject]@{
                                ModuleName = $name
                                Status     = 'Failed'
                                Version    = $null
                                Message    = 'Module update completed but module not found afterward'
                            })
                        }
                    } else {
                        $results.Add([PSCustomObject]@{
                            ModuleName = $name
                            Status     = 'AlreadyUpToDate'
                            Version    = $installedModule.Version.ToString()
                            Message    = 'Module already at or above minimum version'
                        })
                    }
                }
                'Remove' {
                    if ($installedModule) {
                        Write-Verbose "Removing module $name..."
                        $removeParams = @{
                            Name        = $name
                            Force       = $true
                            ErrorAction = 'Stop'
                            AllVersions = $true
                        }
                        Uninstall-Module @removeParams
                        $results.Add([PSCustomObject]@{
                            ModuleName = $name
                            Status     = 'Removed'
                            Version    = $installedModule.Version.ToString()
                            Message    = 'Module removed successfully'
                        })
                    } else {
                        $results.Add([PSCustomObject]@{
                            ModuleName = $name
                            Status     = 'NotInstalled'
                            Version    = $null
                            Message    = 'Module not installed, nothing to remove'
                        })
                    }
                }
            }
        }
    }
    end {
        Write-Verbose 'Completed Invoke-UserAdminModuleRequiredModules.'
        return $results
    }
}
