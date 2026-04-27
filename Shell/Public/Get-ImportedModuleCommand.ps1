#requires -Version 5.1

function Get-ImportedModuleCommand {
    <#
    .SYNOPSIS
        Lists all commands from UserAdminModule submodules imported via Import-PersonalModules.

    .DESCRIPTION
        Retrieves the exported commands from UserAdminModule submodules that are currently
        loaded in the session. By default lists commands from all loaded submodules, but can
        be filtered by submodule name, command verb, or command noun. Useful for discovering
        which functions are available after running Import-PersonalModules.

        Unlike Get-LoadedFunctions (which shows sourceless functions), this function shows
        commands grouped by their source module, making it easy to see what each submodule
        provides.

        Reference: https://learn.microsoft.com/powershell/module/microsoft.powershell.core/get-command

    .PARAMETER Submodule
        Filters output to commands from a specific submodule (e.g. ADFunctions, Shell).
        Supports wildcards.

    .PARAMETER Verb
        Filters commands by verb (e.g. Get, Set, New). Supports wildcards.

    .PARAMETER Noun
        Filters commands by noun (e.g. ADUser, SpeedTest). Supports wildcards.

    .PARAMETER Wide
        Displays output in a compact wide format instead of the default table.

    .PARAMETER Summary
        Shows a summary count of commands per submodule instead of listing individual commands.

    .EXAMPLE
        Get-ImportedModuleCommand

        Lists all commands from every loaded UserAdminModule submodule.

    .EXAMPLE
        Get-ImportedModuleCommand -Submodule ADFunctions

        Lists only the commands exported by the ADFunctions submodule.

    .EXAMPLE
        Get-ImportedModuleCommand -Verb Get -Noun '*AD*'

        Lists all Get- commands with AD in the noun across all loaded submodules.

    .EXAMPLE
        Get-ImportedModuleCommand -Summary

        Shows a count of how many commands each loaded submodule exports.

    .EXAMPLE
        Get-ImportedModuleCommand -Wide

        Displays all loaded submodule commands in a compact wide format.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

        Objects with Submodule, Name, Synopsis, Verb, Noun, and CommandType properties.

    .NOTES
        Author:     Luke Leigh
        Requires:   Import-PersonalModules to have been run first
        Tested on:  PowerShell 5.1 and 7+

        Reference: https://learn.microsoft.com/powershell/module/microsoft.powershell.core/get-command

    .LINK
        Import-PersonalModules

    .LINK
        Get-LoadedFunctions
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string]$Submodule = '*',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string]$Verb = '*',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string]$Noun = '*',

        [Parameter(ParameterSetName = 'Wide')]
        [switch]$Wide,

        [Parameter(ParameterSetName = 'Summary')]
        [switch]$Summary
    )

    begin {
        trap {
            Write-Error "Failed to initialise Get-ImportedModuleCommand: $_"
            break
        }

        Write-Verbose 'Retrieving loaded UserAdminModule submodules'

        # Discover UserAdminModule root.
        # $Script:UAMModuleRoot is set by UserAdminModule.psm1 but lives in that module's
        # scope — not visible here in Shell's scope. Use (Get-Module UserAdminModule).ModuleBase
        # as the authoritative source; fall back to two levels up from $PSScriptRoot
        # (Shell\Public -> Shell -> module root) only if the module is not loaded.
        $_uamRoot = (Get-Module UserAdminModule -ErrorAction SilentlyContinue |
            Select-Object -First 1).ModuleBase
        if (-not $_uamRoot) {
            Write-Verbose 'UserAdminModule module not loaded in session — falling back to PSScriptRoot parent chain.'
            $_uamRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        }
        Write-Verbose "UAMModuleRoot: $_uamRoot"

        # Read CustomModulesPath directly from config.json.
        # Get-UserAdminModuleConfig is private to UserAdminModule's module scope and is
        # not reachable from Shell — read the JSON directly here.
        $customPath = $null
        $configPath = Join-Path $env:APPDATA 'UserAdminModule\config.json'
        if (Test-Path $configPath) {
            trap { Write-Verbose "Could not read config.json: $_"; continue }
            $cfgRaw = Get-Content $configPath -Raw -ErrorAction SilentlyContinue
            if ($cfgRaw) {
                $cfgObj = $cfgRaw | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($cfgObj -and $cfgObj.CustomModulesPath -and (Test-Path $cfgObj.CustomModulesPath)) {
                    $customPath = $cfgObj.CustomModulesPath
                }
            }
        }

        function Normalize-Path([string]$path) {
            if (-not $path) { return $null }
            return ([System.IO.Path]::GetFullPath($path.TrimEnd('\/'))).TrimEnd('\/')
        }
        $_uamRoot = Normalize-Path $_uamRoot
        $customPath = Normalize-Path $customPath

        Write-Verbose "CustomModulesPath: $($customPath ?? '(none)')"

        function Test-IsUAMSubmodule($mod) {
            if (-not $mod.ModuleBase -or -not $mod.Name) { return $false }
            $psm1 = Join-Path $mod.ModuleBase ("$($mod.Name).psm1")
            $modBase = Normalize-Path $mod.ModuleBase
            $hasPsm1 = Test-Path $psm1
            # Must be a child directory of UAMRoot or CustomPath — not the root itself
            $inUAMRoot = ($null -ne $_uamRoot -and
                $modBase.StartsWith($_uamRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
                $modBase -ne $_uamRoot)
            $inCustomPath = ($null -ne $customPath -and $modBase.StartsWith($customPath, [System.StringComparison]::OrdinalIgnoreCase))
            if (-not $hasPsm1) { return $false }
            return ($inUAMRoot -or $inCustomPath)
        }

        $loadedModules = Get-Module |
            Where-Object {
                # Wrap in () so -and is a boolean operator, not an argument to Test-IsUAMSubmodule
                (Test-IsUAMSubmodule $_) -and ($_.Name -like $Submodule)
            }
    }

    process {
        trap {
            Write-Error "Failed to process Get-ImportedModuleCommand: $_"
            continue
        }


        if (-not $loadedModules) {
            Write-Warning "No UserAdminModule submodules matching '$Submodule' are currently loaded. Run Import-PersonalModules first."
            return
        }

        Write-Verbose "Found $($loadedModules.Count) loaded submodule(s)"

        $commands = foreach ($mod in $loadedModules) {
            Write-Verbose "Scanning submodule: $($mod.Name)"

            $modCommands = Get-Command -Module $mod.Name -ErrorAction SilentlyContinue |
                Where-Object {
                    ($_.Verb -like $Verb -or $_.Name -like "$Verb-*") -and
                    ($_.Noun -like $Noun -or $_.Name -like "*-$Noun")
                }

            foreach ($cmd in $modCommands) {
                $synopsis = (Get-Help -Name $cmd.Name -ErrorAction SilentlyContinue).Synopsis
                if ($synopsis) { $synopsis = $synopsis.Trim() }

                [PSCustomObject]@{
                    Submodule   = $mod.Name
                    Name        = $cmd.Name
                    Synopsis    = $synopsis
                    Verb        = $cmd.Verb
                    Noun        = $cmd.Noun
                    CommandType = $cmd.CommandType
                }
            }
        }

        if (-not $commands) {
            Write-Warning 'No commands found matching the specified filters.'
            return
        }

        if ($Summary) {
            $commands |
                Group-Object -Property Submodule |
                Sort-Object -Property Count -Descending |
                Select-Object @{N = 'Submodule'; E = { $_.Name } }, Count
        }
        elseif ($Wide) {
            $commands |
                Sort-Object -Property Submodule, Name |
                Format-Wide -Property Name -AutoSize
        }
        else {
            $commands | Sort-Object -Property Submodule, Name
        }
    }

    end {
        Write-Verbose 'Completed Get-ImportedModuleCommand'
    }
}

Set-Alias -Name gimc -Value Get-ImportedModuleCommand
