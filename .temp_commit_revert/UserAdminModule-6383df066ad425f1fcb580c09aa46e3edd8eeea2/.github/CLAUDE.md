# CLAUDE.md — UserAdminModule

This file provides Claude-specific guidance for this repository.

All coding conventions, error handling rules, module structure, and best practices are defined in:

**→ [`.github/copilot-instructions.md`](copilot-instructions.md)**

Claude must follow every rule in that file.

---

## Claude-Specific Notes

- Read `.github/copilot-instructions.md` before generating any code
- Load the relevant `SKILL.md` from `.github/skills/` before domain-specific tasks
- When adding a new function, **always** create the test file alongside it (see `new-function-tests` skill)
- `Shell/Shell.psm1` uses try/catch — this is legacy. Do not replicate it in new code
- `$Script:UAMModuleRoot` is set by `UserAdminModule.psm1` at load time — Public functions use it for discovery instead of `$PSScriptRoot`
- When uncertain about scope or approach, ask before generating

## Key Files to Read Before Editing

| Task | Files to Read First |
|---|---|
| Editing any Public/ function | `UserAdminModule.psm1`, `Private/Get-UserAdminModuleConfig.ps1` |
| Editing Shell/ functions | `Shell/Shell.psm1`, the specific `.ps1` being changed |
| Changing discovery logic | `Public/Import-PersonalModules.ps1`, `Public/Invoke-PersonalModulesMenu.ps1` |
| Publishing | `UserAdminModule.psd1`, `build/Publish-ToGallery.ps1` |
| Updating docs | `README.md`, `FunctionIndex.json` (auto-generated — do not edit) |
