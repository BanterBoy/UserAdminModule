function Restore-Location {
    <#
    .SYNOPSIS
        Changes the current location back to the previously stored location.

    .DESCRIPTION
        The Restore-Location function pops the last stored location from the stack and changes the current location to it.

    .EXAMPLE
        Restore-Location
        Changes back to the last stored location.

    .NOTES
        Uses a global stack to manage location history shared across all Shell module functions.
    #>

    [CmdletBinding()]
    param ()

    trap {
        Write-Error "Failed to change location back: $_"
        break
    }

    Initialize-LocationStack

    if ($Global:locationStack.Count -eq 0) {
        Write-Warning "No previous location stored."
        return
    }

    $previousLocation = $Global:locationStack.Pop()
    Write-Verbose "Retrieving previous location: $previousLocation"

    # Validate previous location
    if (-not (Test-Path $previousLocation)) {
        Write-Warning "Previous location '$previousLocation' no longer exists. Removing from stack."
        return
    }

    # Change location
    Set-Location $previousLocation
    Write-Verbose "Changed location back to: $previousLocation"
}

