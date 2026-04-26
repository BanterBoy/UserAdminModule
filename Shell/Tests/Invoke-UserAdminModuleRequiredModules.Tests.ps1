#Requires -Modules Pester

BeforeAll {
    . "$PSScriptRoot/../Public/Invoke-UserAdminModuleRequiredModules.ps1"
}

Describe 'Invoke-UserAdminModuleRequiredModules' {
    Context 'Parameter validation' {
        It 'Accepts Action parameter values' {
            $cmd = Get-Command Invoke-UserAdminModuleRequiredModules
            $cmd.Parameters['Action'].Attributes.ValidValues | Should -Be @('Install','Update','Remove')
        }
        It 'Accepts Scope parameter values' {
            $cmd = Get-Command Invoke-UserAdminModuleRequiredModules
            $cmd.Parameters['Scope'].Attributes.ValidValues | Should -Be @('CurrentUser','AllUsers')
        }
    }
    Context 'Module management logic' {
        BeforeEach {
            Mock -CommandName Install-Module -MockWith { $null }
            Mock -CommandName Uninstall-Module -MockWith { $null }
            Mock -CommandName Get-Module -MockWith { @() }
        }
        It 'Returns results for Install action' {
            $result = Invoke-UserAdminModuleRequiredModules -Action Install -Verbose
            $result | Should -Not -BeNullOrEmpty
        }
        It 'Returns results for Update action' {
            $result = Invoke-UserAdminModuleRequiredModules -Action Update -Verbose
            $result | Should -Not -BeNullOrEmpty
        }
        It 'Returns results for Remove action' {
            $result = Invoke-UserAdminModuleRequiredModules -Action Remove -Verbose
            $result | Should -Not -BeNullOrEmpty
        }
    }
}