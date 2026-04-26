---
layout: default
title: Framework Reference
nav_order: 4
description: "Complete command reference for all UserAdminModule framework and Shell UX functions."
---

# Framework Reference
{: .no_toc }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Framework Functions

These five functions are exported by UserAdminModule and available in your session after `Import-Module UserAdminModule`.

---

### Import-PersonalModules

Imports a category of personal PowerShell functions into the current session. The `-Category` parameter is dynamically tab-completed from available submodule folders discovered at runtime — no hardcoded list, no `ValidateSet` to maintain.

```powershell
Import-PersonalModules -Category <CategoryName> [-Verbose]
```

| Parameter | Type | Description |
|---|---|---|
| `-Category` | String (dynamic) | Name of the category folder to import. Tab-completes from discovered folders in both the module root and `CustomModulesPath`. |

**Examples:**

```powershell
# Import all AD functions
Import-PersonalModules -Category ADFunctions

# Import Exchange functions with verbose output
Import-PersonalModules -Category Exchange -Verbose
```

---

### Initialize-UserAdminModule

One-time setup command. Writes `config.json` to `$env:APPDATA\UserAdminModule\` and optionally adds `Import-Module UserAdminModule` to your `$PROFILE`.

```powershell
Initialize-UserAdminModule -Path <string> [-UpdateProfile] [-Verbose]
```

| Parameter | Type | Description |
|---|---|---|
| `-Path` | String | Path to your custom modules root folder. Created automatically if it does not exist. |
| `-UpdateProfile` | Switch | Appends `Import-Module UserAdminModule` to the current `$PROFILE` if the line is not already present. |

**Example:**

```powershell
Initialize-UserAdminModule -Path 'C:\MyModules\AdminFunctions' -UpdateProfile
```

---

### Invoke-PersonalModulesMenu

Launches an interactive PSMenu interface for selecting and importing categories. Navigate with arrow keys, Space to select, Enter to confirm. All available categories are discovered at runtime.

```powershell
Invoke-PersonalModulesMenu [-Verbose]
```

No positional parameters. Accepts common parameters (`-Verbose`, `-Debug`).

---

### Invoke-FunctionIndexRegeneration

Scans all discovered category folders, extracts comment-based help from each `.ps1` file in `Public\`, and regenerates `FunctionIndex.json` and `FunctionIndex.md` in the module root.

```powershell
Invoke-FunctionIndexRegeneration [-Verbose]
```

Run this after adding or removing functions to keep the HTML browser and Markdown index current.

{: .important }
> `FunctionIndex.json` and `FunctionIndex.md` are auto-generated. Do not edit them manually — changes will be overwritten on the next regeneration.

---

### New-PSM1Module

Scaffolds a new category folder with the full UserAdminModule-compatible structure: a `.psm1` file that auto-dot-sources `Public\`, plus `Public\`, `Private\`, `Classes\`, `Configuration\`, and `Resources\` subfolders.

```powershell
New-PSM1Module -folderPath <string> [-Verbose]
```

| Parameter | Type | Description |
|---|---|---|
| `-folderPath` | String | Full path for the new module folder. The `.psm1` filename is derived from the folder name. |

**Example:**

```powershell
New-PSM1Module -folderPath 'C:\MyModules\ADFunctions'
```

---

## Shell UX Functions

These functions are loaded into the **global** scope when `Import-Module UserAdminModule` runs. They provide prompt, console, and session UX helpers — available immediately without importing any category.

| Function | Description |
|---|---|
| `Set-PromptisAdmin` | Sets the PowerShell prompt to display elevation status |
| `Show-IsAdminOrNot` | Displays whether the current session is running as administrator |
| `Set-DisplayIsAdmin` | Configures an admin indicator in the window title |
| `New-Greeting` | Displays a time-of-day greeting with system info on profile load |
| `Open-ModuleMenuApp` | Opens the HTML function browser in the default browser |
| `Get-ConsoleConfig` | Returns current console font, size, and colour configuration |
| `Set-ConsoleConfig` | Applies console font, size, and colour settings |
| `Set-Home` | Sets the working directory to the user's home folder |
| `Get-LocationStack` | Returns the current directory navigation stack |
| `Restore-Location` | Pops the location stack to return to a previous directory |
| `Restart-Profile` | Re-executes `$PROFILE` without starting a new shell process |
| `Install-RequiredModules` | Checks and installs module dependencies |
| `Install-ModuleIfNotPresent` | Installs a module only if it is not already available |
| `Invoke-UserAdminModuleRequiredModules` | Bootstraps all UserAdminModule dependencies |
| `Initialize-Module` | Internal module initialisation helper |
| `IsAdmin` | Returns `$true` if the current session is running as administrator |

---

## Configuration

UserAdminModule stores its configuration at:

```
$env:APPDATA\UserAdminModule\config.json
```

The configuration file is created by `Initialize-UserAdminModule`. Its primary key is `CustomModulesPath`, which tells all discovery functions where to scan for your category folders.

{: .warning }
> Do not edit `config.json` directly. Re-run `Initialize-UserAdminModule -Path <newpath>` to change the configured path.

---

## PS 5.1 and 7+ Compatibility

All framework and Shell UX functions target both Windows PowerShell 5.1 and PowerShell 7+. No `#Requires -PSEdition Core` restrictions apply — UserAdminModule works in the shell you already use.
