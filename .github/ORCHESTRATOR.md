# ORCHESTRATOR.md — UserAdminModule Living Memory

Last Updated: 2026-04-27

---

## Architecture Summary

```
UserAdminModule/
├── UserAdminModule.psd1          ← PSGallery manifest (v1.0.2 current; bump before next publish)
├── UserAdminModule.psm1          ← Sets $script:UAMModuleRoot = $PSScriptRoot; loads Private/, Public/, Shell/ (-Global)
├── Public/                       ← 5 exported functions (Import-PersonalModules, Initialize-UserAdminModule,
│                                    Invoke-FunctionIndexRegeneration, Invoke-PersonalModulesMenu, New-PSM1Module)
├── Private/                      ← Get-UserAdminModuleConfig (reads $env:APPDATA\UserAdminModule\config.json)
│                                    PRIVATE — NOT exported. Only callable from UserAdminModule module scope.
├── Shell/Shell.psm1              ← Legacy try/catch loader (exempted). Loads Shell/Public/*.ps1 with -Global.
├── Shell/Public/                 ← 18 UX functions (Get-ImportedModuleCommand, Set-PromptisAdmin, etc.)
├── Shell/Tests/                  ← Invoke-UserAdminModuleRequiredModules.Tests.ps1 only
├── resources/                    ← ModuleMenuApp.html (auto-generated), New-ModuleMenuApp.ps1
├── build/                        ← Publish-ToGallery.ps1 (excluded from PSGallery package)
└── .github/                      ← Workflows, agents, skills (excluded from PSGallery package)
```

**Module load order in UserAdminModule.psm1:**
1. `$script:UAMModuleRoot = $PSScriptRoot`
2. Dot-source Private/*.ps1 (Get-UserAdminModuleConfig enters UserAdminModule scope)
3. Dot-source Public/*.ps1 (all 5 framework functions enter UserAdminModule scope)
4. `Import-Module Shell\Shell.psm1 -Force -DisableNameChecking -Global`

**Key scoping rule:** `$script:UAMModuleRoot` exists ONLY in UserAdminModule's script scope.
Shell module has its own scope — `$Script:UAMModuleRoot` is null there unless explicitly computed.

---

## Conventions (Non-Negotiable)

- **Error handling:** `trap` ONLY. `Shell/Shell.psm1` uses try/catch — legacy exemption only, do not replicate.
- **No `Write-Host`** — use Write-Verbose, Write-Warning, Write-Error, Write-Information
- **`[CmdletBinding()]`** on every function
- **String interpolation:** variables before `:` or `.` MUST use `$()` — e.g. `"$($cat): $_"` not `"$cat: $_"`
- **PS 5.1/7+ compat:** No `#Requires -PSEdition Core` in Shell/Public/, no `IValidateSetValuesGenerator`, no `??=`, no `Join-String`
- **No `$PSScriptRoot` for submodule discovery from Public/functions** — use `$Script:UAMModuleRoot` instead
- **New Public functions:** must be added to `FunctionsToExport` in `UserAdminModule.psd1`

---

## Known Fragile Areas

1. **`$Script:UAMModuleRoot` scope boundary:** Set in `UserAdminModule.psm1`. Accessible from `Public/` functions (same module scope). NOT set in `Shell` module scope — Shell functions must compute their own module root path.

2. **`Get-UserAdminModuleConfig` accessibility:** Private to `UserAdminModule`. Callable from `Public/` functions (same scope). NOT callable from `Shell/Public/` functions (different module scope, not exported). Shell functions must read `$env:APPDATA\UserAdminModule\config.json` directly.

3. **Shell/Public/ functions and `$PSScriptRoot`:** When dot-sourced by `Shell.psm1`, `$PSScriptRoot` = `Shell\Public\`. To reach the UserAdminModule root: `Split-Path (Split-Path $PSScriptRoot -Parent) -Parent`.

4. **`Import-Module -ErrorAction SilentlyContinue`** in Import-PersonalModules: was silently swallowing psm1 load failures. Fixed to `-ErrorAction Stop` so trap handles it.

5. **Auto-generated files:** `FunctionIndex.json`, `FunctionIndex.md`, `ModuleMenuApp.html` — never edit manually. Regenerate before publishing.

---

## Decisions Made

### 2026-04-27 — PSGallery regression fix (v1.0.2 → v1.0.3 needed)

**Problem:** After PSGallery deployment, `Get-ImportedModuleCommand` always reported "No UserAdminModule submodules loaded" even when modules were imported. `Import-PersonalModules` was silently failing on bad psm1 files.

**Root causes identified:**
- `Get-ImportedModuleCommand` is in Shell module scope. `$Script:UAMModuleRoot` was null, and the fallback `Split-Path $PSScriptRoot -Parent` computed `Shell\` (one level too shallow). Fixed to `Split-Path (Split-Path $PSScriptRoot -Parent) -Parent`.
- `Get-UserAdminModuleConfig` (private to UserAdminModule) was called via `Get-Command` guard from Shell scope — `Get-Command` returns null for private cross-module functions, so `$cfg = $null` and `$customPath = $null`. All custom modules failed `Test-IsUAMSubmodule`. Fixed by reading `config.json` directly.
- `Import-Module ... -ErrorAction SilentlyContinue` in Import-PersonalModules swallowed errors silently. Fixed to `-ErrorAction Stop` so the process-block trap can surface failures.

**Files changed:**
- `Shell/Public/Get-ImportedModuleCommand.ps1` — begin block (lines ~113–134)
- `Public/Import-PersonalModules.ps1` — process block (line ~164)

**Next step:** Bump `ModuleVersion` in `UserAdminModule.psd1` to `1.0.3` and publish to PSGallery.

---

## Current State

- All bugs fixed. Version `1.0.3` in psd1. Ready to test locally then publish.
- FunctionIndex.json/md are current (no new functions added this session)
- Tests: only `Shell/Tests/Invoke-UserAdminModuleRequiredModules.Tests.ps1` exists

---

## Subagent History

| Date | Agent | Task | Files Touched | Outcome |
|---|---|---|---|---|
| 2026-04-27 | UserAdminModule Developer | Fix PSGallery regression (round 1, partial) | `Shell/Public/Get-ImportedModuleCommand.ps1`, `Public/Import-PersonalModules.ps1` | Path logic improved but nested functions (Normalize-Path, Test-IsUAMSubmodule) still leaked into Shell scope; ChatGPT detection logic still broken |
| 2026-04-27 | Coordinator (direct) | Fundamental rewrite of both files | `Shell/Public/Get-ImportedModuleCommand.ps1`, `Public/Import-PersonalModules.ps1`, `UserAdminModule.psd1` | Complete — dynamic directory scan replaces broken ChatGPT path-comparison; -Global added to Import-Module; version bumped to 1.0.3 |
