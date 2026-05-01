<#
.SYNOPSIS
    Opens a new PowerShell or Windows Terminal session with elevated or alternate user context.

.DESCRIPTION
    This function launches a new shell session in various contexts:
    - Standard or elevated (Administrator) PowerShell/PowerShell Core
    - As a different user (with credentials)
    - In Windows Terminal (optionally elevated)
    If the current session is already elevated, a warning is displayed. Robust error handling using trap statements is included for all launch scenarios.

.PARAMETER User
    Specifies the type of shell to start. Valid values: 'PowerShell' (Windows PowerShell), 'pwsh' (PowerShell Core).

.PARAMETER RunAs
    Launches the shell as Administrator. Valid values: 'PowerShellRunAs', 'pwshRunAs'.

.PARAMETER RunAsUser
    Launches the shell as a different user. Valid values: 'PowerShellRunAsUser', 'pwshRunAsUser'.

.PARAMETER Credentials
    Credentials object for RunAsUser. Mandatory when using RunAsUser.

.PARAMETER ForceNewWindow
    Forces the RunAsUser shell to launch in a dedicated console window, which is useful when invoked from hosts that hide child
    process windows such as Stream Deck scripts.

.PARAMETER ShellArgumentList
    Provides additional arguments for the shell executable when using RunAsUser. Combine with ForceNewWindow to control the star
    ted session.

.PARAMETER WindowTitle
    Sets a custom console window title when ForceNewWindow is specified. Defaults to an empty title when omitted.

.PARAMETER Terminal
    Launches the shell in Windows Terminal. Valid values: 'PowerShellTerminal', 'pwshTerminal'.

.PARAMETER TerminalRunAs
    Launches Windows Terminal as Administrator with the specified profile. Valid values: 'PowerShellTerminalRunAs', 'pwshTerminalRunAs'.

.EXAMPLE
    New-Shell -User pwsh
    # Launches a new PowerShell Core shell.

.EXAMPLE
    New-Shell -RunAs PowerShellRunAs
    # Launches a new elevated Windows PowerShell shell.

.EXAMPLE
    New-Shell -RunAsUser pwshRunAsUser -Credentials (Get-Credential)
    # Launches a new PowerShell Core shell as a specified user.

.EXAMPLE
    New-Shell -Terminal pwshTerminal
    # Launches a new PowerShell Core shell in Windows Terminal.

.EXAMPLE
    New-Shell -TerminalRunAs pwshTerminalRunAs
    # Launches a new elevated PowerShell Core shell in Windows Terminal.

.NOTES
    Author: RDGScripts Maintainers
    Date: 2025-09-02
    Prerequisites: PowerShell Core (pwsh.exe) and Windows Terminal (wt.exe) must be installed for respective options.
    Microsoft Docs:
    - Start-Process: https://learn.microsoft.com/powershell/module/microsoft.powershell.management/start-process
    - Windows Terminal: https://learn.microsoft.com/windows/terminal/
#>

