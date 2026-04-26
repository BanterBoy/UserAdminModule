#requires -Version 5.1
<#
.SYNOPSIS
    Publishes UserAdminModule to the PowerShell Gallery.

.DESCRIPTION
    Creates a clean staging copy of the module (excluding build tools, CI config,
    and generated artefacts) and publishes it to the PowerShell Gallery using
    Publish-Module. Supports prerelease publishing automatically when the module
    manifest contains a Prerelease string.

    Reference: https://learn.microsoft.com/en-us/powershell/module/powershellget/publish-module

.PARAMETER ApiKey
    Your PowerShell Gallery NuGet API key. Create one at:
    https://www.powershellgallery.com → Sign in → API Keys → Create

.PARAMETER Repository
    The target repository. Defaults to 'PSGallery'.

.EXAMPLE
    .\build\Publish-ToGallery.ps1 -ApiKey 'oy2abc...'

    Publishes the current version to the PowerShell Gallery.

.EXAMPLE
    .\build\Publish-ToGallery.ps1 -ApiKey 'oy2abc...' -WhatIf

    Dry run — shows what would be published without uploading.

.EXAMPLE
    .\build\Publish-ToGallery.ps1 -ApiKey 'oy2abc...' -Verbose

    Publishes with detailed output.

.NOTES
    Author:    Luke Leigh
    Requires:  PowerShellGet 2.0+ (Install-Module PowerShellGet -Force)
    Tested on: PowerShell 5.1 and 7+

    Reference: https://learn.microsoft.com/en-us/powershell/module/powershellget/publish-module

.LINK
    Publish-Module
    Test-ModuleManifest
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, HelpMessage = 'PowerShell Gallery NuGet API key.')]
    [ValidateNotNullOrEmpty()]
    [string]$ApiKey,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Repository = 'PSGallery'
)

trap {
    Write-Error "Publish-ToGallery failed: $_"
    break
}

# ── Resolve paths ─────────────────────────────────────────────────────────────
$repoRoot     = Split-Path $PSScriptRoot -Parent
$manifestPath = Join-Path $repoRoot 'UserAdminModule.psd1'

if (-not (Test-Path $manifestPath)) {
    Write-Error "Module manifest not found at: $($manifestPath)"
    return
}

# ── Validate manifest ─────────────────────────────────────────────────────────
Write-Verbose "Validating manifest: $($manifestPath)"
$manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
$prerelease = $manifest.PrivateData.PSData.Prerelease
$fullVersion = if ($prerelease) { "$($manifest.Version)-$($prerelease)" } else { $manifest.Version }

Write-Verbose "Module:  $($manifest.Name)"
Write-Verbose "Version: $($fullVersion)"
Write-Verbose "Repo:    $($Repository)"

# ── Build staging directory ───────────────────────────────────────────────────
# Staging folder must be named 'UserAdminModule' so Publish-Module picks up the
# correct module name from the directory name.
$stagingBase = Join-Path $env:TEMP "UAM-publish-$(Get-Date -Format 'yyyyMMddHHmmss')"
$stagingPath = Join-Path $stagingBase 'UserAdminModule'
New-Item -Path $stagingPath -ItemType Directory -Force | Out-Null
Write-Verbose "Staging directory: $($stagingPath)"

# Folders excluded from the PSGallery package
$excludedDirs = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
@('.github', 'build') | ForEach-Object { $null = $excludedDirs.Add($_) }

# File name patterns excluded from the PSGallery package
$excludedPatterns = @(
    '*.Tests.ps1',
    'FunctionIndex.json',
    'FunctionIndex.md',
    'ValidationReport.json',
    'UserAdminModule-Diagram.md',
    'SYNTAX-VALIDATION-REPORT.md',
    '*.png',
    '*.svg',
    '.gitignore'
)

function Test-ExcludedFile {
    param([System.IO.FileInfo]$File)
    foreach ($pattern in $excludedPatterns) {
        if ($File.Name -like $pattern) { return $true }
    }
    return $false
}

# ── Copy module contents to staging ──────────────────────────────────────────
Get-ChildItem -Path $repoRoot -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.PSIsContainer) {
        if (-not $excludedDirs.Contains($_.Name)) {
            Copy-Item -Path $_.FullName -Destination $stagingPath -Recurse -Force
        }
    }
    else {
        if (-not (Test-ExcludedFile -File $_)) {
            Copy-Item -Path $_.FullName -Destination $stagingPath -Force
        }
    }
}

# Remove Tests folders from any submodule copies
Get-ChildItem -Path $stagingPath -Recurse -Directory -Filter 'Tests' -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Write-Verbose "Staging complete. Contents:"
Get-ChildItem -Path $stagingPath | ForEach-Object { Write-Verbose "  $($_.Name)" }

# ── Publish ───────────────────────────────────────────────────────────────────
$publishParams = @{
    Path        = $stagingPath
    NuGetApiKey = $ApiKey
    Repository  = $Repository
    ErrorAction = 'Stop'
    Verbose     = $PSBoundParameters.ContainsKey('Verbose')
}
if ($prerelease) {
    $publishParams['AllowPrerelease'] = $true
}

if ($PSCmdlet.ShouldProcess("UserAdminModule v$($fullVersion)", "Publish to $($Repository)")) {
    Write-Information "Publishing UserAdminModule v$($fullVersion) to $($Repository)..." -InformationAction Continue
    Publish-Module @publishParams
    Write-Information "Published successfully. View at: https://www.powershellgallery.com/packages/UserAdminModule" -InformationAction Continue
}

# ── Cleanup ───────────────────────────────────────────────────────────────────
Remove-Item -Path $stagingBase -Recurse -Force -ErrorAction SilentlyContinue
Write-Verbose 'Staging directory cleaned up.'
