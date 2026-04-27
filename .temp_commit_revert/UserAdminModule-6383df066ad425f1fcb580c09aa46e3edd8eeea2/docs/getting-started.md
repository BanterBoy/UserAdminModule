---
layout: default
title: Getting Started
nav_order: 2
description: "Install and configure UserAdminModule in five minutes."
---

# Getting Started
{: .no_toc }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Prerequisites

- PowerShell 5.1 or PowerShell 7+
- An internet connection (first install only)
- A folder that contains, or will contain, your PowerShell function categories

---

## Install from PSGallery

```powershell
Install-Module UserAdminModule -AllowPrerelease -Scope CurrentUser
```

{: .note }
> `PSMenu` is a required dependency. PowerShellGet installs it automatically alongside UserAdminModule.

---

## First-time setup

Run `Initialize-UserAdminModule` once, pointing it at the root of your function library. Pass `-UpdateProfile` to have it add the import line to your `$PROFILE` automatically.

```powershell
Initialize-UserAdminModule -Path 'C:\MyModules' -UpdateProfile
```

This writes a `config.json` to `$env:APPDATA\UserAdminModule\` so every UserAdminModule command knows where to find your functions. You only need to run this once per machine.

{: .tip }
> If you already have functions in a folder like `C:\Scripts\AdminFunctions`, point `-Path` there. No restructuring needed yet — see [Bring Your Own Functions]({{ site.baseurl }}/your-functions) for how to make existing libraries compatible.

---

## Scaffold your first category

`New-PSM1Module` creates the full folder structure for a new category, including the `.psm1` file that auto-dot-sources everything in `Public\`:

```powershell
New-PSM1Module -folderPath 'C:\MyModules\ADFunctions'
```

This produces:

```
C:\MyModules\ADFunctions\
├── ADFunctions.psm1
├── Public\
├── Private\
├── Classes\
├── Configuration\
└── Resources\
```

Drop your function `.ps1` files into `Public\`. They are imported automatically when you load the category.

---

## Import a category

```powershell
# Tab-complete the category name — discovered at runtime
Import-PersonalModules -Category ADFunctions
```

All functions in `ADFunctions\Public\` are now available in your session. Run `Get-Command -Module ADFunctions` to see them.

---

## Use the interactive menu

If you have multiple categories and want to choose which ones to import:

```powershell
# Arrow keys to navigate, Space to select, Enter to import
Invoke-PersonalModulesMenu
```

---

## Browse your functions

```powershell
# Opens the HTML function reference in your default browser
Open-ModuleMenuApp
```

The browser is built from `FunctionIndex.json`. Use `-Regenerate` to rebuild it after adding or removing functions:

```powershell
# Rebuilds the function index AND the HTML browser, then opens it
Open-ModuleMenuApp -Regenerate
```

{: .tip }
> `-Regenerate` handles everything automatically — it runs `Invoke-FunctionIndexRegeneration` if needed, then regenerates the HTML browser. You do not need to run any intermediate commands.

---

## Next steps

- [Bring Your Own Functions]({{ site.baseurl }}/your-functions) — organise an existing function library
- [Framework Reference]({{ site.baseurl }}/reference) — all commands, parameters, and examples
