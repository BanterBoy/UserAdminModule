@{
    RootModule        = 'UserAdminModule.psm1'
    ModuleVersion     = '1.0.1'
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
                'PowerShellGallery', 'UserAdminModule', 'AdminTools', 'FunctionLibrary', 'Profile', 'Prompt', 'Menu',
                'ModuleScaffold', 'Documentation', 'HTMLReference', 'ActiveDirectory', 'Exchange', 'Azure', 'Intune',
                'Security', 'PKI', 'Reporting', 'Automation', 'Productivity', 'Shell', 'Framework', 'CustomModules',
                'Category', 'Submodule', 'Import', 'Scaffold', 'Interactive', 'PSMenu', 'Config', 'Index', 'Reference',
                'Docs', 'Windows', 'CrossPlatform', 'PowerShell', 'Module', 'Functions', 'ProfileScript', 'Startup',
                'Bootstrap', 'Discovery', 'TabCompletion', 'DynamicParam', 'UX', 'HTML', 'Web', 'MenuApp', 'Gallery'
            )
            ProjectUri   = 'https://useradminmodule.lukeleigh.com/'
            LicenseUri   = 'https://github.com/BanterBoy/UserAdminModule/blob/main/LICENSE'
            ReleaseNotes = @'
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