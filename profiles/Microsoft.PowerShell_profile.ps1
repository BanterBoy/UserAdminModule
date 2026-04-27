<#
    Microsoft.PowerShell_profile.ps1 — Minimal reference profile for UserAdminModule
    ==================================================================================
    This is an EXAMPLE profile. Copy the relevant block into your own $PROFILE.

    There are two levels of setup:

    OPTION A — Minimal (recommended for most users)
    ─────────────────────────────────────────────────
    After running:
        Initialize-UserAdminModule -Path 'C:\MyModules' -UpdateProfile

    Your $PROFILE will contain just:
        Import-Module UserAdminModule

    That single line loads the Shell submodule globally (Set-PromptisAdmin,
    Show-IsAdminOrNot, New-Greeting, Set-ConsoleConfig, Open-ModuleMenuApp, etc.)
    and registers Import-PersonalModules for on-demand category loading.

    OPTION B — Full shared profile (all UX features)
    ──────────────────────────────────────────────────
    Run: Initialize-UserAdminModule -Path 'C:\MyModules' -UpdateProfile -UseSharedProfile
    This writes the dynamic resolution block below to your $PROFILE automatically.
    It resolves the newest installed version at each session startup — so it stays
    correct after Update-Module without re-running Initialize-UserAdminModule.

    PS 7+ / Core — written to $PROFILE:

        # UserAdminModule shared profile — resolves automatically after module updates
        $_uamMod = Get-Module -Name UserAdminModule -ListAvailable |
            Sort-Object Version -Descending | Select-Object -First 1
        if ($_uamMod) {
            $_uamShared = Join-Path $_uamMod.ModuleBase 'profiles\SharedPowershellProfile.ps1'
            if (Test-Path $_uamShared) { . $_uamShared }
        }
        Remove-Variable _uamMod, _uamShared -ErrorAction SilentlyContinue

    Windows PowerShell 5.1 — same block, but loads SharedWindowsPowershellProfile.ps1.
    The correct file is chosen automatically based on $PSEdition.

    SharedPowershellProfile.ps1 / SharedWindowsPowershellProfile.ps1 adds:
      - PSReadLine history prediction + F1 context help
      - Console sizing (Set-ConsoleConfig)
      - Notepad++ alias
      - Startup timer
      - Graceful degradation if module is not installed
#>

# ── Load UserAdminModule ───────────────────────────────────────────────────────
# Loads Shell submodule globally — Set-PromptisAdmin, Show-IsAdminOrNot, etc.
# are available immediately after this line without any Import-PersonalModules call.
Import-Module UserAdminModule -Force -DisableNameChecking -ErrorAction SilentlyContinue

# ── Shell UX — provided by the bundled Shell submodule ────────────────────────
Show-IsAdminOrNot
Set-PromptisAdmin
New-Greeting
Set-ConsoleConfig -WindowHeight 45 -WindowWidth 220

# ── (Optional) Load additional submodule categories on startup ────────────────
# Tab-completion discovers available categories dynamically.
# Import-PersonalModules -Category ADFunctions
# Import-PersonalModules -Category Exchange

# ── (Optional) Aliases ────────────────────────────────────────────────────────
New-Alias -Name 'Notepad++' -Value 'C:\Program Files\Notepad++\notepad++.exe' `
    -Description 'Launch Notepad++' -ErrorAction SilentlyContinue

# ── (Optional) Set F1 key to open help for the current command ────────────────
if (Get-Module -ListAvailable -Name PSReadLine) {
    Set-PSReadLineKeyHandler -Key F1 `
        -BriefDescription CommandHelp `
        -LongDescription 'Open the help window for the command at the cursor position' `
        -ScriptBlock {
        param($key, $arg)

        $ast = $null
        $tokens = $null
        $errors = $null
        $cursor = $null
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
