---
name: new-function-tests
description: >
  MANDATORY QUALITY GATE — enforce Pester v5 test creation alongside every new PowerShell
  function written in the UserAdminModule repository. USE FOR: any time a new function is created
  or requested — ensures tests are written before the function is considered done. Provides
  test file templates and mock patterns for credential functions, connection/disconnect
  functions, AD, Exchange Online, on-premises Exchange, Microsoft Graph, Intune, Defender,
  and general utility functions. Prevents functions being committed without test coverage.
  Also use when the user asks "should I add tests?", "do I need tests for this?", or
  "is this function complete?". DO NOT USE FOR: writing tests for existing functions
  without accompanying new function creation (use pester-testing skill instead);
  creating change requests (use change-request skill).
---

# New Function Tests — Quality Gate Skill

## Purpose

Every new function in UserAdminModule MUST have a corresponding Pester v5 test file created
**at the same time** as the function itself. This skill activates on any function creation
request and enforces that workflow. A function is not considered done until its test file
exists, the tests pass, and the quality checklist is signed off.

## Core Principle

> No function is complete without a test file. Create the test alongside the function — not after.

---

## When This Skill Applies

Activate when the user:

- Asks to "create a function", "write a function", "add a function", or "build a function"
- Asks to "add to a module" or names a submodule and describes a new capability
- Uses the `/useradminmodule` skill to create a new function
- Receives a new `.ps1` file that doesn't yet have a corresponding `.Tests.ps1`
- Asks "is this function complete?" or "can I commit this?"

---

## Mandatory Workflow

### Step 1 — Create the Function

Follow the standard function template from the `useradminmodule` skill or `copilot-instructions.md`.
All mandatory standards apply:
- Approved verb, `[CmdletBinding()]`, `trap` error handling, comment-based help
- `$()` subexpression for variables before `:` or `.` in strings

### Step 2 — Immediately Create the Test File

**Do not wait. Do not ask. Create the test file as part of the same response.**

Determine the test path:

| Function Location | Test File Location |
|---|---|
| `Shell/Public/Verb-Noun.ps1` | `Shell/Tests/Verb-Noun.Tests.ps1` |
| `Public/Verb-Noun.ps1` | `Shell/Tests/Verb-Noun.Tests.ps1` |

### Step 3 — Determine Mock Requirements

Identify every external dependency in the function and mock it. Use the pattern table below.

### Step 4 — Run Quality Checklist

All items must pass before the function is considered done.

### Step 5 — Syntax Validate Both Files

```powershell
$files = @('Path\To\Verb-Noun.ps1', 'Path\To\Verb-Noun.Tests.ps1')
foreach ($file in $files) {
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors) { Write-Host "ERR: $file"; $errors | ForEach-Object { "  L$($_.Extent.StartLineNumber): $($_.Message)" } }
    else { Write-Host "OK: $file" }
}
```

---

## Mock Pattern Quick Reference

| Function Type | Commands to Mock |
|---|---|
| **Credential-accepting** | `Get-Credential` |
| **Exchange Online** | `Connect-ExchangeOnline`, `Disconnect-ExchangeOnline`, `Import-Module ExchangeOnlineManagement`, `Get-Mailbox`, `Get-MailboxPermission` |
| **On-Prem Exchange (PSSession)** | `New-PSSession`, `Import-PSSession`, `Remove-PSSession`, `Connect-ExchangeOnPrem`, `Get-Command` |
| **Azure (Az module)** | `Connect-AzAccount`, `Disconnect-AzAccount`, `Get-AzResource`, `Import-Module Az.Accounts` |
| **Microsoft Graph** | `Connect-MgGraph`, `Disconnect-MgGraph`, `Get-MgContext`, `Get-MgUser`, `Get-MgApplication`, `Get-MgServicePrincipal`, `Import-Module Microsoft.Graph.Authentication` |
| **Microsoft Teams** | `Connect-MicrosoftTeams`, `Disconnect-MicrosoftTeams`, `Import-Module MicrosoftTeams` |
| **Active Directory** | `Get-ADUser`, `Get-ADGroup`, `Get-ADComputer`, `Get-ADGroupMember`, `Set-ADUser`, `New-ADUser`, `Get-ADDomain` |
| **Module availability check** | `Get-Command` (mock with `$null` for "not installed" path, mock with object for "installed" path) |
| **PSSession state** | `Get-PSSession` |
| **File I/O** | `Test-Path`, `Get-Content`, `Export-Csv`, `Out-File` — use `$TestDrive` for write paths |
| **DNS / network** | `Resolve-DnsName`, `Test-Connection`, `Test-NetConnection` |

