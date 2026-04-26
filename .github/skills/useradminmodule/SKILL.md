---
name: useradminmodule
description: >
  Specialist skill for developing and maintaining the UserAdminModule PowerShell framework.
  USE FOR: creating or refactoring Public/ or Shell/Public/ functions, adding new framework
  capabilities, understanding module architecture, regenerating the function index, validating
  syntax, auditing coding standards compliance, and generating documentation.
  DO NOT USE FOR: general PowerShell questions unrelated to this module, creating change
  requests, or managing other repositories.
---

# UserAdminModule Skill

## Purpose

Provide structured workflows for developing, maintaining, and navigating the **UserAdminModule** framework — a PSGallery-published PowerShell module that gives administrators a dynamic, folder-based system for managing their own function libraries.

## When This Skill Applies

Activate when the user:

- Asks to **create or modify a function** in `Public/` or `Shell/Public/`
- Wants to **find an existing function** or understand what's available
- Needs to **add a Shell UX function** to the bundled Shell submodule
- Asks to **refactor or move functions** within the module
- Wants to **regenerate the function index** (JSON/Markdown)
- Asks to **validate syntax** across the module
- Needs to **audit coding standards** compliance
- Mentions any Public function by name, or Shell functions like `Set-PromptisAdmin`, `New-Greeting`, `Open-ModuleMenuApp`

---

## Module Architecture

```
UserAdminModule/                          ← repo root
├── UserAdminModule.psd1                  ← PSGallery manifest (v1.0.0)
├── UserAdminModule.psm1                  ← Root module — sets $script:UAMModuleRoot,
│                                            loads Private/, Public/, Shell/
├── Public/                               ← 5 exported framework functions
│   ├── Import-PersonalModules.ps1        ← Dynamic category importer (DynamicParam)
│   ├── Initialize-UserAdminModule.ps1    ← First-run config writer
│   ├── Invoke-FunctionIndexRegeneration.ps1 ← Index rebuilder
│   ├── Invoke-PersonalModulesMenu.ps1    ← PSMenu interactive loader
│   └── New-PSM1Module.ps1               ← Submodule scaffolder
├── Private/                              ← Internal helpers (NOT exported)
│   └── Get-UserAdminModuleConfig.ps1     ← Reads $env:APPDATA\UserAdminModule\config.json
├── Shell/                                ← Bundled UX submodule (loaded -Global)
│   ├── Shell.psm1
│   └── Public/                           ← 16 Shell UX functions
│       ├── Set-PromptisAdmin.ps1
│       ├── Show-IsAdminOrNot.ps1
│       ├── New-Greeting.ps1
│       ├── Set-ConsoleConfig.ps1
│       ├── Get-ConsoleConfig.ps1
│       ├── Open-ModuleMenuApp.ps1        ← alias: omma
│       ├── Restart-Profile.ps1
│       ├── Install-ModuleIfNotPresent.ps1
│       ├── Install-RequiredModules.ps1
│       ├── Invoke-UserAdminModuleRequiredModules.ps1
│       ├── Get-LocationStack.ps1
│       ├── Set-Home.ps1
│       ├── Restore-Location.ps1
│       ├── Initialize-Module.ps1
│       ├── Set-DisplayIsAdmin.ps1
│       └── IsAdmin.ps1                   ← contains Test-IsAdmin
├── profiles/                             ← Reference profiles for users
│   ├── SharedPowershellProfile.ps1       ← PS 7+ full UX profile
│   ├── SharedWindowsPowershellProfile.ps1 ← PS 5.1 full UX profile
│   └── Microsoft.PowerShell_profile.ps1  ← Minimal reference profile
├── resources/                            ← Data and generator scripts
│   ├── New-ModuleMenuApp.ps1             ← Generates ModuleMenuApp.html
│   └── ModuleMenuApp.html               ← Auto-generated — do not edit
├── FunctionIndex.json                    ← Auto-generated index
├── FunctionIndex.md                      ← Auto-generated index
├── build/
│   └── Publish-ToGallery.ps1
└── .github/
    ├── copilot-instructions.md
    ├── AGENTS.md
    ├── CLAUDE.md
    └── skills/
```

