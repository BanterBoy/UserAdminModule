---
layout: default
title: Home
nav_order: 1
description: "Stop dot-sourcing. A PowerShell module framework that makes managing administrator functions simple, discoverable, and shareable."
permalink: /
---

# UserAdminModule
{: .fs-9 }

Stop dot-sourcing. Start managing.
{: .fs-5 .fw-300 }

Every administrator eventually hits the same wall: hundreds of functions scattered across scripts, dot-sourced in a `$PROFILE` that nobody wants to touch, impossible to share or deploy to a new machine.

UserAdminModule solves this — without rewriting your functions or changing how you work.

[Get Started]({{ site.baseurl }}/getting-started){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-2 }
[View on GitHub](https://github.com/BanterBoy/UserAdminModule){: .btn .fs-5 .mb-4 .mb-md-0 }

---

## Install in seconds

```powershell
Install-Module UserAdminModule -AllowPrerelease
Initialize-UserAdminModule -Path 'C:\MyModules' -UpdateProfile
```

One command to install. One command to set up. Your `$PROFILE` stays clean.

---

## The Problem

You have been writing PowerShell functions for years. They work. The problem is what happens to them after you write them.

**The old way:**

```powershell
# $PROFILE — 47 lines of dot-sourcing nobody dares touch
. C:\Scripts\AD\Get-ADUserSearch.ps1
. C:\Scripts\AD\Get-LockedOutAccounts.ps1
. C:\Scripts\AD\Reset-ADUserPassword.ps1
. C:\Scripts\Exchange\Connect-O365Exchange.ps1
. C:\Scripts\Exchange\Get-MailboxPermissions.ps1
. C:\Scripts\Exchange\Get-DistributionListMembers.ps1
# ... 41 more lines ...
```

Every new workstation means updating paths. Sharing a tool with a colleague means zipping a folder and explaining the setup over Teams. There is no tab completion, no discovery, no index of what you have written.

**This is not a workflow. It is technical debt with a `.ps1` extension.**

---

## The Solution

UserAdminModule gives your functions a home. Organise them into category folders — one folder per domain, one `.psm1` per folder. The module discovers them automatically.

```powershell
# Import every AD function — tab-complete the category name
Import-PersonalModules -Category ADFunctions

# Or browse all categories interactively
Invoke-PersonalModulesMenu
```

No dot-sourcing in `$PROFILE`. New functions appear the moment you drop them into the right folder.

---

## How It Works

### 1 — Organise your functions into category folders

```
C:\MyModules\
├── ADFunctions\
│   ├── ADFunctions.psm1        ← auto-dot-sources Public\
│   └── Public\
│       ├── Get-ADUserSearch.ps1
│       ├── Reset-ADUserPassword.ps1
│       └── Get-LockedOutAccounts.ps1
├── Exchange\
│   ├── Exchange.psm1
│   └── Public\
│       ├── Connect-O365Exchange.ps1
│       └── Get-MailboxPermissions.ps1
└── Network\
    ├── Network.psm1
    └── Public\
        └── Test-PortConnectivity.ps1
```

Each folder is a self-contained category. UserAdminModule discovers them dynamically — no manifest updates, no hardcoded lists.

### 2 — Import the categories you need

```powershell
# -Category tab-completes from your discovered folders at runtime
Import-PersonalModules -Category <Tab>
#                                 ADFunctions
#                                 Exchange
#                                 Network
```

### 3 — Browse your entire function library

```powershell
# Interactive PSMenu — pick categories with arrow keys
Invoke-PersonalModulesMenu

# Searchable HTML function browser
Open-ModuleMenuApp
```

---

## Features

| | |
|---|---|
| **Dynamic discovery** | New category folders appear in tab-completion automatically — no configuration changes needed |
| **Interactive menu** | `Invoke-PersonalModulesMenu` lets you select multiple categories with arrow keys and Space |
| **HTML function browser** | `Open-ModuleMenuApp` opens a searchable reference of every function in your library |
| **No dot-sourcing** | `$PROFILE` stays clean — UserAdminModule handles everything on import |
| **Scaffold new categories** | `New-PSM1Module` creates the full folder structure in one command |
| **Shareable library** | Point colleagues at the same folder path or commit the library to Git |
| **PS 5.1 and 7+ compatible** | Works in Windows PowerShell and PowerShell 7+ |
| **PSGallery published** | `Install-Module UserAdminModule` — nothing to clone, nothing to configure manually |

---

{: .note }
> UserAdminModule is currently published as a prerelease. Install with `-AllowPrerelease` until the stable `v1.0.0` release.
