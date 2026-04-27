#requires -Version 5.1
<#
    UserAdminModule.psm1 — Root module entry point
    ================================================
    Structure:
        Private/   — internal helpers (Get-UserAdminModuleConfig)
        Public/    — exported base framework functions (5 functions)
        Shell/     — bundled UX submodule, loaded with -Global
        profiles/  — profile scripts for users to dot-source
        resources/ — config data and templates

    Exported functions:
        Import-PersonalModules          — dynamic category importer (tab-completion)
        Invoke-PersonalModulesMenu      — interactive PSMenu multi-select
        New-PSM1Module                  — submodule folder scaffolder
        Invoke-FunctionIndexRegeneration — rebuilds FunctionIndex.json/.md
        Initialize-UserAdminModule      — first-run setup / config writer

    Private helper (module-scoped, NOT exported):
        Get-UserAdminModuleConfig       — reads $env:APPDATA\UserAdminModule\config.json

    Shell submodule is loaded with -Global so its exported functions (Set-PromptisAdmin,
    Show-IsAdminOrNot, Set-ConsoleConfig, etc.) are available directly in the user's
    session after Import-Module UserAdminModule.

    NOTE: Public functions that discover submodules reference $script:UAMModuleRoot
    (set below) instead of $PSScriptRoot, because after moving to Public/ the file's
    $PSScriptRoot would point to the Public/ subdirectory, not the module root.
#>

# ── Module root — set FIRST; used by Public functions for submodule discovery ─
$script:UAMModuleRoot = $PSScriptRoot

# ── Private helpers (must load before Public functions are parsed) ─────────────
$_privateScripts = @( Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue )
foreach ($_script in $_privateScripts) {
    . $_script.FullName
}
Remove-Variable _privateScripts, _script -ErrorAction SilentlyContinue

# ── Public base framework functions ───────────────────────────────────────────
$_publicScripts = @( Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue )
foreach ($_script in $_publicScripts) {
    . $_script.FullName
}
Remove-Variable _publicScripts, _script -ErrorAction SilentlyContinue

# ── Shell submodule (bundled UX layer) ────────────────────────────────────────
# Loaded with -Global so its functions reach the user's session directly.
$_shellModule = Join-Path $PSScriptRoot 'Shell\Shell.psm1'
if (Test-Path $_shellModule) {
    Import-Module $_shellModule -Force -DisableNameChecking -Global -ErrorAction SilentlyContinue
}
else {
    Write-Warning 'UserAdminModule: Shell submodule not found. Prompt helpers will be unavailable.'
}
Remove-Variable _shellModule -ErrorAction SilentlyContinue

# ── Exports ───────────────────────────────────────────────────────────────────
# Get-UserAdminModuleConfig is intentionally NOT exported — private module helper only.
Export-ModuleMember -Function @(
    'Import-PersonalModules'
    'Invoke-PersonalModulesMenu'
    'New-PSM1Module'
    'Invoke-FunctionIndexRegeneration'
    'Initialize-UserAdminModule'
)