### Key Runtime Variables

| Variable | Set By | Value | Purpose |
|---|---|---|---|
| `$script:UAMModuleRoot` | `UserAdminModule.psm1` | Module root folder path | Public functions use this for submodule discovery |
| `$env:APPDATA\UserAdminModule\config.json` | `Initialize-UserAdminModule` | `{"CustomModulesPath":"...", "ConfigVersion":"1.0"}` | Runtime config — user's custom submodule path |

### Loading Mechanism

1. `Import-Module UserAdminModule` triggers `UserAdminModule.psm1`
2. psm1 sets `$script:UAMModuleRoot = $PSScriptRoot`
3. psm1 dot-sources `Private/*.ps1` then `Public/*.ps1`
4. psm1 imports `Shell/Shell.psm1` with `-Global`
5. Shell functions (`Set-PromptisAdmin`, `Show-IsAdminOrNot`, etc.) available immediately in user session
6. `Import-PersonalModules -Category <Tab>` discovers user submodules at call time via `Get-UserAdminModuleConfig`

---

## Workflow 1 — Create or Modify a Public/ Framework Function

### When to Use

User asks to change how the module loads, discovers submodules, manages config, or scaffolds new modules.

### Constraints for Public/ Functions

- MUST reference `$Script:UAMModuleRoot` (not `$PSScriptRoot`) for any path that needs the module root
- MUST call `Get-UserAdminModuleConfig` to read config — never read the JSON directly
- MUST support PS 5.1 and 7+
- MUST be added to `FunctionsToExport` in `UserAdminModule.psd1` if new

### Standard Template

```powershell
#requires -Version 5.1
function Verb-Noun {
    <#
    .SYNOPSIS
        One-line summary.
    .DESCRIPTION
        Full description.
        Reference: https://learn.microsoft.com/...
    .PARAMETER Name
        Description.
    .EXAMPLE
        Verb-Noun -Name 'value'
        What this does.
    .NOTES
        Author:    Luke Leigh
        Tested on: PowerShell 5.1 and 7+
    .LINK
        Related-Function
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    begin {
        trap {
            Write-Error "Failed to initialise Verb-Noun: $_"
            break
        }
        $_uamRoot = if ($Script:UAMModuleRoot) { $Script:UAMModuleRoot } else { Split-Path $PSScriptRoot -Parent }
    }

    process {
        trap {
            Write-Error "Failed to process $($Name): $_"
            continue
        }
        Write-Verbose "Processing $($Name)"
        # logic here
    }
}
```

---

## Workflow 2 — Create or Modify a Shell/Public/ Function

### When to Use

User asks to change a Shell UX function (prompt, console, greeting, module app, etc.)

### Extra Constraints for Shell/Public/

- **NO `#Requires -PSEdition Core`** — Shell.psm1 dot-sources the whole folder in one pass. A Core-only `#Requires` kills the entire load loop in PS 5.1, making all subsequent Shell functions unavailable.
- **NO `IValidateSetValuesGenerator`** — PS 6.0+ only. Use hardcoded `[ValidateSet('Value1','Value2')]` instead.
- **NO `??=` operator** — PS 7+ only.
- `$PSScriptRoot` in Shell/Public/ files resolves to `Shell/Public/` — use `Split-Path $PSScriptRoot -Parent` for the Shell root, or `Split-Path -Parent (Split-Path -Parent $PSScriptRoot)` for the module root.
- Shell.psm1 uses try/catch — this is legacy. Do NOT replicate it in new files.

### Path Resolution in Shell/Public/

