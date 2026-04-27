#requires -Version 5.1
<#
.SYNOPSIS
    Imports PowerShell submodules by category name, with dynamic tab-completion.

.DESCRIPTION
    Discovers available categories at runtime by scanning the UserAdminModule installation
    directory for built-in submodules and any configured custom modules path for
    user-created submodules. A folder qualifies as a submodule if it contains a .psm1
    file whose name matches the folder name.

    Tab-completion for -Category is built dynamically from what actually exists — no
    configuration is needed when new submodules are added. Configure a custom modules
    path first with Initialize-UserAdminModule.

    Reference: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/import-module

.PARAMETER Category
    One or more category names to import. Tab-completes dynamically from all discovered
    submodules (both built-in and custom). Accepts multiple values.

.EXAMPLE
    Import-PersonalModules -Category Shell

    Imports the built-in Shell submodule.

.EXAMPLE
    Import-PersonalModules -Category ADFunctions, Exchange

    Imports multiple built-in categories in one call.

.EXAMPLE
    Import-PersonalModules -Category MyScripts -Verbose

    Imports a user-created custom category with verbose timing output.

.EXAMPLE
    Import-PersonalModules -Category HomeLabTools -WhatIf

    Shows what would be imported without making any changes.

.NOTES
    Author:    Luke Leigh
    Tested on: PowerShell 5.1 and 7+

    Reference: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/import-module

.LINK
    Initialize-UserAdminModule
    Invoke-PersonalModulesMenu
    New-PSM1Module
    Get-UserAdminModuleConfig

#>

function Import-PersonalModules {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    DynamicParam {
        # --- Discover built-in submodules from the module root ---
        # Use $script:UAMModuleRoot (set by UserAdminModule.psm1) rather than $PSScriptRoot,
        # because this file lives in Public/ and $PSScriptRoot would point to Public/, not the module root.
        $_uamRoot = if ($Script:UAMModuleRoot) { $Script:UAMModuleRoot } else { Split-Path $PSScriptRoot -Parent }
        $discovered = [System.Collections.Generic.List[string]]::new()

        if (Test-Path $_uamRoot) {
            Get-ChildItem -Path $_uamRoot -Directory -ErrorAction SilentlyContinue |
                Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name).psm1") } |
                ForEach-Object { $discovered.Add($_.Name) }
        }

        # --- Discover custom submodules from config ---
        $cfg = if (Get-Command Get-UserAdminModuleConfig -ErrorAction SilentlyContinue) {
            Get-UserAdminModuleConfig -ErrorAction SilentlyContinue
        }
        if ($cfg -and $cfg.CustomModulesPath -and (Test-Path $cfg.CustomModulesPath)) {
            Get-ChildItem -Path $cfg.CustomModulesPath -Directory -ErrorAction SilentlyContinue |
                Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name).psm1") } |
                ForEach-Object {
                    if (-not $discovered.Contains($_.Name)) { $discovered.Add($_.Name) }
                }
        }

        $allCategories = ($discovered | Sort-Object)

        # --- Build dynamic -Category parameter ---
        $attrCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

        $paramAttr                = New-Object System.Management.Automation.ParameterAttribute
        $paramAttr.Mandatory      = $true
        $paramAttr.HelpMessage    = 'Category name to import. Tab-completes from all discovered submodules.'
        $attrCollection.Add($paramAttr)

        if ($allCategories.Count -gt 0) {
            $validateSet = New-Object System.Management.Automation.ValidateSetAttribute(
                [string[]]$allCategories
            )
            $attrCollection.Add($validateSet)
        }

        $dynParam = New-Object System.Management.Automation.RuntimeDefinedParameter(
            'Category', [string[]], $attrCollection
        )

        $paramDict = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $paramDict.Add('Category', $dynParam)
        return $paramDict
    }

    begin {
        trap {
            Write-Error "Failed to initialise Import-PersonalModules: $_"
            break
        }

        $Category = $PSBoundParameters['Category']

        # --- Build category -> psm1 path map ---
        $moduleMap = @{}

        # Built-in submodules (discovered from module root)
        $_uamRoot = if ($Script:UAMModuleRoot) { $Script:UAMModuleRoot } else { Split-Path $PSScriptRoot -Parent }
        if (Test-Path $_uamRoot) {
            Get-ChildItem -Path $_uamRoot -Directory -ErrorAction SilentlyContinue |
                Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name).psm1") } |
                ForEach-Object { $moduleMap[$_.Name] = Join-Path $_.FullName "$($_.Name).psm1" }
        }

        # Custom
        $cfg = if (Get-Command Get-UserAdminModuleConfig -ErrorAction SilentlyContinue) {
            Get-UserAdminModuleConfig -ErrorAction SilentlyContinue
        }
        if ($cfg -and $cfg.CustomModulesPath -and (Test-Path $cfg.CustomModulesPath)) {
            Get-ChildItem -Path $cfg.CustomModulesPath -Directory -ErrorAction SilentlyContinue |
                Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name).psm1") } |
                ForEach-Object {
                    if (-not $moduleMap.ContainsKey($_.Name)) {
                        $moduleMap[$_.Name] = Join-Path $_.FullName "$($_.Name).psm1"
                    }
                }
        }

        $timingResults = @()
    }

    process {
        trap {
            Write-Error "Failed to import category: $_"
            continue
        }

        foreach ($cat in $Category) {
            if (-not $moduleMap.ContainsKey($cat)) {
                Write-Warning "Category '$($cat)' was not found on disk. Run Initialize-UserAdminModule to configure a custom modules path, or use New-PSM1Module to scaffold a new submodule."
                continue
            }

            $modulePath = $moduleMap[$cat]

            if ($PSCmdlet.ShouldProcess($modulePath, 'Import-Module')) {
                $start = Get-Date
                Write-Verbose "Importing '$($cat)' from: $($modulePath)"
                Import-Module -Name $modulePath -Force -DisableNameChecking -Global
                $duration      = (Get-Date) - $start
                $timingResults += [PSCustomObject]@{
                    Category = $cat
                    Path     = $modulePath
                    Duration = "$([math]::Round($duration.TotalSeconds, 2))s"
                }
                Write-Verbose "Imported '$($cat)' in $([math]::Round($duration.TotalSeconds, 2))s"
            }
        }
    }

    end {
        trap {
            Write-Error "Failed in Import-PersonalModules end block: $_"
            continue
        }

        if ($PSBoundParameters.ContainsKey('Verbose') -and $timingResults.Count -gt 0) {
            $timingResults | Format-Table -AutoSize
        }

        Write-Verbose 'Import-PersonalModules completed.'
    }
}