---

## Test Templates by Function Type

### Template A — Credential-Accepting Function

For functions with a `-Credential` or `-[Service]Credential` parameter that call `Get-Credential` when omitted.

```powershell
#Requires -Modules Pester

BeforeAll {
    . "$PSScriptRoot\..\Public\{FunctionName}.ps1"

    # Safe test credential — never use plaintext passwords
    $script:testCredential = [System.Management.Automation.PSCredential]::new(
        'testuser@contoso.com',
        (New-Object System.Security.SecureString)
    )
}

Describe '{FunctionName}' {

    Context 'Parameter validation' {
        It 'Accepts a PSCredential parameter' {
            (Get-Command {FunctionName}).Parameters.ContainsKey('{CredentialParam}') | Should -BeTrue
        }
    }

    Context 'When credential is not supplied' {
        BeforeEach {
            Mock -CommandName Get-Credential -MockWith { $script:testCredential }
            # Mock any service connections the function makes
            Mock -CommandName {ServiceConnectCmdlet} -MockWith { }
        }

        It 'Prompts for credentials via Get-Credential' {
            {FunctionName} -{RequiredParams}
            Should -Invoke -CommandName Get-Credential -Exactly -Times 1
        }
    }

    Context 'When credential is supplied' {
        BeforeEach {
            Mock -CommandName Get-Credential -MockWith { throw 'Should not be called when credential is supplied' }
            Mock -CommandName {ServiceConnectCmdlet} -MockWith { }
        }

        It 'Does not call Get-Credential when -Credential is provided' {
            {FunctionName} -{CredentialParam} $script:testCredential -{RequiredParams}
            Should -Invoke -CommandName Get-Credential -Exactly -Times 0
        }
    }
}
```

### Template B — Cloud Service Connection Function

For `Connect-*` functions that connect to one or more cloud services with a `[ValidateSet]` `-Service` parameter.

```powershell
#Requires -Modules Pester

BeforeAll {
    . "$PSScriptRoot\..\Public\{FunctionName}.ps1"

    $script:testCredential = [System.Management.Automation.PSCredential]::new(
        'admin@contoso.com',
        (New-Object System.Security.SecureString)
    )
}

Describe '{FunctionName}' {

    Context 'Parameter validation' {
        It 'Rejects an invalid service name' {
            { {FunctionName} -Service 'InvalidService' -{CredentialParam} $script:testCredential } |
                Should -Throw
        }

        It 'Accepts each valid service value' {
            (Get-Command {FunctionName}).Parameters['Service'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
                Select-Object -ExpandProperty ValidValues |
                Should -Not -BeNullOrEmpty
        }
    }

    Context 'When connecting to ExchangeOnline' {
        BeforeEach {
            Mock -CommandName Import-Module -MockWith { } -ParameterFilter { $Name -eq 'ExchangeOnlineManagement' }
            Mock -CommandName Connect-ExchangeOnline -MockWith { }
        }

        It 'Calls Connect-ExchangeOnline once' {
            {FunctionName} -Service ExchangeOnline -{CredentialParam} $script:testCredential
            Should -Invoke -CommandName Connect-ExchangeOnline -Exactly -Times 1
        }

        It 'Returns a connected status object' {
            $result = {FunctionName} -Service ExchangeOnline -{CredentialParam} $script:testCredential
            $result.Service | Should -Be 'ExchangeOnline'
            $result.Connected | Should -BeTrue
        }
    }

    Context "When 'All' is specified" {
        BeforeEach {
            Mock -CommandName Import-Module -MockWith { }
            Mock -CommandName Connect-ExchangeOnline  -MockWith { }
            Mock -CommandName Connect-AzAccount       -MockWith { [PSCustomObject]@{} }
            Mock -CommandName Connect-MicrosoftTeams  -MockWith { [PSCustomObject]@{} }
            Mock -CommandName Connect-MgGraph         -MockWith { }
            Mock -CommandName Connect-IPPSSession     -MockWith { }
        }

        It 'Returns a result for every service' {
            $results = {FunctionName} -Service All -{CredentialParam} $script:testCredential
            $results.Count | Should -BeGreaterThan 1
        }

        It 'All returned results show Connected = True' {
            $results = {FunctionName} -Service All -{CredentialParam} $script:testCredential
            $results | ForEach-Object { $_.Connected | Should -BeTrue }
        }
    }

    Context 'When UseDeviceCode is specified' {
        BeforeEach {
            Mock -CommandName Import-Module -MockWith { }
            Mock -CommandName Connect-ExchangeOnline -MockWith { }
        }

        It 'Passes device code flag to Connect-ExchangeOnline' {
            {FunctionName} -Service ExchangeOnline -{CredentialParam} $script:testCredential -UseDeviceCode
            Should -Invoke -CommandName Connect-ExchangeOnline -ParameterFilter { $Device -eq $true } -Exactly -Times 1
        }
    }

    Context 'SupportsShouldProcess' {
        It 'Supports -WhatIf without error' {
            { {FunctionName} -Service ExchangeOnline -{CredentialParam} $script:testCredential -WhatIf } |
                Should -Not -Throw
        }
    }
}
```

