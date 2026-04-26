function Initialize-LocationStack {
    <#
    .SYNOPSIS
        Initializes the global location stack if it doesn't exist.

    .DESCRIPTION
        Creates a global location stack for storing navigation history.
        This ensures all Shell module functions share the same stack instance.

    .EXAMPLE
        Initialize-LocationStack
        Ensures the global location stack is initialized.

    .NOTES
        This is a private helper function called by public navigation functions.
        The stack is only created once per session.
    #>

    [CmdletBinding()]
    param()

    if (-not (Get-Variable -Name locationStack -Scope Global -ErrorAction SilentlyContinue)) {
        $Global:locationStack = [System.Collections.Generic.Stack[string]]::new()
        Write-Verbose "Initialized global location stack"
    }
}