```powershell
# Shell root (Shell/)
$shellRoot = Split-Path $PSScriptRoot -Parent

# Module root (UserAdminModule/)
$moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# Resources (Shell/Resources/)
$resourceDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'Resources'

# Module resources (UserAdminModule/resources/)
$moduleResourceDir = Join-Path $moduleRoot 'resources'
```

---

## Workflow 3 — Find Existing Functions

```powershell
# Search the index by name
$index = Get-Content 'FunctionIndex.json' | ConvertFrom-Json
$index | ForEach-Object { $_.Functions } | Where-Object { $_.Name -like '*Greeting*' }

# Search by description keyword
$index | ForEach-Object { $_.Functions } | Where-Object { $_.Description -match 'config' }

# List all Shell functions
Get-ChildItem 'Shell\Public\*.ps1' | Select-Object -ExpandProperty BaseName

# List all Public framework functions
Get-ChildItem 'Public\*.ps1' | Select-Object -ExpandProperty BaseName
```

---

## Workflow 4 — Regenerate the Function Index

Run after any function is added, renamed, or removed.

```powershell
Import-Module .\UserAdminModule.psd1 -Force -DisableNameChecking
Invoke-FunctionIndexRegeneration -Verbose
```

With no arguments, `Invoke-FunctionIndexRegeneration` auto-discovers:
1. The module root (Shell submodule — 16 functions)
2. The `CustomModulesPath` from config (user's AdminFunctions — 30+ submodules)

Outputs: `FunctionIndex.json` and `FunctionIndex.md` at the module root.

---

## Workflow 5 — Validate Syntax

```powershell
# Check all Shell/Public files for parse errors
Get-ChildItem 'Shell\Public\*.ps1' | ForEach-Object {
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
    if ($errors) { [PSCustomObject]@{ File = $_.Name; Errors = $errors } }
}

# Check all Public framework files
Get-ChildItem 'Public\*.ps1' | ForEach-Object {
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
    if ($errors) { [PSCustomObject]@{ File = $_.Name; Errors = $errors } }
}
```

---

## Workflow 6 — Validate Module Manifest

```powershell
Test-ModuleManifest -Path .\UserAdminModule.psd1
```

Expected: 5 exported functions — `Import-PersonalModules`, `Initialize-UserAdminModule`,
`Invoke-FunctionIndexRegeneration`, `Invoke-PersonalModulesMenu`, `New-PSM1Module`.

---

## Mandatory Coding Standards Checklist

Before saving any function, verify ALL of these:

- [ ] **Approved verb** — function name uses an approved PowerShell verb (`Get-Verb` to check)
- [ ] **`[CmdletBinding()]`** — present on every function
- [ ] **Parameter validation** — `[ValidateNotNullOrEmpty()]`, `[ValidateSet()]`, `[ValidateRange()]` where appropriate
- [ ] **Error handling uses `trap` ONLY** — absolutely NO `try/catch` blocks
- [ ] **String interpolation** — variables before `:` or `.` wrapped in `$()`: `"Error: $($var): $_"` not `"Error: $var: $_"`
- [ ] **Comment-based help** — SYNOPSIS, DESCRIPTION, PARAMETER, EXAMPLE, NOTES all present
- [ ] **`Write-Verbose`** — used for diagnostic output, NOT `Write-Host`
- [ ] **PS 5.1 compatible** — no `#Requires -PSEdition Core`, no `IValidateSetValuesGenerator`, no `??=`
- [ ] **Shell/Public only** — no `#Requires -PSEdition Core` at top of file

---

## Defaults Reference

| Field | Value |
|---|---|
| Module Name | `UserAdminModule` |
| Author | Luke Leigh |
| PowerShell Version | 5.1+ (test on both 5.1 and 7+) |
| Public functions | 5 (framework) |
| Shell UX functions | 16 |
| Config location | `$env:APPDATA\UserAdminModule\config.json` |
| PSGallery URL | `https://www.powershellgallery.com/packages/UserAdminModule` |
| GitHub | `https://github.com/BanterBoy/UserAdminModule` |
