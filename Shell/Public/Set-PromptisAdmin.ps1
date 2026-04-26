function Set-TitleisAdmin {
  <#
  .SYNOPSIS
  Sets the console window title to display the current user's username, privileges, and current path.
  
  .DESCRIPTION
  This function sets the console window title to display the current user's username, followed by their privileges (either "Admin Privileges" or "User Privileges"), and the current path.
  
  .PARAMETER None
  This function does not accept any parameters.
  
  .EXAMPLE
  Set-TitleisAdmin
  #>
  $Username = whoami.exe /upn
  $CurrentPath = $PWD.Path

  if (Test-IsAdmin) {
    $host.UI.RawUI.WindowTitle = "$($Username) - Admin Privileges - Path: $($CurrentPath)"
  }	
  else {
    $host.UI.RawUI.WindowTitle = "$($Username) - User Privileges - Path: $($CurrentPath)"
  }	
}

function Set-PromptisAdmin {
  <#
  .SYNOPSIS
  Sets the PowerShell prompt to display whether the current session is running as an administrator or not.
  
  .DESCRIPTION
  This function sets the PowerShell prompt to display "(Admin)" if the current session is running
  as an administrator, or "(User)" if it is not. The window title is also updated with the
  username, privilege level, and current path.

  The prompt function is created as a module-scope-independent scriptblock so that it survives
  module reloads (Import-Module -Force).
  
  .PARAMETER None
  This function has no parameters.
  
  .EXAMPLE
  Set-PromptisAdmin
  This example sets the PowerShell prompt to display whether the current session is running as an administrator or not.
  
  .NOTES
  The prompt function is self-contained and does not depend on any module functions.
  This ensures it survives Shell module reloads without resetting to PS>.
  #>
  if (Test-IsAdmin) {
    Set-Item -Path function:global:prompt -Value ([ScriptBlock]::Create({
      $Username = whoami.exe /upn 2>$null
      if (-not $Username) { $Username = $env:USERNAME }
      $host.UI.RawUI.WindowTitle = "$Username - Admin Privileges - Path: $($PWD.Path)"
      "(Admin) $PWD> "
    }.ToString()))
  }
  else {
    Set-Item -Path function:global:prompt -Value ([ScriptBlock]::Create({
      $Username = whoami.exe /upn 2>$null
      if (-not $Username) { $Username = $env:USERNAME }
      $host.UI.RawUI.WindowTitle = "$Username - User Privileges - Path: $($PWD.Path)"
      "(User) $PWD> "
    }.ToString()))
  }
}
