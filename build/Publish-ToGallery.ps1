#requires -Version 5.1
<#
.SYNOPSIS
    Publishes UserAdminModule to the PowerShell Gallery.

.DESCRIPTION
    Creates a clean staging copy of the module (excluding build tools, CI config,
    and generated artefacts) and publishes it to the PowerShell Gallery using
    Publish-PSResource (Microsoft.PowerShell.PSResourceGet). PSResourceGet does not
    use dotnet pack internally and is the modern, reliable replacement for the
    broken Publish-Module / PowerShellGet v2 publish path.

    PSResourceGet is installed automatically if not present.

    Reference: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.psresourceget/publish-psresource

.PARAMETER ApiKey
    Your PowerShell Gallery NuGet API key. Create one at:
    https://www.powershellgallery.com → Sign in → API Keys → Create

.PARAMETER Repository
    The target repository. Defaults to 'PSGallery'.

.PARAMETER Validate
    Runs a pre-flight check without publishing. Builds the staging directory,
    verifies manifest integrity, checks no excluded folders leaked in, and
    confirms FunctionsToExport matches Public\ .ps1 files. No API key required.

.EXAMPLE
    .\build\Publish-ToGallery.ps1 -Validate

    Pre-flight validation — builds staging, verifies contents, prints pass/fail report.
    Safe to run at any time; no publish occurs and no API key is needed.

.EXAMPLE
    .\build\Publish-ToGallery.ps1 -Validate -Verbose

    Pre-flight validation with detailed staging output.

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
    Requires:  Microsoft.PowerShell.PSResourceGet (installed automatically if missing)
    Tested on: PowerShell 5.1 and 7+

    Reference: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.psresourceget/publish-psresource

.LINK
    Publish-PSResource
    Test-ModuleManifest
#>
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Publish')]
param(
    [Parameter(ParameterSetName = 'Publish', Mandatory, HelpMessage = 'PowerShell Gallery NuGet API key.')]
    [ValidateNotNullOrEmpty()]
    [string]$ApiKey,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Repository = 'PSGallery',

    [Parameter(ParameterSetName = 'Validate', Mandatory)]
    [switch]$Validate
)

trap {
    Write-Error "Publish-ToGallery failed: $_"
    break
}

# ── Ensure PSResourceGet is available ─────────────────────────────────────────
# PSResourceGet (Publish-PSResource) does not use dotnet pack internally,
# avoiding the PowerShellGet v2 bug where dotnet.exe pack fails with exit
# code -2147450735 on newer .NET SDKs.
if (-not (Get-Module -Name Microsoft.PowerShell.PSResourceGet -ListAvailable)) {
    Write-Information 'Microsoft.PowerShell.PSResourceGet not found — installing...' -InformationAction Continue
    Install-Module -Name Microsoft.PowerShell.PSResourceGet -Force -AllowClobber -Scope CurrentUser
}
Import-Module -Name Microsoft.PowerShell.PSResourceGet -ErrorAction Stop

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
# Use GetFullPath to expand any 8.3 short names (e.g. LUKELE~1) — dotnet pack fails on 8.3 paths
$stagingBase = Join-Path ([System.IO.Path]::GetFullPath($env:TEMP)) "UAM-publish-$(Get-Date -Format 'yyyyMMddHHmmss')"
$stagingPath = Join-Path $stagingBase 'UserAdminModule'
New-Item -Path $stagingPath -ItemType Directory -Force | Out-Null
Write-Verbose "Staging directory: $($stagingPath)"

# Folders excluded from the PSGallery package
$excludedDirs = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
@('.github', 'build', '.vscode', 'docs') | ForEach-Object { $null = $excludedDirs.Add($_) }

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

# ── Validate (pre-flight check — no publish) ──────────────────────────────────
if ($Validate) {
    $pass   = $true
    $report = [System.Collections.Generic.List[string]]::new()

    $report.Add("  [OK ] Manifest valid: $($manifest.Name) v$($fullVersion)")

    $leaked = Get-ChildItem -Path $stagingPath -Directory |
        Where-Object { $excludedDirs.Contains($_.Name) }
    if ($leaked) {
        $pass = $false
        foreach ($l in $leaked) { $report.Add("  [FAIL] Excluded dir present in staging: $($l.Name)") }
    }
    else {
        $report.Add('  [OK ] No excluded directories present in staging')
    }

    $stagedManifest = Join-Path $stagingPath 'UserAdminModule.psd1'
    if (Test-Path $stagedManifest) {
        $report.Add('  [OK ] Module manifest present in staging')
    }
    else {
        $pass = $false
        $report.Add('  [FAIL] Module manifest NOT found in staging')
    }

    $exportedFns = @($manifest.ExportedFunctions.Keys | Sort-Object)
    $publicPs1   = @(Get-ChildItem -Path (Join-Path $stagingPath 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty BaseName | Sort-Object)
    $missing = @($exportedFns | Where-Object { $_ -notin $publicPs1 })
    $extra   = @($publicPs1   | Where-Object { $_ -notin $exportedFns })
    if ($missing.Count -gt 0) {
        $pass = $false
        foreach ($m in $missing) { $report.Add("  [FAIL] In FunctionsToExport but no .ps1 found: $($m)") }
    }
    if ($extra.Count -gt 0) {
        foreach ($e in $extra) { $report.Add("  [WARN] .ps1 exists but not in FunctionsToExport: $($e)") }
    }
    if ($missing.Count -eq 0 -and $extra.Count -eq 0) {
        $report.Add("  [OK ] FunctionsToExport matches Public\ .ps1 files ($($exportedFns.Count) functions)")
    }

    if ($stagingPath -match '~\d') {
        $pass = $false
        $report.Add('  [FAIL] Staging path contains 8.3 short name — dotnet pack will fail')
        $report.Add("         Path: $($stagingPath)")
    }
    else {
        $report.Add('  [OK ] Staging path is a full long path')
    }

    Write-Information '' -InformationAction Continue
    Write-Information "Pre-flight Validation — UserAdminModule v$($fullVersion)" -InformationAction Continue
    Write-Information ('-' * 60) -InformationAction Continue
    foreach ($line in $report) { Write-Information $line -InformationAction Continue }
    Write-Information ('-' * 60) -InformationAction Continue
    if ($pass) {
        Write-Information '  RESULT: PASS — safe to publish' -InformationAction Continue
    }
    else {
        Write-Information '  RESULT: FAIL — resolve issues above before publishing' -InformationAction Continue
    }
    Write-Information '' -InformationAction Continue

    Remove-Item -Path $stagingBase -Recurse -Force -ErrorAction SilentlyContinue
    return
}

# ── Publish ───────────────────────────────────────────────────────────────────
$publishParams = @{
    Path        = $stagingPath
    ApiKey      = $ApiKey
    Repository  = $Repository
    ErrorAction = 'Stop'
}
if ($PSCmdlet.ShouldProcess("UserAdminModule v$($fullVersion)", "Publish to $($Repository)")) {
    Write-Information "Publishing UserAdminModule v$($fullVersion) to $($Repository)..." -InformationAction Continue
    Publish-PSResource @publishParams
    Write-Information 'Published successfully. View at: https://www.powershellgallery.com/packages/UserAdminModule' -InformationAction Continue
}

# ── Cleanup ───────────────────────────────────────────────────────────────────
Remove-Item -Path $stagingBase -Recurse -Force -ErrorAction SilentlyContinue
Write-Verbose 'Staging directory cleaned up.'
