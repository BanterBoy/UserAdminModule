function Set-PromptisAdmin {
    <#
    .SYNOPSIS
        Sets the global PowerShell prompt to reflect whether the session is elevated.
    .DESCRIPTION
        Installs a global prompt function that displays "(Admin)" or "(User)" before the current
        path, and simultaneously updates the console window title with the username, privilege
        level, and path. The prompt ScriptBlock is self-contained so that it survives module
        reloads (Import-Module -Force) without reverting to the default PS> prompt.
    .EXAMPLE
        Set-PromptisAdmin
        Installs the custom prompt. Subsequent prompt renders show: (Admin) C:\Windows>
    .NOTES
        Author:    Luke Leigh
        Tested on: PowerShell 5.1 and 7+
    .LINK
        Test-IsAdmin
        Set-TitleisAdmin
    #>
    [CmdletBinding()]
    param()

    trap {
        Write-Error "Set-PromptisAdmin failed: $_"
        break
    }

    if (Test-IsAdmin) {
        Set-Item -Path function:global:prompt -Value ([ScriptBlock]::Create(@'
$Username = whoami.exe /upn 2>$null
if (-not $Username) { $Username = $env:USERNAME }
$host.UI.RawUI.WindowTitle = "$($Username) - Admin Privileges - Path: $($PWD.Path)"
"(Admin) $($PWD)> "
'@))
    }
    else {
        Set-Item -Path function:global:prompt -Value ([ScriptBlock]::Create(@'
$Username = whoami.exe /upn 2>$null
if (-not $Username) { $Username = $env:USERNAME }
$host.UI.RawUI.WindowTitle = "$($Username) - User Privileges - Path: $($PWD.Path)"
"(User) $($PWD)> "
'@))
    }
}
