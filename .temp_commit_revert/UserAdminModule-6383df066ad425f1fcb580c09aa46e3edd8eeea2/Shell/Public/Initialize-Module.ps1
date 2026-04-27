Function Initialize-Module {
    <#
    .SYNOPSIS
        Initialize-Module install and import modules from PowerShell Galllery.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [string]$Module
    )

    $ProgressPreference = "SilentlyContinue"
    $ErrorActionPreference = "SilentlyContinue"
    trap { continue }
    Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials

    Write-Information "Importing $Module module..." -InformationAction Continue

    # If module is imported say that and do nothing
    If (Get-Module | Where-Object { $_.Name -eq $Module }) {
        Write-Information "Module $Module is already imported." -InformationAction Continue
    }
    Else {
        # If module is not imported, but available on disk then import
        If ( [bool](Get-Module -ListAvailable | Where-Object { $_.Name -eq $Module }) )
        {
            $InstalledModuleVersion = (Get-InstalledModule -Name $Module).Version
            $ModuleVersion = (Find-Module -Name $Module).Version
            $ModulePath = (Get-InstalledModule -Name $Module).InstalledLocation
            $ModulePath = (Get-Item -Path $ModulePath).Parent.FullName
            If ([version]$ModuleVersion -gt [version]$InstalledModuleVersion) {
                Update-Module -Name $Module -Force
                Remove-Item -Path $ModulePath\$InstalledModuleVersion -Force -Recurse
                Write-Information "Module $Module was updated." -InformationAction Continue
            }
            Import-Module -Name $Module -Force -Global -DisableNameChecking
            Write-Information "Module $Module was imported." -InformationAction Continue
        }
        Else {
            # Install Nuget
            If (-not(Get-PackageProvider -ListAvailable -Name NuGet)) {
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
                Write-Information "Package provider NuGet was installed." -InformationAction Continue
            }

            # Add the Powershell Gallery as trusted repository
            If ((Get-PSRepository -Name "PSGallery").InstallationPolicy -eq "Untrusted") {
                Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
                Write-Information "PowerShell Gallery is now a trusted repository." -InformationAction Continue
            }

            # Update PowerShellGet
            $InstalledPSGetVersion = (Get-PackageProvider -Name PowerShellGet).Version
            $PSGetVersion = [version](Find-PackageProvider -Name PowerShellGet).Version
            If ($PSGetVersion -gt $InstalledPSGetVersion) {
                Install-PackageProvider -Name PowerShellGet -Force
                Write-Information "PowerShellGet Gallery was updated." -InformationAction Continue
            }

            # If module is not imported, not available on disk, but is in online gallery then install and import
            If (Find-Module -Name $Module | Where-Object { $_.Name -eq $Module }) {
                # Install and import module
                Install-Module -Name $Module -AllowClobber -Force -Scope AllUsers
                Import-Module -Name $Module -Force -Global -DisableNameChecking
                Write-Information "Module $Module was installed and imported." -InformationAction Continue
            }
            Else {
                # If the module is not imported, not available and not in the online gallery then abort
                Write-Error "Module $Module was not imported, not available and not in an online gallery, exiting."
                Exit 1
            }
        }
    }
}
