function Show-IsAdminOrNot {
    <#
    .SYNOPSIS
        Writes whether the current PowerShell session is running with administrator privileges.
    .DESCRIPTION
        Calls Test-IsAdmin and emits a Write-Warning message indicating the privilege level.
        Use this in profile scripts or interactive sessions for a quick elevation check.
    .EXAMPLE
        Show-IsAdminOrNot
        WARNING: Running with Admin Privileges
    .EXAMPLE
        Show-IsAdminOrNot
        WARNING: Running with User Privileges
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
        Write-Error "Show-IsAdminOrNot failed: $_"
        break
    }

    if (Test-IsAdmin) {
        Write-Warning -Message 'Running with Admin Privileges'
    }
    else {
        Write-Warning -Message 'Running with User Privileges'
    }
}
