<#
.SYNOPSIS
    Writes whether the current user has local administrator privileges.
.DESCRIPTION
    Invokes Test-IsAdmin and outputs a warning-level message based on the result.
    Assumes Test-IsAdmin exists in the current session or module path.
.EXAMPLE
    Show-IsAdminOrNot
.NOTES
    Output is written via Write-Warning.
.LINK
    https://learn.microsoft.com/powershell/scripting/developer/cmdlet/about-cmdlet-binding
#>
function Show-IsAdminOrNot {
    $IsAdmin = Test-IsAdmin
    if ( $IsAdmin -eq "False") {
        Write-Warning -Message "Admin Privileges!"
    }
    else {
        Write-Warning -Message "User Privileges"
    }
}
