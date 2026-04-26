function Set-TitleisAdmin {
    <#
    .SYNOPSIS
        Sets the console window title to display the current user, privilege level, and current path.
    .DESCRIPTION
        Retrieves the current user's UPN via whoami.exe (falls back to $env:USERNAME if unavailable)
        and checks elevation via Test-IsAdmin. Sets $host.UI.RawUI.WindowTitle accordingly.
    .EXAMPLE
        Set-TitleisAdmin
        Sets the title to something like: user@domain.com - Admin Privileges - Path: C:\Windows
    .NOTES
        Author:    Luke Leigh
        Tested on: PowerShell 5.1 and 7+
    .LINK
        Test-IsAdmin
        Set-PromptisAdmin
    #>
    [CmdletBinding()]
    param()

    trap {
        Write-Error "Set-TitleisAdmin failed: $_"
        break
    }

    $Username    = whoami.exe /upn 2>$null
    if (-not $Username) { $Username = $env:USERNAME }
    $CurrentPath = $PWD.Path

    if (Test-IsAdmin) {
        $host.UI.RawUI.WindowTitle = "$($Username) - Admin Privileges - Path: $($CurrentPath)"
    }
    else {
        $host.UI.RawUI.WindowTitle = "$($Username) - User Privileges - Path: $($CurrentPath)"
    }
}
