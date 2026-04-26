---
name: pester-testing
description: >
  Generate Pester tests and CI workflows for PowerShell functions in the RDGScripts repository.
  USE FOR: creating Pester test files for new or existing functions, scaffolding test fixtures,
  mocking Active Directory or Microsoft Graph API calls, generating GitHub Actions CI workflows,
  setting up PSScriptAnalyzer integration, backfilling tests for critical scripts, creating
  test parameter matrices for cross-version testing (PS 5.1 and 7+).
  DO NOT USE FOR: writing the functions themselves (use default agent or useradminmodule skill),
  creating change requests (use change-request skill), or managing GitHub settings (use
  github-management skill).
---

# Pester Testing & CI Skill

## Purpose

Generate high-quality Pester v5+ tests for PowerShell functions in the RDGScripts repository, following established patterns and repo conventions. Also scaffolds GitHub Actions workflows for automated testing and static analysis.

## When This Skill Applies

Activate when the user:

- Asks to "write tests", "create Pester tests", "add unit tests", or "test this function"
- Wants to "backfill tests" for existing scripts or modules
- Asks for a "CI pipeline", "GitHub Actions workflow", or "automated testing"
- Mentions "PSScriptAnalyzer", "lint", "static analysis", or "code quality"
- Asks to "mock" AD, Exchange, Graph, or other cmdlets for testing
- Wants to validate a function works correctly before deploying
- Asks about test coverage or testing strategy for the repo

## Repository Testing Context

| Property | Value |
|---|---|
| **Current test coverage** | ~0.2% (2 Pester test files across ~1,209 scripts) |
| **Pester version** | v5+ (modern syntax) |
| **Test file naming** | `<FunctionName>.Tests.ps1` |
| **CI status** | No GitHub Actions workflows configured |
| **Analyser** | PSScriptAnalyzer referenced in AGENTS.md but not enforced |

### Existing Test Files (Reference)

| File | Pattern | Complexity |
|---|---|---|
| `Functions/Check MFA Status.Test.ps1` | Dot-source import, simple mocks, `Should -Be` | Basic |
| `ISAM-Manager/Tests/Export-EntraGraphSSOAppConfigAll.Tests.ps1` | Script path import, Graph API mocking, TestDrive, `BeforeAll`/`BeforeEach` | Advanced |
| `Scripts/Send-MailGunMessage.Tests.ps1` | Manual test case comments (not executable) | Incomplete |

---

## Workflow 1 — Create Tests for a Function

### When to Use

User asks to write tests for a specific function or script.

### Steps

1. **Read the target function** — Understand parameters, logic branches, error paths, and output types

2. **Determine the test file location** — Follow these rules:

   | Function Location | Test File Location |
   |---|---|
   | `UserAdminModule/<Submodule>/Public/Verb-Noun.ps1` | `UserAdminModule/<Submodule>/Tests/Verb-Noun.Tests.ps1` |
   | `Functions/FunctionName.ps1` | `Functions/FunctionName.Tests.ps1` |
   | `Scripts/ScriptName.ps1` | `Scripts/ScriptName.Tests.ps1` |
   | `<Scenario>/ScriptName.ps1` | `<Scenario>/Tests/ScriptName.Tests.ps1` |

3. **Identify what needs mocking** — Common mock targets:

   | Domain | Cmdlets to Mock |
   |---|---|
   | Active Directory | `Get-ADUser`, `Get-ADGroup`, `Get-ADComputer`, `Get-ADGroupMember`, `Set-ADUser`, `New-ADUser` |
   | Exchange Online | `Get-Mailbox`, `Get-MailboxPermission`, `Get-DistributionGroupMember`, `Get-CalendarProcessing` |
   | Microsoft Graph | `Get-MgContext`, `Invoke-MgGraphRequest`, `Get-MgUser`, `Get-MgApplication`, `Get-MgServicePrincipal` |
   | Azure/Entra | `Connect-AzAccount`, `Get-AzResource`, `Connect-MgGraph` |
   | System | `Test-Connection`, `Get-WmiObject`, `Get-CimInstance`, `Resolve-DnsName` |
   | File I/O | `Test-Path`, `Get-Content`, `Export-Csv`, `Out-File` |

4. **Generate the test file** using the template below

5. **Verify the tests run** — Execute with `Invoke-Pester -Path <test-file> -Output Detailed`

### Test File Template