### Template C — Disconnect / Cleanup Function

For `Disconnect-*` functions that close sessions and handle "module not loaded" gracefully.

```powershell
#Requires -Modules Pester

BeforeAll {
    . "$PSScriptRoot\..\Public\{FunctionName}.ps1"
}

Describe '{FunctionName}' {

    Context 'When all modules are loaded and sessions are active' {
        BeforeEach {
            Mock -CommandName Disconnect-ExchangeOnline   -MockWith { }
            Mock -CommandName Disconnect-AzAccount        -MockWith { [PSCustomObject]@{} }
            Mock -CommandName Disconnect-MicrosoftTeams   -MockWith { [PSCustomObject]@{} }
            Mock -CommandName Disconnect-MgGraph          -MockWith { }
            Mock -CommandName Get-Command                 -MockWith { [PSCustomObject]@{ Name = $CommandName } }
            Mock -CommandName Get-PSSession               -MockWith {
                [PSCustomObject]@{ ConfigurationName = 'Microsoft.Exchange'; State = 'Opened' }
            }
            Mock -CommandName Remove-PSSession            -MockWith { }
        }

        It 'Disconnects all services when -Service All is used' {
            $results = {FunctionName} -Service All
            $results | Where-Object { $_.Disconnected -eq $false } | Should -BeNullOrEmpty
        }

        It 'Returns one status object per service' {
            $results = {FunctionName} -Service All
            $results.Count | Should -BeGreaterThan 1
        }
    }

    Context 'When modules are not loaded (graceful degradation)' {
        BeforeEach {
            # Simulate module not installed — Get-Command returns nothing
            Mock -CommandName Get-Command -MockWith { $null }
        }

        It 'Does not throw when disconnect cmdlets are unavailable' {
            { {FunctionName} -Service ExchangeOnline } | Should -Not -Throw
        }

        It 'Returns Disconnected = False with an explanatory message' {
            $result = {FunctionName} -Service ExchangeOnline
            $result.Disconnected | Should -BeFalse
            $result.Message | Should -Not -BeNullOrEmpty
        }
    }

    Context 'When no Exchange PSSessions are active' {
        BeforeEach {
            Mock -CommandName Get-PSSession -MockWith { @() }
            Mock -CommandName Remove-PSSession -MockWith { }
        }

        It 'Does not throw when no sessions exist' {
            { {FunctionName} -Service OnPremExchange } | Should -Not -Throw
        }

        It 'Reports no sessions found without error' {
            $result = {FunctionName} -Service OnPremExchange
            $result.Disconnected | Should -BeTrue
        }
    }

    Context 'Default behaviour (no -Service specified)' {
        BeforeEach {
            Mock -CommandName Get-Command -MockWith { [PSCustomObject]@{ Name = $CommandName } }
            Mock -CommandName Disconnect-ExchangeOnline  -MockWith { }
            Mock -CommandName Disconnect-AzAccount       -MockWith { [PSCustomObject]@{} }
            Mock -CommandName Disconnect-MicrosoftTeams  -MockWith { [PSCustomObject]@{} }
            Mock -CommandName Disconnect-MgGraph         -MockWith { }
            Mock -CommandName Get-PSSession              -MockWith { @() }
        }

        It 'Defaults to disconnecting all services' {
            $results = {FunctionName}
            $results.Count | Should -BeGreaterThan 1
        }
    }

    Context 'SupportsShouldProcess' {
        It 'Supports -WhatIf without error' {
            { {FunctionName} -WhatIf } | Should -Not -Throw
        }
    }
}
```

### Template D — On-Premises Connection (PSSession / AD)

