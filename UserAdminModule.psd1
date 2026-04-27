@{
    RootModule        = 'UserAdminModule.psm1'
    ModuleVersion     = '1.0.4'
    GUID              = 'c080b18e-78ca-453a-8f6b-6a86c9390267'
    Author            = 'Luke Leigh'
    CompanyName       = 'Banter Studio'
    Copyright         = '(c) 2026 Luke Leigh. All rights reserved.'

    Description       = @'
A PowerShell function management framework that gives any administrator a superpower
in their own shell.

Scaffold submodules, manage categories interactively, and maintain a living function
index — without the pain of dot-sourcing loose scripts or maintaining individual
module manifests for every function you write.

Quick start:
  1. Install-Module UserAdminModule
  2. Initialize-UserAdminModule -Path 'C:\MyModules' -UpdateProfile
  3. New-PSM1Module -folderPath 'C:\MyModules\MyCategory'
  4. Drop .ps1 files into MyCategory\Public\ and Import-PersonalModules -Category MyCategory
'@

    PowerShellVersion = '5.1'
    RequiredModules   = @('PSMenu')

    FunctionsToExport = @(
        'Import-PersonalModules'
        'Invoke-PersonalModulesMenu'
        'New-PSM1Module'
        'Invoke-FunctionIndexRegeneration'
        'Initialize-UserAdminModule'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags = @(
                'UserAdminModule', 'AdminTools', 'FunctionLibrary', 'Productivity', 'CustomModules', 'ScriptManagement'
                )
            ProjectUri   = 'https://useradminmodule.lukeleigh.com/'
            LicenseUri   = 'https://github.com/BanterBoy/UserAdminModule/blob/main/LICENSE'
            ReleaseNotes = @'
v1.0.4 — Fix submodule import and command detection (PSGallery regression, re-release)
  - 1.0.3 published with incomplete fixes; this supersedes it
  - Import-PersonalModules: added -Global to Import-Module so imported submodules
    are visible in the user session, not scoped internally to the module
  - Get-ImportedModuleCommand: rewrote submodule detection using dynamic directory
    scan (same logic as Import-PersonalModules). Eliminates the broken
    path-comparison approach that caused Normalize-Path and Test-IsUAMSubmodule
    to leak into Shell exports and Shell/UserAdminModule to appear as submodules
  - Get-ImportedModuleCommand: replaced Get-Help synopsis lookup with AST-based
    help extraction to avoid terminating type-resolution errors on functions that
    use typed AD parameters ([ADComputer] etc.) when AD module is not loaded
  - Get-ImportedModuleCommand: deduplicate results when same module is loaded from
    multiple paths (e.g. PSGallery and local dev copy both in session)
v1.0.3 — Fix submodule import and command detection (PSGallery regression)
  - Import-PersonalModules: added -Global to Import-Module so imported submodules
    are visible in the user session, not scoped internally to the module
  - Get-ImportedModuleCommand: rewrote submodule detection using dynamic directory
    scan (same logic as Import-PersonalModules). Eliminates the broken
    path-comparison approach that caused Normalize-Path and Test-IsUAMSubmodule
    to leak into Shell exports and Shell/UserAdminModule to appear as submodules
  - Get-ImportedModuleCommand: replaced Get-Help synopsis lookup with AST-based
    help extraction to avoid terminating type-resolution errors on functions that
    use typed AD parameters ([ADComputer] etc.) when AD module is not loaded
  - Get-ImportedModuleCommand: deduplicate results when same module is loaded from
    multiple paths (e.g. PSGallery and local dev copy both in session)
v1.0.2 — Minor fixes and improvements
  - New-PSM1Module: added -Force parameter to overwrite existing module folders
  - New-PSM1Module: improved error handling for invalid folder paths
  - Initialize-UserAdminModule: added check to prevent duplicate profile entries
  - Updated documentation for new parameters and edge cases
  - All changes validated for PS 5.1/7+ compatibility and repo conventions
v1.0.1 — Stable release (all recent changes)
  - All Shell/Public/ functions now use [CmdletBinding()], trap, and full help
  - Set-DisplayIsAdmin.ps1 deleted (duplicate)
  - IsAdmin.ps1 renamed to Test-IsAdmin.ps1; Set-TitleisAdmin.ps1 extracted
  - Show-IsAdminOrNot.ps1 logic bug fixed (now always correct)
  - Shell.psm1: legacy try/catch exemption comment added
  - resources/New-ModuleMenuApp.ps1: .DESCRIPTION clarified (internal use)
  - docs/reference.md: expanded menu/browser documentation, screenshots added
  - docs/getting-functions.md: new page for building your function library
  - All changes validated for PS 5.1/7+ compatibility and repo conventions
'@
        }
    }
}