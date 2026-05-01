@{
    RootModule        = 'UserAdminModule.psm1'
    ModuleVersion     = '1.0.9'
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
v1.0.9 — Fix New-Shell executable resolution for -RunAs and -TerminalRunAs
  - Root cause: Start-Process -Verb RunAs (ShellExecute) requires a fully-qualified
    path or an App Paths registry entry; pwsh.exe is not always registered there,
    causing "system cannot find all the information required" errors when elevating
  - Fix: added Test-Executable helper in New-Shell that resolves shell executables
    via Get-Command before launch, guaranteeing an absolute path is passed to
    Start-Process regardless of App Paths registration
  - Affects: -RunAs (PowerShellRunAs, pwshRunAs) and -TerminalRunAs parameter sets
v1.0.8 — Fix Getting Started modal in ModuleMenuApp
  - New-ModuleMenuApp.ps1 setup guide previously showed steps to clone RDGScripts
    instead of the correct PSGallery install steps for UserAdminModule
  - Fix: steps now correctly show Install-Module UserAdminModule,
    Initialize-UserAdminModule -Path, Import-Module in $PROFILE,
    and Import-PersonalModules -Category
v1.0.7 — Fix submodule scope (Import-PersonalModules -Global)
  - Root cause of all "Import-PersonalModules imports nothing" reports: Import-Module
    was called without -Global, so submodules were loaded into UserAdminModule's private
    scope instead of the session scope — Get-Command -Module Weather returned nothing
  - Fix: added -Global to Import-Module in Import-PersonalModules
  - Removed -ErrorAction SilentlyContinue so errors from #requires failures (e.g.
    ADFunctions needing ActiveDirectory RSAT) surface through the trap handler instead
    of being silently swallowed
  - This fix supersedes the incorrectly documented v1.0.3/v1.0.4 entries below —
    -Global was described in those release notes but was never actually committed
v1.0.6 — Fix -UseSharedProfile profile write (root cause: Add-Content silent failure)
  - Root cause of v1.0.5 bug: (Get-Module UserAdminModule).ModuleBase returned an
    array when two module instances were loaded, producing a concatenated path string
  - Root cause of profile write failure: Add-Content silently swallowed errors then
    set ProfileUpdated=True regardless — profile was empty after the run
  - Fix 1: resolve shared profile path via $Script:UAMModuleRoot (set in psm1 at
    load time — always a single string, immune to multi-instance loading)
  - Fix 2: store resolved path in config.json as SharedProfilePath
  - Fix 3: profile block reads config.json at session startup (no PSModulePath needed)
  - Fix 4: replaced Add-Content with [System.IO.File]::WriteAllText + explicit
    read-back verification. If verification fails, backup is restored and a Warning
    is emitted instead of silently returning ProfileUpdated=True
  - Tested end-to-end in a real admin session — profile correctly written and verified
v1.0.5 — Add -UseSharedProfile to Initialize-UserAdminModule
  - New -UseSharedProfile switch: when combined with -UpdateProfile, writes a
    dot-source line for the bundled shared profile instead of a bare Import-Module
    line. Auto-detects $PSEdition: Desktop (PS 5.1) → SharedWindowsPowershellProfile.ps1;
    Core (PS 7+) → SharedPowershellProfile.ps1
  - Duplicate-detection now covers both the Import-Module pattern and the
    SharedPowershellProfile/SharedWindowsPowershellProfile dot-source pattern so
    re-running the command is idempotent
  - End block nudge: informs users who used -UpdateProfile alone about -UseSharedProfile
  - docs/getting-started.md: new 'Profile options' section explaining Option A vs B
  - docs/reference.md: -UseSharedProfile added to Initialize-UserAdminModule table
  - README.md: quick-start updated with Option A / Option B examples
v1.0.4 — Fix submodule import and command detection (PSGallery regression, re-release)
  - 1.0.3 published with incomplete fixes; this supersedes it
  - Get-ImportedModuleCommand: rewrote submodule detection using dynamic directory
    scan (same logic as Import-PersonalModules). Eliminates the broken
    path-comparison approach that caused Normalize-Path and Test-IsUAMSubmodule
    to leak into Shell exports and Shell/UserAdminModule to appear as submodules
  - Get-ImportedModuleCommand: replaced Get-Help synopsis lookup with AST-based
    help extraction to avoid terminating type-resolution errors on functions that
    use typed AD parameters ([ADComputer] etc.) when AD module is not loaded
  - Get-ImportedModuleCommand: deduplicate results when same module is loaded from
    multiple paths (e.g. PSGallery and local dev copy both in session)
v1.0.3 — Fix submodule command detection (PSGallery regression)
  - Get-ImportedModuleCommand: rewrote submodule detection using dynamic directory scan
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