function New-Shell {
    [CmdletBinding(DefaultParameterSetName = 'User')]
    [Alias('ns')]
    param (
        [Parameter(ParameterSetName = 'User', Mandatory = $false, Position = 0, HelpMessage = 'Specifies the type of shell to start.')]
        [ValidateSet('PowerShell', 'pwsh')]
        [string]
        $User,

        [Parameter(ParameterSetName = 'RunAs', Mandatory = $false, Position = 0, HelpMessage = 'Specifies to run the shell as an administrator.')]
        [ValidateSet('PowerShellRunAs', 'pwshRunAs')]
        [string]
        $RunAs,

        [Parameter(ParameterSetName = 'RunAsUser', Mandatory = $false, Position = 0, HelpMessage = 'Specifies to run the shell as a different user.')]
        [ValidateSet('PowerShellRunAsUser', 'pwshRunAsUser')]
        [string]
        $RunAsUser,

        [Parameter(ParameterSetName = 'RunAsUser', Mandatory = $true, Position = 1, HelpMessage = 'Specifies the credentials to use for the RunAsUser parameter.')]
        [ValidateNotNull()]
        [pscredential]
        $Credentials,

        [Parameter(ParameterSetName = 'RunAsUser', Mandatory = $false, HelpMessage = 'Forces the shell to launch in a new window when running as another user.')]
        [switch]
        $ForceNewWindow,

        [Parameter(ParameterSetName = 'RunAsUser', Mandatory = $false, HelpMessage = 'Specifies additional arguments for the shell when running as another user.')]
        [string[]]
        $ShellArgumentList,

        [Parameter(ParameterSetName = 'RunAsUser', Mandatory = $false, HelpMessage = 'Specifies the window title when a new window is launched for another user.')]
        [string]
        $WindowTitle,

        [Parameter(ParameterSetName = 'Terminal', Mandatory = $false, Position = 0, HelpMessage = 'Specifies to launch the shell in Windows Terminal.')]
        [ValidateSet('PowerShellTerminal', 'pwshTerminal')]
        [string]
        $Terminal,

        [Parameter(ParameterSetName = 'TerminalRunAs', Mandatory = $false, Position = 0, HelpMessage = 'Specifies to run Windows Terminal as an administrator with the specified profile.')]
        [ValidateSet('PowerShellTerminalRunAs', 'pwshTerminalRunAs')]
        [string]
        $TerminalRunAs
    )

    begin {
        Write-Verbose "Starting New-Shell function with parameter set: $($PSCmdlet.ParameterSetName)"
    }

    process {
        # Error trap for the function
        trap {
            Write-Error "An error occurred in New-Shell: $_"
            break
        }

        # Check for elevation if relevant
        $isElevated = $false
        trap {
            Write-Verbose "Could not determine elevation status: $_"
            $isElevated = $false
            continue
        }
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        $isElevated = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

        # Helper function to resolve an executable to its full path.
        # Returns the absolute path string when found, otherwise $null.
        # ShellExecute (`Start-Process -Verb RunAs`) needs a fully-qualified
        # path or an App Paths registry entry — `pwsh.exe` is not always
        # registered there, so resolving via Get-Command up-front avoids the
        # "system cannot find all the information required" error.
        function Test-Executable {
            param ([string]$Path)
            trap {
                Write-Verbose "Executable not found: $Path"
                return $null
            }
            $cmd = Get-Command -Name $Path -ErrorAction SilentlyContinue |
                Where-Object { $_.CommandType -eq 'Application' } |
                Select-Object -First 1
            if ($cmd -and $cmd.Source) {
                return $cmd.Source
            }
            return $null
        }

        switch ($PSCmdlet.ParameterSetName) {
            'User' {
                if ($isElevated) {
                    Write-Warning "Current session is already elevated."
                }
                switch ($User) {
                    'PowerShell' {
                        $exePath = Test-Executable 'PowerShell.exe'
                        if (-not $exePath) {
                            Write-Error "PowerShell.exe not found."
                            return
                        }
                        trap {
                            Write-Error "Failed to launch PowerShell: $_"
                            break
                        }
                        Start-Process -FilePath $exePath -PassThru
                        Write-Verbose "Launched PowerShell from $exePath."
                    }
                    'pwsh' {
                        $exePath = Test-Executable 'pwsh.exe'
                        if (-not $exePath) {
                            Write-Error "pwsh.exe not found."
                            return
                        }
                        trap {
                            Write-Error "Failed to launch PowerShell Core: $_"
                            break
                        }
                        Start-Process -FilePath $exePath -PassThru
                        Write-Verbose "Launched PowerShell Core from $exePath."
                    }
                    default {
                        Write-Error "Invalid value for -User parameter: $User"
                    }
                }
            }
            'RunAs' {
                if ($isElevated) {
                    Write-Warning "Current session is already elevated."
                }
                switch ($RunAs) {
                    'PowerShellRunAs' {
                        $exePath = Test-Executable 'PowerShell.exe'
                        if (-not $exePath) {
                            Write-Error "PowerShell.exe not found."
                            return
                        }
                        trap {
                            Write-Error "Failed to launch elevated PowerShell: $_"
                            break
                        }
                        # ShellExecute (-Verb RunAs) needs a fully-qualified path or an
                        # App Paths registry entry; pass the resolved Source from Get-Command.
                        Start-Process -FilePath $exePath -Verb RunAs -PassThru
                        Write-Verbose "Launched elevated PowerShell from $exePath."
                    }
                    'pwshRunAs' {
                        $exePath = Test-Executable 'pwsh.exe'
                        if (-not $exePath) {
                            Write-Error "pwsh.exe not found."
                            return
                        }
                        trap {
                            Write-Error "Failed to launch elevated PowerShell Core: $_"
                            break
                        }
                        # ShellExecute (-Verb RunAs) needs a fully-qualified path or an
                        # App Paths registry entry; pwsh.exe is not always registered there
                        # (pass Get-Command's resolved Source to avoid "system cannot find
                        # all the information required").
                        Start-Process -FilePath $exePath -Verb RunAs -PassThru
                        Write-Verbose "Launched elevated PowerShell Core from $exePath."
                    }
                    default {
                        Write-Error "Invalid value for -RunAs parameter: $RunAs"
                    }
                }
            }
            'RunAsUser' {
                if (-not $PSBoundParameters.ContainsKey('Credentials') -or -not $Credentials) {
                    Write-Error "-Credentials parameter is required for -RunAsUser."
                    return
                }

                $shellExecutable = $null
                $shellDescription = $null

                switch ($RunAsUser) {
                    'PowerShellRunAsUser' {
                        if (-not (Test-Executable 'PowerShell.exe')) {
                            Write-Error "PowerShell.exe not found."
                            return
                        }
                        $shellExecutable = 'PowerShell.exe'
                        $shellDescription = 'Windows PowerShell'
                    }
                    'pwshRunAsUser' {
                        if (-not (Test-Executable 'pwsh.exe')) {
                            Write-Error "pwsh.exe not found."
                            return
                        }
                        $shellExecutable = 'pwsh.exe'
                        $shellDescription = 'PowerShell Core'
                    }
                    default {
                        Write-Error "Invalid value for -RunAsUser parameter: $RunAsUser"
                        return
                    }
                }

                $process = $null
                $useForceNewWindow = $PSBoundParameters.ContainsKey('ForceNewWindow') -and $ForceNewWindow.IsPresent

                trap {
                    Write-Error "Failed to launch $shellDescription as specified user: $_"
                    break
                }

                if ($useForceNewWindow) {
                    if (-not (Test-Executable 'cmd.exe')) {
                        Write-Error "cmd.exe not found. Unable to launch a new window."
                        return
                    }

                    $titleValue = '""'
                    if ($PSBoundParameters.ContainsKey('WindowTitle') -and -not [string]::IsNullOrWhiteSpace($WindowTitle)) {
                        $sanitizedTitle = $WindowTitle.Replace('"', "'")
                        $titleValue = '"' + $sanitizedTitle + '"'
                    }

                    $argumentList = New-Object -TypeName 'System.Collections.Generic.List[string]'
                    [void]$argumentList.Add('/c')
                    [void]$argumentList.Add('start')
                    [void]$argumentList.Add($titleValue)
                    [void]$argumentList.Add($shellExecutable)

                    if ($PSBoundParameters.ContainsKey('ShellArgumentList') -and $ShellArgumentList) {
                        foreach ($argument in $ShellArgumentList) {
                            if ([string]::IsNullOrWhiteSpace($argument)) {
                                continue
                            }

                            [void]$argumentList.Add($argument)
                        }
                    }

                    $startProcessParameters = @{
                        FilePath          = 'cmd.exe'
                        ArgumentList      = $argumentList.ToArray()
                        Credential        = $Credentials
                        LoadUserProfile   = $true
                        UseNewEnvironment = $true
                        PassThru          = $true
                    }

                    $process = Start-Process @startProcessParameters
                    Write-Verbose "Launched $shellDescription as specified user in a new console window."
                }
                else {
                    $startProcessParameters = @{
                        FilePath          = $shellExecutable
                        Credential        = $Credentials
                        LoadUserProfile   = $true
                        UseNewEnvironment = $true
                        PassThru          = $true
                    }

                    if ($PSBoundParameters.ContainsKey('ShellArgumentList') -and $ShellArgumentList) {
                        $startProcessParameters['ArgumentList'] = $ShellArgumentList
                    }

                    $process = Start-Process @startProcessParameters
                    Write-Verbose "Launched $shellDescription as specified user."
                }

                if ($null -ne $process) {
                    $process
                }
            }
            'Terminal' {
                if (-not (Test-Executable 'wt.exe')) {
                    Write-Error "wt.exe (Windows Terminal) not found."
                    return
                }
                switch ($Terminal) {
                    'PowerShellTerminal' {
                        trap {
                            Write-Error "Failed to launch Windows PowerShell in Windows Terminal: $_"
                            break
                        }
                        Start-Process -FilePath "wt.exe" -ArgumentList "new-tab -p 'Windows PowerShell'" -PassThru
                        Write-Verbose "Launched Windows PowerShell in Windows Terminal."
                    }
                    'pwshTerminal' {
                        trap {
                            Write-Error "Failed to launch PowerShell Core in Windows Terminal: $_"
                            break
                        }
                        Start-Process -FilePath "wt.exe" -ArgumentList "new-tab -p 'PowerShell'" -PassThru
                        Write-Verbose "Launched PowerShell Core in Windows Terminal."
                    }
                    default {
                        Write-Error "Invalid value for -Terminal parameter: $Terminal"
                    }
                }
            }
            'TerminalRunAs' {
                if (-not (Test-Executable 'wt.exe')) {
                    Write-Error "wt.exe (Windows Terminal) not found."
                    return
                }
                switch ($TerminalRunAs) {
                    'PowerShellTerminalRunAs' {
                        trap {
                            Write-Error "Failed to launch elevated Windows PowerShell in Windows Terminal: $_"
                            break
                        }
                        Start-Process -FilePath "wt.exe" -ArgumentList "new-tab -p 'Windows PowerShell'" -Verb RunAs -PassThru
                        Write-Verbose "Launched elevated Windows PowerShell in Windows Terminal."
                    }
                    'pwshTerminalRunAs' {
                        trap {
                            Write-Error "Failed to launch elevated PowerShell Core in Windows Terminal: $_"
                            break
                        }
                        Start-Process -FilePath "wt.exe" -ArgumentList "new-tab -p 'PowerShell'" -Verb RunAs -PassThru
                        Write-Verbose "Launched elevated PowerShell Core in Windows Terminal."
                    }
                    default {
                        Write-Error "Invalid value for -TerminalRunAs parameter: $TerminalRunAs"
                    }
                }
            }
            default {
                Write-Error "Unknown parameter set: $($PSCmdlet.ParameterSetName)"
            }
        }
    }

    end {
        Write-Verbose "New-Shell function execution completed."
    }
}
