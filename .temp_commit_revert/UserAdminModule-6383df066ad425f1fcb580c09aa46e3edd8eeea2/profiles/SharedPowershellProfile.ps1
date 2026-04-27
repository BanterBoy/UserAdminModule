#Requires -Version 7.0
<#
.SYNOPSIS
    Shared PowerShell 7+ profile for UserAdminModule users.
.DESCRIPTION
    Dot-source this file from your personal PowerShell 7 profile ($PROFILE) to get:
      - UserAdminModule auto-loaded (PSGallery install takes priority; repo clone as fallback)
      - Shell submodule UX — admin prompt, console dimensions, greeting
      - F1 context-sensitive help handler (PSReadLine)
      - PSReadLine history-based prediction
      - Admin prompt indicator and greeting
      - Startup timing display

    PSGallery install — add one of these to $PROFILE:
        # Minimal (recommended with Initialize-UserAdminModule -UpdateProfile):
        Import-Module UserAdminModule

        # Full shell UX:
        . "$($(Get-Module UserAdminModule -ListAvailable | Select-Object -First 1).ModuleBase)\profiles\SharedPowershellProfile.ps1"

    Repo clone — add to $PROFILE:
        . "C:\Path\To\UserAdminModule\profiles\SharedPowershellProfile.ps1"

.NOTES
    Reference: https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_profiles
#>

# ── Startup timer ─────────────────────────────────────────────────────────────
$_profileStart = [System.Diagnostics.Stopwatch]::StartNew()

# ── Load UserAdminModule ───────────────────────────────────────────────────────
# Try by name first (PSGallery / PSModulePath install), then fall back to
# path-relative import for repo clone users.
if (Get-Module -ListAvailable -Name UserAdminModule -ErrorAction SilentlyContinue) {
    Import-Module UserAdminModule -Force -DisableNameChecking -ErrorAction SilentlyContinue
}
else {
    # Repo clone: this file lives at <ModuleRoot>\profiles\SharedPowershellProfile.ps1
    # So the module root is one level up.
    $_profileDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $_moduleRoot = Join-Path (Split-Path $_profileDir -Parent) 'UserAdminModule.psd1'

    if (Test-Path $_moduleRoot) {
        Import-Module $_moduleRoot -Force -DisableNameChecking -ErrorAction SilentlyContinue
    }
    else {
        Write-Warning "UserAdminModule not found. Install with: Install-Module UserAdminModule -AllowPrerelease"
    }

    Remove-Variable _profileDir, _moduleRoot -ErrorAction SilentlyContinue
}

if (-not (Get-Module -Name UserAdminModule)) {
    Write-Warning 'UserAdminModule failed to load. Run: Install-Module UserAdminModule -AllowPrerelease'
}

# ── Admin prompt ──────────────────────────────────────────────────────────────
if (Get-Command Set-PromptisAdmin -ErrorAction SilentlyContinue) {
    Set-PromptisAdmin
}

# ── Console dimensions ────────────────────────────────────────────────────────
if (Get-Command Set-ConsoleConfig -ErrorAction SilentlyContinue) {
    Set-ConsoleConfig -WindowHeight 45 -WindowWidth 200
}

# ── Aliases ───────────────────────────────────────────────────────────────────
$_notepadPlusPlus = 'C:\Program Files\Notepad++\notepad++.exe'
if (Test-Path $_notepadPlusPlus) {
    if (-not (Get-Alias -Name 'Notepad++' -ErrorAction SilentlyContinue)) {
        New-Alias -Name 'Notepad++' -Value $_notepadPlusPlus -Description 'Launch Notepad++'
    }
}

# ── PSReadLine — history-based prediction + F1 context help ──────────────────
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine -ErrorAction SilentlyContinue

    Set-PSReadLineOption -PredictionSource History -ErrorAction SilentlyContinue
    Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction SilentlyContinue

    Set-PSReadLineKeyHandler -Key F1 `
        -BriefDescription CommandHelp `
        -LongDescription 'Open the help window for the command at the cursor position' `
        -ScriptBlock {
            param($key, $arg)
            $ast = $null; $tokens = $null; $errors = $null; $cursor = $null
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)
            $commandAst = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.Extent.StartOffset -le $cursor -and
                $node.Extent.EndOffset -ge $cursor
            }, $true) | Select-Object -Last 1

            if ($null -ne $commandAst) {
                $commandName = $commandAst.GetCommandName()
                if ($null -ne $commandName) {
                    $command = $ExecutionContext.InvokeCommand.GetCommand($commandName, 'All')
                    if ($command -is [System.Management.Automation.AliasInfo]) {
                        $commandName = $command.ResolvedCommandName
                    }
                    if ($null -ne $commandName) {
                        Get-Help $commandName -ShowWindow
                    }
                }
            }
        }
}

# ── Greeting ──────────────────────────────────────────────────────────────────
if (Get-Command Show-IsAdminOrNot -ErrorAction SilentlyContinue) {
    Show-IsAdminOrNot
}

# ── Startup time ──────────────────────────────────────────────────────────────
$_profileStart.Stop()
Write-Information "Profile loaded in $([math]::Round($_profileStart.Elapsed.TotalSeconds, 2))s" -InformationAction Continue
Remove-Variable _profileStart, _notepadPlusPlus -ErrorAction SilentlyContinue
