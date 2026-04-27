# AGENTS.md — UserAdminModule

All coding conventions, error handling rules, module structure, and best practices are defined in:

**→ [`.github/copilot-instructions.md`](copilot-instructions.md)**

Agents working in this repository MUST follow every rule in that file.

---

## Repository Purpose

UserAdminModule is a PSGallery-published PowerShell framework for managing administrator function libraries. It is a **standalone module** — not a collection of infrastructure scripts. Development work focuses on:

- The 5 base framework functions (`Public/`)
- The 16 Shell UX functions (`Shell/Public/`)
- PSGallery packaging and release pipeline (`build/`, `.github/workflows/`)
- Documentation (`README.md`, `FunctionIndex.json`, `FunctionIndex.md`)

---

## Specialized Skills

Before starting any domain-specific task, load the relevant skill file:

| Skill | Use When |
|---|---|
| `useradminmodule` | Creating/finding/refactoring functions in this module |
| `new-function-tests` | Creating any new function — tests are mandatory alongside |
| `pester-testing` | Writing Pester tests, mocking, CI workflow setup |
| `documentation-generation` | Updating README, regenerating FunctionIndex, PlatyPS |
| `github-management` | Releases, changelogs, issue/PR templates, branch protection |

Skills live at `.github/skills/<name>/SKILL.md`.

---

## Key Constraints

- **PS 5.1 AND 7+ compatible** — no Core-only constructs in Shell/Public files
- **No try/catch** — `trap` statements only
- **No Write-Host** — use Write-Verbose, Write-Warning, Write-Error, Write-Information
- **No IValidateSetValuesGenerator** — hardcode ValidateSet values instead
- **No $PSScriptRoot in Public/ functions for discovery** — use `$Script:UAMModuleRoot`
- **FunctionIndex.json is auto-generated** — never edit manually

---

## Testing

- Test files: `Shell/Tests/<FunctionName>.Tests.ps1`
- Framework: Pester v5+
- Every new function requires a test file (see `new-function-tests` skill)
- Run tests: `Invoke-Pester -Path .\Shell\Tests\ -Output Detailed`

---

## Publishing

Trigger the PSGallery publish workflow by pushing a version tag:

```bash
git tag v1.0.0-preview2
git push origin v1.0.0-preview2
```

Requires `PSGALLERY_API_KEY` secret in GitHub repository settings.
