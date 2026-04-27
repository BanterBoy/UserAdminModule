---
layout: single
title: Building Your Function Library
nav_order: 5
---

# Building Your Function Library

UserAdminModule is a **framework** — it gives you the structure to organise and import your own PowerShell functions. It does not ship with domain-specific admin functions (AD, Exchange, Azure, Intune, etc.) built in.

This page explains where to find ready-made admin functions and how to drop them into the framework so they appear in the menu and tab-complete by category.

---

## Where to Get Functions

The companion site **[scripts.lukeleigh.com](https://scripts.lukeleigh.com/)** hosts a growing library of ready-to-use admin functions, organised by the same categories UserAdminModule expects. Browse, download, and drop them straight into your local folder structure.

---

## Folder Structure UserAdminModule Expects

A folder qualifies as a discoverable submodule (category) when it contains a `.psm1` file whose name matches the folder name:

```
CustomModules/
├── ADFunctions/
│   ├── ADFunctions.psm1      ← required — this is what makes it discoverable
│   └── Public/
│       ├── Get-ADUserReport.ps1
│       └── Reset-ADUserPassword.ps1
├── Exchange/
│   ├── Exchange.psm1
│   └── Public/
│       └── Get-MailboxSize.ps1
└── Azure/
    ├── Azure.psm1
    └── Public/
        └── Get-AzureSubscriptions.ps1
```

The `.psm1` file acts as the module entry point. A minimal `ADFunctions.psm1` just dot-sources its `Public/` folder:

```powershell
$Public = @(Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)
foreach ($import in $Public) {
    . $import.FullName
}
Export-ModuleMember -Function $Public.BaseName
```

---

## Suggested Category Names

| Category | What goes in it |
|---|---|
| `ADFunctions` | Active Directory — users, groups, computers, OUs |
| `Exchange` | Exchange Online or on-premises mailbox management |
| `Azure` | Azure Resource Manager, subscriptions, resource groups |
| `Graph` | Microsoft Graph API — users, devices, policies |
| `Intune` | Intune device management and compliance |
| `Network` | DNS, DHCP, routing, firewall, connectivity tests |
| `Security` | Certificates, audit logs, security baselines |
| `Reporting` | HTML/CSV reports, scheduled exports |
| `Utilities` | General-purpose helpers that don't fit a specific category |

---

## Scaffold a New Category with New-PSM1Module

UserAdminModule includes `New-PSM1Module` to scaffold a new category folder with the correct structure:

```powershell
New-PSM1Module -Name ADFunctions -Path 'C:\MyModules'
```

This creates:

```
C:\MyModules\ADFunctions\
├── ADFunctions.psm1
└── Public\
    └── .gitkeep
```

Drop your function `.ps1` files into `Public\` and you're ready to import.

---

## Importing a Category

Once the folder is in place:

```powershell
# Tab-complete shows your registered categories
Import-PersonalModules -Category ADFunctions
```

Categories are discovered dynamically from both the module root and the `CustomModulesPath` you registered with `Initialize-UserAdminModule`.

---

## Updating the Function Browser

After adding or removing functions, regenerate the index and HTML browser:

```powershell
# Regenerates FunctionIndex.json, FunctionIndex.md, and ModuleMenuApp.html, then opens the browser
Open-ModuleMenuApp -Regenerate
```

Or regenerate silently without opening the browser:

```powershell
Invoke-FunctionIndexRegeneration
```

Your new functions will appear in the browser under their category.