For functions that connect to on-premises resources using `New-PSSession` or `Get-ADDomain`.

```powershell
#Requires -Modules Pester

BeforeAll {
    . "$PSScriptRoot\..\Public\{FunctionName}.ps1"

    $script:testCredential = [System.Management.Automation.PSCredential]::new(
        'onpremadmin@contoso.local',
        (New-Object System.Security.SecureString)
    )
}

Describe '{FunctionName}' {

    Context 'Exchange via ConnectExchangeOnPrem module (preferred path)' {
        BeforeEach {
            Mock -CommandName Get-Command -MockWith { [PSCustomObject]@{ Name = 'Connect-ExchangeOnPrem' } } `
                -ParameterFilter { $Name -eq 'Connect-ExchangeOnPrem' }
            Mock -CommandName Import-Module        -MockWith { }
            Mock -CommandName Connect-ExchangeOnPrem -MockWith { }
        }

        It 'Uses Connect-ExchangeOnPrem when the module is available' {
            {FunctionName} -Service Exchange -OnPremCredential $script:testCredential -ExchangeServer 'exchange01.domain.local'
            Should -Invoke -CommandName Connect-ExchangeOnPrem -Exactly -Times 1
        }
    }

    Context 'Exchange via PSSession fallback (ConnectExchangeOnPrem not installed)' {
        BeforeEach {
            Mock -CommandName Get-Command -MockWith { $null } `
                -ParameterFilter { $Name -eq 'Connect-ExchangeOnPrem' }
            Mock -CommandName New-PSSession    -MockWith { [PSCustomObject]@{ Id = 1; State = 'Opened' } }
            Mock -CommandName Import-PSSession -MockWith { }
            Mock -CommandName Import-Module    -MockWith { }
        }

        It 'Falls back to New-PSSession when ConnectExchangeOnPrem is not available' {
            {FunctionName} -Service Exchange -OnPremCredential $script:testCredential -ExchangeServer 'exchange01.domain.local'
            Should -Invoke -CommandName New-PSSession -Exactly -Times 1
        }
    }

    Context 'Active Directory validation' {
        BeforeEach {
            Mock -CommandName Import-Module -MockWith { }
            Mock -CommandName Get-ADDomain  -MockWith {
                [PSCustomObject]@{ DNSRoot = 'contoso.local'; PDCEmulator = 'dc01.contoso.local' }
            }
        }

        It 'Calls Get-ADDomain to validate the credential' {
            {FunctionName} -Service ActiveDirectory -OnPremCredential $script:testCredential
            Should -Invoke -CommandName Get-ADDomain -Exactly -Times 1
        }

        It 'Returns the credential in the output for use with AD cmdlets' {
            $result = {FunctionName} -Service ActiveDirectory -OnPremCredential $script:testCredential
            $result.Credential | Should -Not -BeNullOrEmpty
        }
    }
}
```

### Template E — General Utility Function

For functions that do not interact with external services.

```powershell
#Requires -Modules Pester

BeforeAll {
    . "$PSScriptRoot\..\Public\{FunctionName}.ps1"
}

Describe '{FunctionName}' {

    Context 'Parameter validation' {
        It 'Has mandatory parameter {ParamName}' {
            (Get-Command {FunctionName}).Parameters['{ParamName}'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                Select-Object -ExpandProperty Mandatory |
                Should -BeTrue
        }

        It 'Rejects null or empty {ParamName}' {
            { {FunctionName} -{ParamName} '' } | Should -Throw
        }
    }

    Context 'When processing valid input' {
        It 'Returns a PSCustomObject' {
            $result = {FunctionName} -{ParamName} 'TestValue'
            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Supports pipeline input' {
            $result = 'TestValue' | {FunctionName}
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Error handling' {
        It 'Writes an error gracefully when processing fails' {
            # Trigger a failure path appropriate to the function
            { {FunctionName} -{ParamName} $null -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'SupportsShouldProcess (if applicable)' {
        It 'Supports -WhatIf without error' {
            { {FunctionName} -{ParamName} 'TestValue' -WhatIf } | Should -Not -Throw
        }
    }
}
```

---

## Quality Checklist — Function Is NOT Done Until All Pass

Before presenting a completed function to the user, verify every item:

### Function Checklist
- [ ] Approved PowerShell verb used
- [ ] `[CmdletBinding()]` present
- [ ] All mandatory parameters have `[ValidateNotNullOrEmpty()]` or other validation
- [ ] Error handling uses `trap` — **no `try/catch` blocks anywhere**
- [ ] Variables followed by `:` or `.` in strings use `$()` subexpression
- [ ] Comment-based help includes SYNOPSIS, DESCRIPTION, PARAMETER (all), EXAMPLE (2+), OUTPUTS, NOTES, LINK
- [ ] Microsoft docs URL referenced in NOTES or DESCRIPTION
- [ ] `Write-Verbose` used for progress — **not `Write-Host`**
- [ ] No hardcoded usernames, passwords, domain names, or server names
- [ ] No plain-text credentials in any parameter default or example

### Test Checklist
- [ ] Test file exists at the correct path per the placement table
- [ ] Test file name is `<FunctionName>.Tests.ps1`
- [ ] `BeforeAll` correctly imports the function under test via dot-sourcing
- [ ] All external cmdlets are mocked — zero real AD/Exchange/Graph/Azure calls
- [ ] Tests cover parameter validation (mandatory params, ValidateSet values)
- [ ] Tests cover the primary success path
- [ ] Tests cover the error/failure path
- [ ] Tests cover `SupportsShouldProcess` (`-WhatIf`) if the function has it
- [ ] Credentials use `[PSCredential]::new('user', (New-Object System.Security.SecureString))`
- [ ] No hardcoded credentials, tenant IDs, or real server names in tests
- [ ] File I/O tests use `$TestDrive` — never write to real paths
- [ ] Tests use Pester v5 syntax (`Should -Be`, `Should -Invoke`, not legacy)
- [ ] Both files pass PowerShell syntax validation (`Parser.ParseFile`)

---

## Learned Patterns from This Repository

These patterns were derived from real functions in the RDGAdmin submodule. Apply them when creating similar functions.

### `Get-Command` Availability Pattern

When a function conditionally uses a module that may not be installed, test BOTH paths:

```powershell
# Path 1 — module IS installed
Mock -CommandName Get-Command -MockWith { [PSCustomObject]@{ Name = 'SomeCmdlet' } } `
    -ParameterFilter { $Name -eq 'SomeCmdlet' }

# Path 2 — module is NOT installed (graceful degradation)
Mock -CommandName Get-Command -MockWith { $null } `
    -ParameterFilter { $Name -eq 'SomeCmdlet' }
```

### Module-Scoped Variable Testing

When a function writes to `$script:` variables (e.g. storing credentials in the module), verify the side effect:

```powershell
It 'Stores the credential in module scope' {
    InModuleScope RDGAdmin {
        Connect-RDGCloudAdmin -Service ExchangeOnline -CloudCredential $script:testCredential
        $script:RDGCloudCredential | Should -Not -BeNullOrEmpty
    }
}
```

### ValidateSet Expansion Test

When `All` or similar expands to a list of services:

```powershell
It 'All expands to every available service' {
    $results = {FunctionName} -Service All -{CredentialParam} $script:testCredential
    $expectedServiceCount = 7  # Update to match actual count
    $results.Count | Should -Be $expectedServiceCount
}
```

### Round-Trip Disconnect Test

When testing that a disconnect function clears module credentials:

```powershell
It 'Clears module-scoped credentials after disconnect' {
    InModuleScope RDGAdmin {
        Disconnect-RDGAdminSessions -Service All
        $script:RDGCloudCredential  | Should -BeNullOrEmpty
        $script:RDGOnPremCredential | Should -BeNullOrEmpty
    }
}
```

---

## Backfill Tasks Created by This Session

The following functions were created without tests and need them backfilled:

| Function | Location | Template to Use |
|---|---|---|
| `Connect-RDGCloudAdmin` | `UserAdminModule/RDGAdmin/Public/` | Template B (Cloud Connection) |
| `Connect-RDGOnPremAdmin` | `UserAdminModule/RDGAdmin/Public/` | Template D (On-Prem Connection) |
| `Disconnect-RDGAdminSessions` | `UserAdminModule/RDGAdmin/Public/` | Template C (Disconnect) |

---

## Running Tests

```powershell
# Run a single test file
Invoke-Pester -Path 'UserAdminModule\RDGAdmin\Tests\Connect-RDGCloudAdmin.Tests.ps1' -Output Detailed

# Run all RDGAdmin tests
Invoke-Pester -Path 'UserAdminModule\RDGAdmin\Tests\*.Tests.ps1' -Output Detailed

# Run all module tests
$config = New-PesterConfiguration
$config.Run.Path = 'UserAdminModule\*/Tests\*.Tests.ps1'
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config
```
