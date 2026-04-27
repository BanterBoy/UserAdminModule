function Get-LocationStack {
    <#
    .SYNOPSIS
        Displays the current location stack.

    .DESCRIPTION
        Shows all stored locations in the navigation stack.

    .EXAMPLE
        Get-LocationStack
        Displays the stack of stored locations.
    #>

    [CmdletBinding()]
    param ()

    Initialize-LocationStack

    if ($Global:locationStack.Count -eq 0) {
        Write-Output "No locations in the stack."
    } else {
        Write-Output "Location Stack (most recent first):"
        $Global:locationStack.ToArray() | ForEach-Object { Write-Output "  $_" }
    }
}