```powershell
#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for {FunctionName}.

.NOTES
    Requires Pester v5+.
    Run: Invoke-Pester -Path '{TestFilePath}' -Output Detailed
#>

BeforeAll {
    # Import the function under test
    . "$PSScriptRoot\..\Public\{FunctionName}.ps1"
    # OR for standalone scripts:
    # . "$PSScriptRoot\{FunctionName}.ps1"
}

Describe '{FunctionName}' {

    Context 'Parameter validation' {
        It 'Has mandatory parameter {ParamName}' {
            (Get-Command {FunctionName}).Parameters['{ParamName}'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                Select-Object -ExpandProperty Mandatory |
                Should -BeTrue
        }

        It 'Rejects empty string for {ParamName}' {
            { {FunctionName} -{ParamName} '' } | Should -Throw
        }
    }

    Context 'When processing valid input' {
        BeforeAll {
            # Create test fixtures
            $testObject = [PSCustomObject]@{
                Name  = 'TestItem'
                Value = 'TestValue'
            }
        }

        BeforeEach {
            # Set up mocks (recreated for each test)
            Mock -CommandName {ExternalCmdlet} -MockWith {
                return $testObject
            }
        }

        It 'Returns expected output for standard input' {
            $result = {FunctionName} -{ParamName} 'TestValue'
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'TestItem'
        }

        It 'Calls {ExternalCmdlet} exactly once' {
            {FunctionName} -{ParamName} 'TestValue'
            Should -Invoke -CommandName {ExternalCmdlet} -Exactly -Times 1
        }

        It 'Supports pipeline input' {
            $result = 'TestValue' | {FunctionName}
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'When handling errors' {
        BeforeEach {
            Mock -CommandName {ExternalCmdlet} -MockWith {
                throw 'Simulated failure'
            }
        }

        It 'Writes an error when {ExternalCmdlet} fails' {
            { {FunctionName} -{ParamName} 'BadValue' -ErrorAction Stop } |
                Should -Throw
        }
    }

    Context 'When exporting output' {
        BeforeAll {
            $testOutputPath = Join-Path -Path $TestDrive -ChildPath 'output'
            New-Item -Path $testOutputPath -ItemType Directory -Force | Out-Null
        }

        BeforeEach {
            Mock -CommandName {ExternalCmdlet} -MockWith {
                return [PSCustomObject]@{ Name = 'TestItem' }
            }
        }

        It 'Creates a CSV file when -ExportCsv is specified' {
            {FunctionName} -{ParamName} 'TestValue' -ExportCsv -OutputPath $testOutputPath
            $csvFiles = Get-ChildItem -Path $testOutputPath -Filter '*.csv'
            $csvFiles | Should -Not -BeNullOrEmpty
        }
    }
}
```

### Mock Pattern Reference

**Simple cmdlet mock:**
```powershell
Mock -CommandName Get-ADUser -MockWith {
    [PSCustomObject]@{
        SamAccountName    = 'jsmith'
        DisplayName       = 'John Smith'
        Enabled           = $true
        LastLogonDate     = (Get-Date).AddDays(-5)
        DistinguishedName = 'CN=John Smith,OU=Users,DC=contoso,DC=com'
    }
}
```

**Mock with parameter filter:**
```powershell
Mock -CommandName Get-ADUser -ParameterFilter { $Identity -eq 'jsmith' } -MockWith {
    [PSCustomObject]@{ SamAccountName = 'jsmith'; Enabled = $true }
}
Mock -CommandName Get-ADUser -ParameterFilter { $Identity -eq 'disabled-user' } -MockWith {
    [PSCustomObject]@{ SamAccountName = 'disabled-user'; Enabled = $false }
}
```

**Graph API mock (complex nested objects):**
```powershell
BeforeAll {
    $script:testApplication = [PSCustomObject]@{
        Id              = 'app-guid-here'
        AppId           = 'client-id-here'
        DisplayName     = 'Test Application'
        IdentifierUris  = @('api://test-app')
        Web             = [PSCustomObject]@{
            RedirectUris = @('https://testapp/signin')
        }
        KeyCredentials  = @(
            [PSCustomObject]@{
                DisplayName = 'TestCert'
                EndDateTime = (Get-Date).AddMonths(6)
                Type        = 'AsymmetricX509Cert'
            }
        )
    }
}

BeforeEach {
    Mock -CommandName Get-MgContext -MockWith {
        [PSCustomObject]@{
            TenantId = '00000000-0000-0000-0000-000000000000'
            AuthType = 'AppOnly'
            Scopes   = @()
        }
    }
    Mock -CommandName Get-MgApplication -MockWith { $script:testApplication }
}
```

**File I/O validation with TestDrive:**
```powershell
Context 'File output validation' {
    BeforeAll {
        $testOutput = Join-Path -Path $TestDrive -ChildPath 'reports'
        New-Item -Path $testOutput -ItemType Directory -Force | Out-Null
    }

    It 'Creates JSON output file' {
        & $scriptPath -OutputPath $testOutput
        $jsonPath = Join-Path -Path $testOutput -ChildPath 'report.json'
        Test-Path $jsonPath | Should -BeTrue
    }

    It 'JSON content is valid' {
        $jsonPath = Join-Path -Path $testOutput -ChildPath 'report.json'
        $content = Get-Content -Path $jsonPath -Raw
        { $content | ConvertFrom-Json } | Should -Not -Throw
    }
}
```

---

## Workflow 2 — Create GitHub Actions CI Workflow

