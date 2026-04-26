function Test-IsAdmin {
    <#
    .SYNOPSIS
        Tests whether the current PowerShell session is running with administrator privileges.
    .DESCRIPTION
        Uses the .NET Security.Principal API to check whether the current Windows identity
        belongs to the built-in Administrators role. Returns a boolean — $true if elevated,
        $false otherwise. Compatible with PowerShell 5.1 and 7+.

        Reference: https://learn.microsoft.com/en-us/dotnet/api/system.security.principal.windowsprincipal.isinrole
    .EXAMPLE
        Test-IsAdmin
        Returns $true if the session is running as administrator, $false if not.
    .EXAMPLE
        if (Test-IsAdmin) { Write-Verbose 'Elevated session confirmed.' }
        Use as a guard clause before performing privileged operations.
    .NOTES
        Author:    Luke Leigh
        Tested on: PowerShell 5.1 and 7+
    .LINK
        Show-IsAdminOrNot
        Set-PromptisAdmin
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    trap {
        Write-Error "Test-IsAdmin failed: $_"
        break
    }

    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
