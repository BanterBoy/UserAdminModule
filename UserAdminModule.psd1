#
# UserAdminModule.psd1 — Module manifest
# https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/new-modulemanifest
#
@{
    # ── Identity ──────────────────────────────────────────────────────────────
    RootModule        = 'UserAdminModule.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'c080b18e-78ca-453a-8f6b-6a86c9390267'
    Author            = 'Luke Leigh'
    CompanyName       = 'RDG'
    Copyright         = '(c) 2026 Luke Leigh. All rights reserved.'

    # ── Description ───────────────────────────────────────────────────────────
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

    # ── Requirements ──────────────────────────────────────────────────────────
    PowerShellVersion = '5.1'
    RequiredModules   = @('PSMenu')

    # ── Exports ───────────────────────────────────────────────────────────────
    # Only the base framework functions are exported here.
    # Shell submodule functions are exported by Shell.psm1 via -Global import.
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

    # ── Private data / PSGallery metadata ─────────────────────────────────────
    PrivateData       = @{
        PSData = @{
            Tags         = @(
                'modules', 'functions', 'profile', 'shell', 'admin',
                'scaffold', 'framework', 'productivity', 'tools'
            )
            Prerelease   = 'preview1'
            ProjectUri   = 'https://github.com/BanterBoy/UserAdminModule'
            LicenseUri   = 'https://github.com/BanterBoy/UserAdminModule/blob/main/LICENSE'
            ReleaseNotes = @'
v1.0.0 — Initial PSGallery release.
  - Dynamic category discovery — no hardcoded ValidateSet; works with any user-defined submodule name.
  - Initialize-UserAdminModule — one-command first-run setup that configures custom modules path and optionally updates $PROFILE.
  - Get-UserAdminModuleConfig — private config reader used by all discovery functions.
  - Shell submodule bundled as the built-in UX layer (prompt, greeting, console helpers).
  - Import-PersonalModules refactored — DynamicParam tab-completion built from discovered folders; trap-based error handling.
  - Invoke-PersonalModulesMenu refactored — discovers all categories at runtime; graceful PSMenu soft-warning.
  - Invoke-FunctionIndexRegeneration — hardcoded paths replaced with PSScriptRoot-relative defaults.
'@
        }
    }
}