### When to Use

User asks for CI/CD, automated testing, or a GitHub Actions pipeline.

### Steps

1. **Determine scope** — Full repo analysis vs. targeted module testing
2. **Generate the workflow file** at `.github/workflows/`
3. **Include both PSScriptAnalyzer and Pester stages**

### CI Workflow Template

```yaml
name: PowerShell CI

on:
  push:
    branches: [prod]
    paths: ['**/*.ps1', '**/*.psm1', '**/*.psd1']
  pull_request:
    branches: [prod]
    paths: ['**/*.ps1', '**/*.psm1', '**/*.psd1']

jobs:
  lint:
    name: PSScriptAnalyzer
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run PSScriptAnalyzer
        shell: pwsh
        run: |
          Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
          $results = Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error, Warning -ExcludeRule PSAvoidUsingWriteHost
          $results | Format-Table -AutoSize
          if ($results | Where-Object Severity -eq 'Error') {
            throw "PSScriptAnalyzer found errors"
          }

  test:
    name: Pester Tests
    runs-on: windows-latest
    needs: lint
    strategy:
      matrix:
        powershell: ['5.1', '7']
    steps:
      - uses: actions/checkout@v4

      - name: Run Pester Tests (PS ${{ matrix.powershell }})
        shell: pwsh
        run: |
          Install-Module -Name Pester -Force -Scope CurrentUser -MinimumVersion 5.0.0
          $config = New-PesterConfiguration
          $config.Run.Path = @(
            'Functions/*.Tests.ps1',
            'Scripts/*.Tests.ps1',
            'ISAM-Manager/Tests/*.Tests.ps1',
            'UserAdminModule/*/Tests/*.Tests.ps1'
          )
          $config.Output.Verbosity = 'Detailed'
          $config.TestResult.Enabled = $true
          $config.TestResult.OutputFormat = 'NUnitXml'
          $config.TestResult.OutputPath = 'test-results.xml'
          Invoke-Pester -Configuration $config
```

---

## Workflow 3 — Backfill Tests for Existing Functions

### When to Use

User asks to add tests for an existing function, module, or folder that has no tests.

### Steps

1. **Survey the target** — List all public functions in the scope
2. **Prioritise by risk** — Functions that modify state (Set-, Remove-, New-) before read-only (Get-, Test-)
3. **Generate test files** — One `.Tests.ps1` per function, following Workflow 1
4. **Create a test manifest** — Summary of what was generated

### Priority Order for Backfilling

| Priority | Verb Pattern | Reason |
|---|---|---|
| 1 - Critical | `Set-`, `Remove-`, `New-`, `Invoke-` | Mutating operations — highest risk |
| 2 - High | `Export-`, `Import-`, `Send-` | Data movement — integrity matters |
| 3 - Medium | `Get-`, `Find-`, `Search-` | Read operations — validate output shape |
| 4 - Low | `Test-`, `Resolve-`, `Convert-` | Utility operations — usually simple |

---

## Conventions — Non-Negotiable

All generated test code MUST follow these rules:

1. **Pester v5+ syntax** — `BeforeAll`, `BeforeEach`, `Should -Be` (not legacy `Should Be`)
2. **No try/catch in test helpers** — If writing helper functions for tests, use `trap` only
3. **TestDrive for file operations** — Never write to real filesystem paths in tests
4. **Mock all external dependencies** — AD, Exchange, Graph, DNS, WMI — never call real services
5. **Test parameter validation** — Every mandatory parameter and ValidateSet should have a test
6. **Test error paths** — Verify trap/error handling behaviour with `-ErrorAction Stop`
7. **No hardcoded credentials** — Use `[PSCredential]::Empty` or mock `Get-Credential`
8. **Cross-version compatible** — Tests must pass on both PowerShell 5.1 and 7+

### Credential Mocking Pattern (Safe)

```powershell
# NEVER use plaintext passwords in tests
# Use PSCredential::Empty or mock Get-Credential
BeforeEach {
    $testCredential = [System.Management.Automation.PSCredential]::new(
        'testuser@contoso.com',
        (New-Object System.Security.SecureString)
    )
    Mock -CommandName Get-Credential -MockWith { $testCredential }
}
```

## Quality Checks

Before presenting test files, verify:

- [ ] Test file name matches `<FunctionName>.Tests.ps1`
- [ ] Test file is in the correct location per the placement table
- [ ] All external cmdlets are mocked (no real AD/Exchange/Graph calls)
- [ ] Parameter validation tests exist for all mandatory parameters
- [ ] At least one success-path and one error-path test exist
- [ ] `BeforeAll` imports the function under test correctly
- [ ] No hardcoded credentials or real tenant IDs
- [ ] File I/O tests use `$TestDrive` not real paths
- [ ] Assertions use Pester v5+ syntax (`Should -Be`, not `Should Be`)
- [ ] Tests would pass on both PS 5.1 and PS 7+
