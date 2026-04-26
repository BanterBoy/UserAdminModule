function Invoke-FunctionIndexRegeneration {
    <#
    .SYNOPSIS
        Regenerate function indexes from UserAdminModule source files
    .DESCRIPTION
        Scans the UserAdminModule directory structure to discover all functions in Public folders,
        extracts metadata from comment-based help, and regenerates FunctionIndex.json and 
        FunctionIndex.md to ensure indexes stay synchronized with actual source files.
    .PARAMETER ModulePath
        One or more paths to scan for submodule folders. Each folder that contains a
        Public\ subfolder will be treated as a category. When omitted, the function
        automatically scans both the built-in module root (Shell submodule) and the
        custom modules path stored in config (your AdminFunctions directory).
    .PARAMETER OutputPath
        Path where FunctionIndex.json and FunctionIndex.md are written. Defaults to the
        module root directory.
    .EXAMPLE
        Invoke-FunctionIndexRegeneration -Verbose

        Auto-discovers both the built-in Shell submodule and your AdminFunctions path
        from config and writes FunctionIndex.json to the module root.
    .EXAMPLE
        Invoke-FunctionIndexRegeneration -ModulePath "C:\GitRepos\RDGScripts\AdminFunctions" -Verbose
    .NOTES
        This function is part of the UserAdminModule indexing system.
        Requires PowerShell 5.1 or higher.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$ModulePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath = $(if ($Script:UAMModuleRoot) { $Script:UAMModuleRoot } else { Split-Path $PSScriptRoot -Parent })
    )

    trap {
        Write-Error "Failed to regenerate function indexes: $_"
        break
    }

    # If no path supplied, auto-discover: built-in module root (Shell) + custom path from config
    if (-not $PSBoundParameters.ContainsKey('ModulePath')) {
        $moduleRoot = if ($Script:UAMModuleRoot) { $Script:UAMModuleRoot } else { Split-Path $PSScriptRoot -Parent }
        $ModulePath = @($moduleRoot)
        $config = Get-UserAdminModuleConfig
        if ($config.CustomModulesPath -and (Test-Path $config.CustomModulesPath)) {
            $ModulePath += $config.CustomModulesPath
            Write-Verbose "Auto-discovered custom modules path: $($config.CustomModulesPath)"
        }
    }

    Write-Verbose "Starting index regeneration from: $($ModulePath -join ', ')"

    # Define category descriptions
    $categoryDescriptions = @{
        "ADFunctions"             = "Comprehensive Active Directory tooling spanning user lifecycle, group reconciliation, stale-object hygiene, audit reporting, and deep diagnostics across forests and domains."
        "Azure"                   = "Cloud infrastructure functions for Azure and Microsoft Entra ID management including resource provisioning, identity governance, and application integrations."
        "CertificateUtilities"    = "Public Key Infrastructure utilities for certificate operations, validation, enrollment, and lifecycle management."
        "CiscoSecure"             = "VPN and Cisco Secure endpoint management including failover handling, status monitoring, and security configuration."
        "CustomRDGCommands"       = "Custom infrastructure-specific commands using RDG naming conventions for computer and group management."
        "Database"                = "Database server management and SQL Server operations including queries, backups, and server configuration."
        "EnvironmentManagement"   = "System environment configuration, variable management, and path operations for Windows and PowerShell environments."
        "Exchange"                = "Exchange Server and Microsoft 365 Exchange Online management including mailbox operations, calendar permissions, distribution lists, and email configuration."
        "FileOperations"          = "File and directory manipulation, copying, moving, and resource intensive file system operations."
        "JekyllBlog"              = "Static site generation and Jekyll blog management utilities for documentation and publishing."
        "Logging"                 = "Event logging, audit trail creation, and monitoring operations for system auditing and diagnostics."
        "MediaManagement"         = "Audio and video file processing and management including format conversion and media operations."
        "Network"                 = "Network configuration, connectivity testing, DNS operations, and IP management across enterprise infrastructure."
        "PKICertificateTools"     = "Advanced PKI operations including certificate request automation, ADCS integration, and certificate lifecycle management."
        "PrintManagement"         = "Print spooler and printer queue management including printer configuration and print job operations."
        "ProcessServiceSchedules" = "Windows service and scheduled task management including startup configuration and automation scheduling."
        "RDGAdmin"                = "RDG administration connection orchestration for cloud (lleigh.adm) and on-premises (lukeleigh.admin) admin accounts — Exchange Online, Azure, Teams, Intune, Defender, Security and Compliance, and on-premises Exchange and Active Directory."
        "Registry"                = "Windows registry access, key management, and run-key operations for system configuration."
        "RemoteConnections"       = "Remote desktop, PowerShell remoting, and distributed system connectivity for remote administration."
        "Replication"             = "Active Directory replication monitoring, diagnostics, and troubleshooting across domains and forests."
        "Security"                = "Security configuration, compliance operations, and access control management for infrastructure security."
        "Shell"                   = "PowerShell environment utilities, module management, and scripting helpers for enhanced shell productivity."
        "ShutdownCommands"        = "System shutdown, restart, and power management operations for computer lifecycle management."
        "Teams"                   = "Microsoft Teams management and integration including channel and user administration."
        "Testing"                 = "Test utilities, validation functions, and diagnostic tools for development and operational testing."
        "TimeTools"               = "Time synchronization, NTP configuration, time zone management, and W32Time service operations for system time accuracy."
        "Utilities"               = "General-purpose utility functions for common operations and cross-cutting concerns."
        "Virtualization"          = "Hyper-V and virtual machine management including VM deployment, configuration, and lifecycle operations."
        "Weather"                 = "Weather data retrieval and weather-related utilities for environmental monitoring and integration."
    }

    # Discover all categories and their public functions
    $categories = @{}
    $categoryFolders = foreach ($scanPath in $ModulePath) {
        Get-ChildItem -Path $scanPath -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName 'Public') }
    }

    foreach ($categoryFolder in $categoryFolders) {
        $categoryName = $categoryFolder.Name
        $publicPath = Join-Path $categoryFolder.FullName "Public"
        
        $functions = @()
        $psFiles = Get-ChildItem -Path $publicPath -Filter "*.ps1" -ErrorAction SilentlyContinue
        
        foreach ($file in $psFiles) {
            trap {
                Write-Warning "Failed to parse $($file.Name): $_"
                continue
            }
            
            $content = Get-Content -Path $file.FullName -Raw
            
            # Extract function name from file name (remove .ps1)
            $functionName = $file.BaseName
            
            # Extract .SYNOPSIS from comment-based help
            $synopsis = ""
            if ($content -match '\.SYNOPSIS\s*\n\s*(.+?)(?:\n|$)') {
                $synopsis = $matches[1].Trim()
            }
            
            # Extract .DESCRIPTION - handle multi-line descriptions
            $description = ""
            if ($content -match '\.DESCRIPTION\s*\n\s*((?:[^\.](?!\.(?:PARAMETER|EXAMPLE|NOTES|OUTPUTS|INPUTS|COMPONENT|FUNCTIONALITY))|\.(?!PARAMETER|EXAMPLE|NOTES|OUTPUTS|INPUTS|COMPONENT|FUNCTIONALITY))+)') {
                $desc = $matches[1].Trim()
                # Clean up whitespace while preserving paragraph structure
                $description = ($desc -split '\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Join-String -Separator " ").Trim()
            }
            
            if (-not $synopsis) {
                $synopsis = $functionName
            }
            
            $functions += [PSCustomObject]@{
                Name        = $functionName
                Synopsis    = $synopsis
                Description = $description
                Source      = $file.FullName
            }
        }
        
        if ($functions.Count -gt 0) {
            $categories[$categoryName] = $functions | Sort-Object -Property Name
            Write-Verbose "Found $($functions.Count) functions in $categoryName"
        }
    }

    # Generate JSON index (array format matching original structure)
    $jsonIndex = @()

    foreach ($category in ($categories.Keys | Sort-Object)) {
        $functions = $categories[$category]
        $categoryObj = @{
            Category    = $category
            Description = if ($categoryDescriptions.ContainsKey($category)) { $categoryDescriptions[$category] } else { "" }
            Functions   = @($functions | ForEach-Object { 
                @{
                    Name        = $_.Name
                    Description = $_.Description
                    Source      = $_.Source
                }
            })
        }
        $jsonIndex += $categoryObj
    }

    $jsonPath = Join-Path $OutputPath 'FunctionIndex.json'
    $jsonIndex | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
    Write-Verbose "Generated JSON index at: $($jsonPath)"

    # Generate Markdown index
    $totalFunctions = 0
    foreach ($category in ($categories.Keys | Sort-Object)) {
        $count = $categories[$category].Count
        $totalFunctions += $count
    }

    $markdown = @"
# UserAdminModule Function Index

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")

## Summary

| Category | Count | Link |
|----------|-------|------|
"@

    foreach ($category in ($categories.Keys | Sort-Object)) {
        $count = $categories[$category].Count
        $markdown += "`n| $category | $count | [Jump](#$($category.ToLower())) |"
    }

    $markdown += "`n| **Total** | **$totalFunctions** | |`n"

    # Add category details
    foreach ($category in ($categories.Keys | Sort-Object)) {
        $functions = $categories[$category]
        $desc = if ($categoryDescriptions.ContainsKey($category)) { $categoryDescriptions[$category] } else { "" }
        
        $markdown += "`n`n---`n`n## $category`n`n"
        if ($desc) {
            $markdown += "$desc`n`n"
        }
        
        # Add sub-TOC for functions in this category with unique heading
        $categoryFunctionsAnchor = "$($category.ToLower())-functions" -replace '[^a-z0-9\-]', '-'
        $markdown += "### $category Functions`n`n"
        foreach ($func in $functions) {
            $anchorLink = $func.Name.ToLower() -replace '[^a-z0-9\-]', '-'
            $markdown += "- [$($func.Name)](#$anchorLink)`n"
        }
        $markdown += "`n"
        
        foreach ($func in $functions) {
            $markdown += "### $($func.Name)`n`n"
            if ($func.Synopsis) {
                $markdown += "**Synopsis:** $($func.Synopsis)`n`n"
            }
            if ($func.Description) {
                $markdown += "**Description:** $($func.Description)`n`n"
            }
            $markdown += "**Source:** ``$($func.Source)``  `n`n"
            $markdown += "[⬆ Back to $category functions](#$categoryFunctionsAnchor)  `n`n"
        }
        
        $markdown += "[⬆ Top](#summary)`n"
    }

    $mdPath = Join-Path $OutputPath 'FunctionIndex.md'
    $markdown | Set-Content -Path $mdPath -Encoding UTF8
    Write-Verbose "Generated Markdown index at: $($mdPath)"

    Write-Information "Function index regeneration complete. Total: $totalFunctions functions across $($categories.Count) categories"
}
