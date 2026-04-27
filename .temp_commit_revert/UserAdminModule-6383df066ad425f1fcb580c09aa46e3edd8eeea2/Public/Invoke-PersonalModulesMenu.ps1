#requires -Version 5.1
function Invoke-PersonalModulesMenu {
    <#
    .SYNOPSIS
        Interactive menu to import PowerShell submodule categories using PSMenu.

    .DESCRIPTION
        Displays an interactive multi-select menu of all discovered submodule categories —
        both built-in (Shell, ADFunctions, etc.) and any user-created custom categories.
        Categories are discovered dynamically at runtime; no reconfiguration is needed
        when new submodules are added under the configured custom modules path.

        Use arrow keys to navigate, Space to select/deselect, and Enter to confirm.

        Requires the PSMenu module. If PSMenu is not installed the function exits with
        a clear warning and the install command.

        Reference: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/import-module

    .PARAMETER ShowDescriptions
        If specified, appends a short description to each category name in the menu.

    .EXAMPLE
        Invoke-PersonalModulesMenu

        Shows the interactive menu with category names only.

    .EXAMPLE
        Invoke-PersonalModulesMenu -ShowDescriptions

        Shows the menu with descriptions appended to each category name.

    .NOTES
        Author:    Luke Leigh
        Requires:  PSMenu (Install-Module PSMenu)
        Tested on: PowerShell 5.1 and 7+

        Reference: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/import-module

    .LINK
        Import-PersonalModules
        Initialize-UserAdminModule
        New-PSM1Module
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$ShowDescriptions
    )

    trap { Write-Error "Invoke-PersonalModulesMenu failed: $_"; break }

    # PSMenu is a soft dependency — warn gracefully rather than breaking on load
    if (-not (Get-Module -ListAvailable -Name PSMenu)) {
        Write-Warning 'PSMenu module is required for the interactive menu. Install it with: Install-Module PSMenu'
        return
    }

    Import-Module PSMenu -Force -ErrorAction SilentlyContinue

    # Known descriptions for built-in categories (user categories get a generic label)
    $knownDescriptions = @{
        'ADFunctions'             = 'Active Directory — user lifecycle, groups, auditing, diagnostics.'
        'Azure'                   = 'Azure and Entra ID — resource provisioning, identity governance.'
        'CertificateUtilities'    = 'PKI utilities — certificate operations, validation, enrollment.'
        'CiscoSecure'             = 'VPN and Cisco Secure endpoint management.'
        'CustomRDGCommands'       = 'Custom RDG-specific computer and group management commands.'
        'Database'                = 'SQL Server operations — queries, backups, configuration.'
        'EnvironmentManagement'   = 'Environment variables, path operations, system configuration.'
        'Exchange'                = 'Exchange and M365 — mailboxes, calendars, distribution lists.'
        'FileOperations'          = 'File and directory manipulation, copying, moving.'
        'JekyllBlog'              = 'Jekyll static site generation and blog management.'
        'Logging'                 = 'Event logging, audit trails, monitoring.'
        'MediaManagement'         = 'Audio and video file processing and format conversion.'
        'Network'                 = 'IP, DNS, connectivity testing, network configuration.'
        'PKICertificateTools'     = 'Advanced PKI — ADCS integration, certificate lifecycle.'
        'PrintManagement'         = 'Print spooler and printer queue management.'
        'ProcessServiceSchedules' = 'Windows services, scheduled tasks, startup configuration.'
        'RDGAdmin'                = 'RDG admin orchestration — Exchange Online, Azure, Teams, Intune.'
        'Registry'                = 'Windows registry access and key management.'
        'RemoteConnections'       = 'RDP, PSRemoting, distributed system connectivity.'
        'Replication'             = 'Active Directory replication monitoring and diagnostics.'
        'Reporting'               = 'Reporting and audit exports — CSV, HTML, JSON outputs.'
        'Security'                = 'Security configuration, compliance, access control.'
        'Shell'                   = 'PowerShell environment utilities, module management, profile helpers.'
        'ShutdownCommands'        = 'System shutdown, restart, and power management.'
        'Teams'                   = 'Microsoft Teams management and integration.'
        'Testing'                 = 'Test utilities, validation functions, diagnostic tools.'
        'TimeTools'               = 'Time synchronisation, NTP, time zone management.'
        'Utilities'               = 'General-purpose utility functions.'
        'Virtualization'          = 'Hyper-V and virtual machine management.'
        'Weather'                 = 'Weather data retrieval utilities.'
    }

    # --- Discover categories dynamically ---
    $discovered = [System.Collections.Generic.List[string]]::new()

    # Built-in submodules (discovered from module root)
    # Use $script:UAMModuleRoot rather than $PSScriptRoot; this file is in Public/ so
    # $PSScriptRoot would point to Public/, not the module root where submodules live.
    $_uamRoot = if ($Script:UAMModuleRoot) { $Script:UAMModuleRoot } else { Split-Path $PSScriptRoot -Parent }
    if (Test-Path $_uamRoot) {
        Get-ChildItem -Path $_uamRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name).psm1") } |
            ForEach-Object { $discovered.Add($_.Name) }
    }

    # Custom submodules from config
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

    $categories = $discovered | Sort-Object

    if ($categories.Count -eq 0) {
        Write-Warning 'No submodule categories were discovered. Run Initialize-UserAdminModule to configure a custom modules path, then use New-PSM1Module to scaffold your first submodule.'
        return
    }

    $menuItems = if ($ShowDescriptions) {
        $categories | ForEach-Object {
            $desc = if ($knownDescriptions.ContainsKey($_)) { $knownDescriptions[$_] } else { 'Custom submodule' }
            "$_ — $desc"
        }
    }
    else {
        $categories
    }

    Write-Host ''
    Write-Host '  UserAdminModule — Category Import Menu' -ForegroundColor Cyan
    Write-Host '  Space to select/deselect  |  Enter to confirm  |  Ctrl+C to cancel' -ForegroundColor DarkGray
    Write-Host ''

    [int[]]$selectedIndexes = Show-Menu -MenuItems $menuItems -MultiSelect -ReturnIndex -ItemFocusColor 'Cyan'

    if ($null -eq $selectedIndexes -or $selectedIndexes.Count -eq 0) {
        Write-Host '  No categories selected.' -ForegroundColor Yellow
        return
    }

    [string[]]$selectedCats = $selectedIndexes | ForEach-Object { $categories[$_] }

    Write-Host ''
    Write-Host '  Selected:' -ForegroundColor Green
    $selectedCats | ForEach-Object { Write-Host "    + $_" -ForegroundColor Green }
    Write-Host ''

    $confirm = Read-Host '  Proceed with import? [Y/n]'
    if ($confirm -eq '' -or $confirm -like 'y*') {
        Write-Host ''
        Import-PersonalModules -Category $selectedCats
        Write-Host '  Import complete.' -ForegroundColor Green
        Write-Host ''
    }
    else {
        Write-Host '  Cancelled.' -ForegroundColor Yellow
    }

    Write-Verbose 'Invoke-PersonalModulesMenu completed.'
}
