<#
.SYNOPSIS
    Generates a self-contained HTML menu app for the UserAdminModule function reference.
.DESCRIPTION
    Reads FunctionIndex.json and each Public function .ps1 file to extract comment-based help,
    then produces a single self-contained HTML file (ModuleMenuApp.html) with an interactive
    two-panel UI: expandable submodule categories on the left, function detail on the right.
.PARAMETER OutputPath
    Path for the generated HTML file. Defaults to the same folder as this script.
.EXAMPLE
    .\New-ModuleMenuApp.ps1
.EXAMPLE
    .\New-ModuleMenuApp.ps1 -OutputPath "C:\Temp\ModuleMenuApp.html"
.NOTES
    Requires the FunctionIndex.json to be present and up-to-date.
    Run Invoke-FunctionIndexRegeneration.ps1 first if needed.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = (Join-Path $PSScriptRoot "ModuleMenuApp.html")
)

trap {
    Write-Error "Failed to generate ModuleMenuApp: $_"
    break
}

$indexPath = Join-Path (Split-Path $PSScriptRoot -Parent) "FunctionIndex.json"

if (-not (Test-Path $indexPath)) {
    Write-Error "FunctionIndex.json not found at $($indexPath). Run Invoke-FunctionIndexRegeneration.ps1 first."
    return
}

Write-Verbose "Loading FunctionIndex.json from $($indexPath)"
$categories = Get-Content $indexPath -Raw | ConvertFrom-Json

function Get-CommentBasedHelp {
    param([string]$FilePath)

    trap {
        Write-Warning "Could not parse help from $($FilePath): $_"
        return @{ Synopsis = ''; Description = ''; Parameters = @(); Examples = @(); Notes = '' }
        continue
    }

    if (-not (Test-Path $FilePath)) {
        return @{ Synopsis = ''; Description = 'Source file not found.'; Parameters = @(); Examples = @(); Notes = '' }
    }

    $raw = Get-Content $FilePath -Raw

    # Extract the comment block <# ... #>
    $helpBlock = ''
    if ($raw -match '(?s)<#(.*?)#>') {
        $helpBlock = $Matches[1]
    }

    # Extract each section
    $synopsis    = if ($helpBlock -match '(?s)\.SYNOPSIS\s*\r?\n(.*?)(?=\.\w|\z)') { $Matches[1].Trim() } else { '' }
    $description = if ($helpBlock -match '(?s)\.DESCRIPTION\s*\r?\n(.*?)(?=\.\w|\z)') { $Matches[1].Trim() } else { '' }
    $notes       = if ($helpBlock -match '(?s)\.NOTES\s*\r?\n(.*?)(?=\.\w|\z)') { $Matches[1].Trim() } else { '' }

    # Extract all parameters
    $paramMatches = [regex]::Matches($helpBlock, '(?s)\.PARAMETER\s+(\S+)\s*\r?\n(.*?)(?=\.PARAMETER|\.EXAMPLE|\.NOTES|\.OUTPUTS|\.INPUTS|\.LINK|\z)')
    $parameters = @()
    foreach ($m in $paramMatches) {
        $parameters += @{
            Name        = $m.Groups[1].Value.Trim()
            Description = $m.Groups[2].Value.Trim()
        }
    }

    # Extract all examples
    $exampleMatches = [regex]::Matches($helpBlock, '(?s)\.EXAMPLE\s*\r?\n(.*?)(?=\.EXAMPLE|\.PARAMETER|\.NOTES|\.OUTPUTS|\.INPUTS|\.LINK|\z)')
    $examples = @()
    foreach ($m in $exampleMatches) {
        $examples += $m.Groups[1].Value.Trim()
    }

    return @{
        Synopsis    = $synopsis
        Description = $description
        Parameters  = $parameters
        Examples    = $examples
        Notes       = $notes
    }
}

Write-Verbose "Parsing help from $($categories.Count) submodules..."

$moduleData = @()
foreach ($cat in $categories) {
    $functions = @()
    foreach ($fn in $cat.Functions) {
        Write-Verbose "  Parsing $($fn.Name)"
        $help = Get-CommentBasedHelp -FilePath $fn.Source
        $functions += @{
            name        = $fn.Name
            description = $fn.Description
            synopsis    = $help.Synopsis
            fullDesc    = $help.Description
            parameters  = $help.Parameters
            examples    = $help.Examples
            notes       = $help.Notes
            source      = $fn.Source
        }
    }
    $moduleData += @{
        category    = $cat.Category
        description = $cat.Description
        functions   = $functions
    }
}

$jsonData = $moduleData | ConvertTo-Json -Depth 10 -Compress

Write-Verbose "Building HTML..."

$htmlTemplate = @'
<!DOCTYPE html>
<!-- MODULE_DATA_PLACEHOLDER will be replaced by PowerShell with the embedded JSON -->
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>UserAdminModule — Function Reference</title>
  <style>
    :root {
      --bg-deep:    #0d1117;
      --bg-panel:   #161b22;
      --bg-card:    #1c2128;
      --bg-hover:   #222d3a;
      --bg-active:  #1f3a5f;
      --accent:     #58a6ff;
      --accent2:    #3fb950;
      --accent3:    #d2a8ff;
      --text:       #e6edf3;
      --text-muted: #8b949e;
      --border:     #30363d;
      --tag-bg:     #21262d;
      --tag-border: #30363d;
      --radius:     8px;
      --sidebar-w:  320px;
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: var(--bg-deep);
      color: var(--text);
      height: 100vh;
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }

    /* ── Header ── */
    header {
      background: var(--bg-panel);
      border-bottom: 1px solid var(--border);
      padding: 12px 20px;
      display: flex;
      align-items: center;
      gap: 14px;
      flex-shrink: 0;
    }
    header .logo {
      width: 32px; height: 32px;
      background: linear-gradient(135deg, var(--accent), var(--accent3));
      border-radius: 6px;
      display: flex; align-items: center; justify-content: center;
      font-size: 18px; font-weight: 700; color: #fff;
    }
    header h1 {
      font-size: 1.1rem;
      font-weight: 600;
      color: var(--accent);
      cursor: pointer;
      text-decoration: none;
      transition: color .15s, opacity .15s;
    }
    header h1:hover { opacity: 0.8; text-decoration: underline; }
    header .subtitle { font-size: 0.8rem; color: var(--text-muted); margin-left: auto; }
    header .count-badge {
      background: var(--bg-active);
      border: 1px solid var(--accent);
      color: var(--accent);
      border-radius: 12px;
      padding: 2px 10px;
      font-size: 0.75rem;
      font-weight: 600;
    }

    /* ── Search bar ── */
    .search-bar {
      padding: 10px 12px;
      background: var(--bg-panel);
      border-bottom: 1px solid var(--border);
      flex-shrink: 0;
    }
    .search-bar input {
      width: 100%;
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: var(--radius);
      color: var(--text);
      padding: 7px 12px 7px 34px;
      font-size: 0.85rem;
      outline: none;
      transition: border-color .2s;
      background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='14' height='14' viewBox='0 0 24 24' fill='none' stroke='%238b949e' stroke-width='2'%3E%3Ccircle cx='11' cy='11' r='8'/%3E%3Cpath d='M21 21l-4.35-4.35'/%3E%3C/svg%3E");
      background-repeat: no-repeat;
      background-position: 11px center;
    }
    .search-bar input:focus { border-color: var(--accent); }

    /* ── Main layout ── */
    .layout {
      display: flex;
      flex: 1;
      overflow: hidden;
    }

    /* ── Sidebar column wrapper ── */
    .sidebar-col {
      display: flex;
      flex-direction: column;
      width: var(--sidebar-w);
      min-width: 240px;
      max-width: 420px;
      flex-shrink: 0;
      overflow: hidden;
      border-right: 1px solid var(--border);
    }

    /* ── Sidebar ── */
    .sidebar {
      flex: 1;
      background: var(--bg-panel);
      overflow-y: auto;
      min-height: 0;
    }
    .sidebar::-webkit-scrollbar { width: 6px; }
    .sidebar::-webkit-scrollbar-track { background: transparent; }
    .sidebar::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }

    /* Category headers */
    .category-header {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 10px 14px;
      cursor: pointer;
      border-bottom: 1px solid var(--border);
      transition: background .15s;
      user-select: none;
    }
    .category-header:hover { background: var(--bg-hover); }
    .category-header.active { background: var(--bg-hover); }
    .category-icon {
      width: 28px; height: 28px; border-radius: 6px;
      display: flex; align-items: center; justify-content: center;
      font-size: 13px; flex-shrink: 0;
    }
    .category-name {
      flex: 1;
      font-size: 0.87rem;
      font-weight: 600;
      color: var(--text);
    }
    .category-count {
      font-size: 0.72rem;
      background: var(--tag-bg);
      border: 1px solid var(--tag-border);
      color: var(--text-muted);
      border-radius: 10px;
      padding: 1px 8px;
    }
    .chevron {
      font-size: 10px;
      color: var(--text-muted);
      transition: transform .2s;
      flex-shrink: 0;
    }
    .category-header.open .chevron { transform: rotate(90deg); }

    /* Function list */
    .function-list {
      display: none;
      background: var(--bg-deep);
      border-bottom: 1px solid var(--border);
    }
    .function-list.open { display: block; }
    .function-item {
      padding: 7px 14px 7px 50px;
      font-size: 0.82rem;
      color: var(--text-muted);
      cursor: pointer;
      transition: background .1s, color .1s;
      border-left: 3px solid transparent;
    }
    .function-item:hover { background: var(--bg-hover); color: var(--text); }
    .function-item.selected {
      background: var(--bg-active);
      color: var(--accent);
      border-left-color: var(--accent);
      font-weight: 600;
    }
    .no-results {
      padding: 12px 14px;
      font-size: 0.82rem;
      color: var(--text-muted);
      font-style: italic;
    }

    /* ── Detail pane ── */
    .detail {
      flex: 1;
      overflow-y: auto;
      padding: 28px 32px;
      background: var(--bg-deep);
    }
    .detail::-webkit-scrollbar { width: 6px; }
    .detail::-webkit-scrollbar-track { background: transparent; }
    .detail::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }

    .welcome {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100%;
      text-align: center;
      color: var(--text-muted);
      gap: 12px;
    }
    .welcome-icon { font-size: 48px; opacity: .4; }
    .welcome h2 { font-size: 1.2rem; font-weight: 500; color: var(--text); }
    .welcome p { font-size: 0.85rem; max-width: 380px; line-height: 1.6; }

    /* Function detail */
    .fn-header { margin-bottom: 20px; }
    .fn-name {
      font-size: 1.5rem;
      font-weight: 700;
      color: var(--accent);
      font-family: "Cascadia Code", "Consolas", monospace;
      word-break: break-all;
    }
    .fn-module-badge {
      display: inline-block;
      margin-top: 6px;
      background: var(--bg-active);
      border: 1px solid var(--accent);
      color: var(--accent);
      border-radius: 12px;
      padding: 2px 12px;
      font-size: 0.75rem;
      font-weight: 600;
    }
    .fn-synopsis {
      margin-top: 10px;
      font-size: 0.95rem;
      color: var(--text);
      line-height: 1.6;
      font-style: italic;
    }

    .section {
      margin-top: 24px;
    }
    .section-title {
      font-size: 0.72rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: .08em;
      color: var(--accent2);
      margin-bottom: 10px;
      padding-bottom: 6px;
      border-bottom: 1px solid var(--border);
    }
    .section-body {
      font-size: 0.88rem;
      color: var(--text-muted);
      line-height: 1.75;
      white-space: pre-wrap;
    }

    /* Parameters table */
    .param-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.84rem;
    }
    .param-table th {
      text-align: left;
      padding: 8px 12px;
      background: var(--bg-card);
      color: var(--text-muted);
      font-size: 0.75rem;
      text-transform: uppercase;
      letter-spacing: .05em;
      border-bottom: 1px solid var(--border);
    }
    .param-table td {
      padding: 8px 12px;
      border-bottom: 1px solid var(--border);
      vertical-align: top;
    }
    .param-table tr:last-child td { border-bottom: none; }
    .param-name {
      color: var(--accent3);
      font-family: "Cascadia Code", "Consolas", monospace;
      font-weight: 600;
      white-space: nowrap;
    }
    .param-desc { color: var(--text-muted); line-height: 1.6; }

    /* Examples */
    .example-block {
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: var(--radius);
      padding: 14px 16px;
      margin-bottom: 12px;
      font-family: "Cascadia Code", "Consolas", monospace;
      font-size: 0.82rem;
      color: var(--text);
      white-space: pre-wrap;
      word-break: break-all;
      position: relative;
    }
    .example-num {
      position: absolute;
      top: 8px; right: 12px;
      font-size: 0.7rem;
      color: var(--text-muted);
      font-family: sans-serif;
    }

    /* Source path */
    .source-path {
      font-family: "Cascadia Code", "Consolas", monospace;
      font-size: 0.75rem;
      color: var(--text-muted);
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: var(--radius);
      padding: 8px 12px;
      word-break: break-all;
    }

    /* Empty state badge */
    .empty-section {
      color: var(--text-muted);
      font-style: italic;
      font-size: 0.84rem;
    }
  </style>
</head>
<body>

<header>
  <div class="logo">&#9881;</div>
  <h1 id="homeBtn" title="Back to overview">UserAdminModule &mdash; Function Reference</h1>
  <span class="count-badge" id="totalBadge"></span>
  <span class="subtitle">PowerShell Module Viewer</span>
  <button onclick="showSetupGuide()" style="margin-left:16px;flex-shrink:0;background:var(--accent);color:#000;border:none;border-radius:var(--radius);padding:8px 16px;font-size:0.8rem;font-weight:700;cursor:pointer;white-space:nowrap;transition:opacity .15s;" onmouseover="this.style.opacity='.85'" onmouseout="this.style.opacity='1'">
    &#128196; Get Started
  </button>
</header>

<div class="layout">
  <!-- ── Sidebar ── -->
  <div class="sidebar-col">
    <div class="search-bar">
      <input type="text" id="searchInput" placeholder="Search functions…" autocomplete="off" />
    </div>
    <div class="sidebar" id="sidebar"></div>
  </div>

  <!-- ── Detail pane ── -->
  <div class="detail" id="detail">
    <div class="welcome">
      <div class="welcome-icon">&#128196;</div>
      <h2>UserAdminModule Function Reference</h2>
      <p>Select a submodule from the left panel to browse functions, then click a function to view its full help documentation.</p>
    </div>
  </div>
</div>

<!-- ── Setup Guide Modal ── -->
<div id="setupModal" style="display:none;position:fixed;inset:0;background:rgba(0,0,0,.75);z-index:1000;overflow-y:auto;padding:40px 20px;">
  <div style="max-width:720px;margin:0 auto;background:var(--bg-card);border:1px solid var(--border);border-radius:10px;padding:36px 40px;position:relative;">
    <button onclick="document.getElementById('setupModal').style.display='none'" style="position:absolute;top:16px;right:20px;background:none;border:none;color:var(--text-muted);font-size:1.4rem;cursor:pointer;line-height:1;" title="Close">&times;</button>

    <div style="font-size:1.4rem;font-weight:700;color:var(--accent);font-family:'Cascadia Code','Consolas',monospace;margin-bottom:6px;">Getting Started</div>
    <div style="color:var(--text-muted);font-size:0.88rem;margin-bottom:28px;">How to set up UserAdminModule in your PowerShell profile</div>

    <!-- Step 1 -->
    <div style="margin-bottom:24px;">
      <div style="font-size:0.72rem;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:var(--accent2);margin-bottom:10px;">Step 1 — Prerequisites</div>
      <ul style="margin:0;padding-left:20px;color:var(--text);font-size:0.88rem;line-height:1.9;">
        <li>PowerShell <strong>5.1</strong> (Windows) or <strong>7+</strong> (cross-platform)</li>
        <li><strong>Git</strong> installed — <a href="https://git-scm.com/downloads" target="_blank" style="color:var(--accent);">git-scm.com</a></li>
        <li>A local folder for your repos, e.g. <code style="background:var(--bg-active);padding:1px 6px;border-radius:3px;">C:\GitRepos\</code></li>
      </ul>
    </div>

    <!-- Step 2 -->
    <div style="margin-bottom:24px;">
      <div style="font-size:0.72rem;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:var(--accent2);margin-bottom:10px;">Step 2 — Clone the Repository</div>
      <div style="font-size:0.85rem;color:var(--text);margin-bottom:8px;">Open a terminal and run:</div>
      <pre style="background:var(--bg-active);border:1px solid var(--border);border-radius:6px;padding:14px 16px;font-size:0.82rem;color:var(--accent);overflow-x:auto;margin:0;">git clone https://github.com/BanterBoy/RDGScripts.git C:\GitRepos\RDGScripts</pre>
    </div>

    <!-- Step 3 -->
    <div style="margin-bottom:24px;">
      <div style="font-size:0.72rem;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:var(--accent2);margin-bottom:10px;">Step 3 — Check / Create Your Profile</div>
      <div style="font-size:0.85rem;color:var(--text);margin-bottom:8px;">Check whether a profile file already exists:</div>
      <pre style="background:var(--bg-active);border:1px solid var(--border);border-radius:6px;padding:14px 16px;font-size:0.82rem;color:var(--accent);overflow-x:auto;margin:0 0 10px 0;">Test-Path $PROFILE</pre>
      <div style="font-size:0.85rem;color:var(--text);margin-bottom:8px;">If it returns <code style="background:var(--bg-active);padding:1px 6px;border-radius:3px;">False</code>, create it:</div>
      <pre style="background:var(--bg-active);border:1px solid var(--border);border-radius:6px;padding:14px 16px;font-size:0.82rem;color:var(--accent);overflow-x:auto;margin:0;">New-Item -ItemType File -Path $PROFILE -Force</pre>
    </div>

    <!-- Step 4 -->
    <div style="margin-bottom:24px;">
      <div style="font-size:0.72rem;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:var(--accent2);margin-bottom:10px;">Step 4 — Configure Your Profile</div>
      <div style="font-size:0.85rem;color:var(--text);margin-bottom:8px;">Add the appropriate dot-source line to your <code style="background:var(--bg-active);padding:1px 6px;border-radius:3px;">$PROFILE</code>:</div>

      <div style="font-size:0.78rem;color:var(--text-muted);margin:12px 0 4px;text-transform:uppercase;letter-spacing:.04em;">PowerShell 7+ (pwsh)</div>
      <pre style="background:var(--bg-active);border:1px solid var(--border);border-radius:6px;padding:14px 16px;font-size:0.82rem;color:var(--accent);overflow-x:auto;margin:0 0 14px 0;"># Add to your $PROFILE
. C:\GitRepos\RDGScripts\SharedPowershellProfle.ps1</pre>

      <div style="font-size:0.78rem;color:var(--text-muted);margin:0 0 4px;text-transform:uppercase;letter-spacing:.04em;">Windows PowerShell 5.1</div>
      <pre style="background:var(--bg-active);border:1px solid var(--border);border-radius:6px;padding:14px 16px;font-size:0.82rem;color:var(--accent);overflow-x:auto;margin:0;">. C:\GitRepos\RDGScripts\SharedWindowsPowershellProfle.ps1</pre>

      <div style="margin-top:12px;font-size:0.82rem;color:var(--text-muted);">
        To open your profile in Notepad for editing, run: <code style="background:var(--bg-active);padding:1px 6px;border-radius:3px;color:var(--accent);">notepad $PROFILE</code>
      </div>
    </div>

    <!-- Step 5 -->
    <div style="margin-bottom:28px;">
      <div style="font-size:0.72rem;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:var(--accent2);margin-bottom:10px;">Step 5 — Reload &amp; Verify</div>
      <div style="font-size:0.85rem;color:var(--text);margin-bottom:8px;">Reload your profile in the current session:</div>
      <pre style="background:var(--bg-active);border:1px solid var(--border);border-radius:6px;padding:14px 16px;font-size:0.82rem;color:var(--accent);overflow-x:auto;margin:0 0 10px 0;">. $PROFILE</pre>
      <div style="font-size:0.85rem;color:var(--text);margin-bottom:8px;">Confirm the module loaded successfully:</div>
      <pre style="background:var(--bg-active);border:1px solid var(--border);border-radius:6px;padding:14px 16px;font-size:0.82rem;color:var(--accent);overflow-x:auto;margin:0;">Get-Module -Name UserAdminModule* | Select-Object Name, Version</pre>
    </div>

    <!-- Note -->
    <div style="background:var(--bg-active);border-left:3px solid var(--accent2);border-radius:4px;padding:12px 16px;font-size:0.83rem;color:var(--text-muted);line-height:1.7;">
      <strong style="color:var(--text);">&#128161; Tip:</strong>
      Once loaded, run <code style="color:var(--accent);">Open-ModuleMenuApp</code> (alias: <code style="color:var(--accent);">omma</code>) at any time to open this Function Reference in your browser.
      Use <code style="color:var(--accent);">Open-ModuleMenuApp -Regenerate</code> to rebuild it after adding new functions.
    </div>

    <div style="margin-top:24px;text-align:right;">
      <button onclick="document.getElementById('setupModal').style.display='none'" style="background:var(--accent);color:#000;border:none;border-radius:var(--radius);padding:10px 24px;font-size:0.85rem;font-weight:700;cursor:pointer;">
        Close
      </button>
    </div>
  </div>
</div>

<script>
const MODULE_DATA = __MODULE_DATA_PLACEHOLDER__;

// ── Build sidebar ──
function buildSidebar() {
  const sidebar = document.getElementById('sidebar');
  sidebar.innerHTML = '';

  let totalVisible = 0;

  MODULE_DATA.forEach((cat, ci) => {
    const fns = cat.functions;

    totalVisible += fns.length;

    const catEl = document.createElement('div');

    const hdr = document.createElement('div');
    hdr.className = 'category-header';
    hdr.dataset.ci = ci;
    hdr.innerHTML = `
      <div class="category-icon" style="background:${catColor(ci)}22;color:${catColor(ci)}">${catIcon(cat.category)}</div>
      <span class="category-name">${cat.category}</span>
      <span class="category-count">${fns.length}</span>
      <span class="chevron">&#9654;</span>`;

    const list = document.createElement('div');
    list.className = 'function-list';

    if (fns.length === 0) {
      list.innerHTML = '<div class="no-results">No matching functions</div>';
    } else {
      fns.forEach(fn => {
        const item = document.createElement('div');
        item.className = 'function-item';
        item.textContent = fn.name;
        item.dataset.fnName = fn.name;
        item.dataset.ci = ci;
        item.addEventListener('click', e => { e.stopPropagation(); showFunction(fn, cat.category); selectItem(item); });
        list.appendChild(item);
      });
    }

    hdr.addEventListener('click', () => {
      const isOpen = list.classList.contains('open');
      hdr.classList.toggle('open', !isOpen);
      hdr.classList.toggle('active', !isOpen);
      list.classList.toggle('open', !isOpen);
      showSubmodule(cat, ci);
    });

    catEl.appendChild(hdr);
    catEl.appendChild(list);
    sidebar.appendChild(catEl);
  });

  document.getElementById('totalBadge').textContent =
    totalVisible + ' functions';
}

function catColor(i) {
  const palette = ['#58a6ff','#3fb950','#d2a8ff','#ffa657','#ff7b72','#79c0ff','#56d364','#e3b341'];
  return palette[i % palette.length];
}

function catIcon(name) {
  const icons = {
    ADFunctions:'&#128101;', Azure:'&#9729;', CertificateUtilities:'&#128273;',
    CiscoSecure:'&#128274;', CustomRDGCommands:'&#9881;', Database:'&#128451;',
    EnvironmentManagement:'&#127760;', Exchange:'&#9993;', FileOperations:'&#128196;',
    JekyllBlog:'&#9997;', Logging:'&#128220;', MediaManagement:'&#127916;',
    Network:'&#127760;', PKICertificateTools:'&#128272;', PrintManagement:'&#128438;',
    ProcessServiceSchedules:'&#9200;', RDGAdmin:'&#128736;', Registry:'&#128268;',
    RemoteConnections:'&#128187;', Replication:'&#128260;', Reporting:'&#128202;',
    Security:'&#128737;', Shell:'&#9000;', ShutdownCommands:'&#9211;',
    Teams:'&#128172;', Testing:'&#9989;', TimeTools:'&#128336;',
    Utilities:'&#128295;', Virtualization:'&#128442;', Weather:'&#127780;'
  };
  return icons[name] || '&#128196;';
}

// ── Show function detail ──
function showFunction(fn, category) {
  const detail = document.getElementById('detail');

  const esc = s => (s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');

  const paramsHtml = fn.parameters && fn.parameters.length
    ? `<table class="param-table">
        <thead><tr><th>Parameter</th><th>Description</th></tr></thead>
        <tbody>
          ${fn.parameters.map(p => `<tr>
            <td class="param-name">-${esc(p.Name||p.name)}</td>
            <td class="param-desc">${esc(p.Description||p.description)}</td>
          </tr>`).join('')}
        </tbody>
       </table>`
    : '<div class="empty-section">No parameters documented.</div>';

  const examplesHtml = fn.examples && fn.examples.length
    ? fn.examples.map((ex, i) => `<div class="example-block"><span class="example-num">Example ${i+1}</span>${esc(ex)}</div>`).join('')
    : '<div class="empty-section">No examples documented.</div>';

  const descHtml = fn.fullDesc || fn.description
    ? `<div class="section-body">${esc(fn.fullDesc || fn.description)}</div>`
    : '<div class="empty-section">No description available.</div>';

  const notesHtml = fn.notes
    ? `<div class="section-body">${esc(fn.notes)}</div>`
    : '';

  detail.innerHTML = `
    <div class="fn-header">
      <div class="fn-name">${esc(fn.name)}</div>
      <span class="fn-module-badge">${esc(category)}</span>
      ${fn.synopsis ? `<div class="fn-synopsis">${esc(fn.synopsis)}</div>` : ''}
    </div>

    <div class="section">
      <div class="section-title">Description</div>
      ${descHtml}
    </div>

    <div class="section">
      <div class="section-title">Parameters</div>
      ${paramsHtml}
    </div>

    <div class="section">
      <div class="section-title">Examples</div>
      ${examplesHtml}
    </div>

    ${notesHtml ? `<div class="section"><div class="section-title">Notes</div><div class="section-body">${esc(fn.notes)}</div></div>` : ''}

    <div class="section">
      <div class="section-title">Source</div>
      <div class="source-path">${esc(fn.source)}</div>
    </div>`;
}

function selectItem(el) {
  document.querySelectorAll('.function-item.selected').forEach(e => e.classList.remove('selected'));
  el.classList.add('selected');
}

// ── Submodule dashboard ──
function showSubmodule(cat, ci) {
  document.querySelectorAll('.function-item.selected').forEach(e => e.classList.remove('selected'));
  const detail = document.getElementById('detail');
  const color = catColor(ci);
  const withExamples = cat.functions.filter(f => f.examples && f.examples.length > 0).length;
  const withParams   = cat.functions.filter(f => f.parameters && f.parameters.length > 0).length;
  const withSynopsis = cat.functions.filter(f => f.synopsis && f.synopsis.length > 0).length;

  const fnRows = cat.functions.map(fn => {
    const esc = s => (s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
    const hasEx = fn.examples && fn.examples.length > 0;
    const hasPa = fn.parameters && fn.parameters.length > 0;
    return `<tr style="cursor:pointer;" onclick="(function(){
      document.querySelectorAll('.function-item').forEach(el=>{
        if(el.dataset.fnName==='${fn.name.replace(/'/g,"\\'")}'){el.click();}
      });
    })()">
      <td style="padding:7px 12px;white-space:nowrap;font-family:'Cascadia Code','Consolas',monospace;color:${color};font-size:0.82rem;font-weight:600;">${esc(fn.name)}</td>
      <td style="padding:7px 12px;color:var(--text-muted);font-size:0.82rem;line-height:1.5;">${esc(fn.synopsis || fn.description || '')}</td>
      <td style="padding:7px 12px;text-align:center;">
        ${hasEx ? '<span style="color:var(--accent2);font-size:0.8rem;" title="Has examples">&#10003;</span>' : '<span style="color:var(--border);font-size:0.8rem;">&#8212;</span>'}
      </td>
      <td style="padding:7px 12px;text-align:center;">
        ${hasPa ? '<span style="color:var(--accent2);font-size:0.8rem;" title="Has parameters">&#10003;</span>' : '<span style="color:var(--border);font-size:0.8rem;">&#8212;</span>'}
      </td>
    </tr>`;
  }).join('');

  const esc = s => (s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');

  detail.innerHTML = `
    <div style="max-width:900px;">
      <div style="margin-bottom:22px;">
        <div style="display:flex;align-items:center;gap:12px;margin-bottom:8px;">
          <div style="width:36px;height:36px;border-radius:8px;background:${color}22;color:${color};display:flex;align-items:center;justify-content:center;font-size:20px;">${catIcon(cat.category)}</div>
          <div style="font-size:1.5rem;font-weight:700;color:${color};font-family:'Cascadia Code','Consolas',monospace;">${esc(cat.category)}</div>
        </div>
        <div style="font-size:0.92rem;color:var(--text);line-height:1.75;margin-bottom:16px;">${esc(cat.description || '')}</div>
        <div style="display:flex;gap:12px;flex-wrap:wrap;">
          <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius);padding:12px 18px;text-align:center;min-width:100px;">
            <div style="font-size:1.6rem;font-weight:700;color:${color};">${cat.functions.length}</div>
            <div style="font-size:0.72rem;color:var(--text-muted);text-transform:uppercase;letter-spacing:.06em;">Functions</div>
          </div>
          <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius);padding:12px 18px;text-align:center;min-width:100px;">
            <div style="font-size:1.6rem;font-weight:700;color:var(--accent2);">${withExamples}</div>
            <div style="font-size:0.72rem;color:var(--text-muted);text-transform:uppercase;letter-spacing:.06em;">With Examples</div>
          </div>
          <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius);padding:12px 18px;text-align:center;min-width:100px;">
            <div style="font-size:1.6rem;font-weight:700;color:#ffa657;">${withParams}</div>
            <div style="font-size:0.72rem;color:var(--text-muted);text-transform:uppercase;letter-spacing:.06em;">With Params</div>
          </div>
          <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius);padding:12px 18px;text-align:center;min-width:100px;">
            <div style="font-size:1.6rem;font-weight:700;color:var(--accent3);">${withSynopsis}</div>
            <div style="font-size:0.72rem;color:var(--text-muted);text-transform:uppercase;letter-spacing:.06em;">Documented</div>
          </div>
        </div>
      </div>

      <div style="font-size:0.72rem;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:var(--accent2);margin-bottom:10px;padding-bottom:6px;border-bottom:1px solid var(--border);">
        Functions in ${esc(cat.category)}
      </div>
      <table style="width:100%;border-collapse:collapse;">
        <thead>
          <tr style="border-bottom:1px solid var(--border);">
            <th style="text-align:left;padding:8px 12px;font-size:0.73rem;text-transform:uppercase;letter-spacing:.05em;color:var(--text-muted);white-space:nowrap;">Function</th>
            <th style="text-align:left;padding:8px 12px;font-size:0.73rem;text-transform:uppercase;letter-spacing:.05em;color:var(--text-muted);">Synopsis</th>
            <th style="text-align:center;padding:8px 12px;font-size:0.73rem;text-transform:uppercase;letter-spacing:.05em;color:var(--text-muted);">Examples</th>
            <th style="text-align:center;padding:8px 12px;font-size:0.73rem;text-transform:uppercase;letter-spacing:.05em;color:var(--text-muted);">Params</th>
          </tr>
        </thead>
        <tbody style="background:var(--bg-card);">
          ${fnRows}
        </tbody>
      </table>
      <div style="margin-top:8px;font-size:0.75rem;color:var(--text-muted);">Click any row to view the full function help.</div>
    </div>`;
}

// ── Home dashboard ──
function showHome() {
  document.querySelectorAll('.function-item.selected').forEach(e => e.classList.remove('selected'));
  const detail = document.getElementById('detail');
  const total = MODULE_DATA.reduce((s, c) => s + c.functions.length, 0);

  const catRows = MODULE_DATA
    .slice()
    .sort((a, b) => a.category.localeCompare(b.category))
    .map((c, i) => {
      const docCount = c.functions.filter(f => f.synopsis && f.synopsis.length > 0).length;
      const docPct   = c.functions.length > 0 ? Math.round((docCount / c.functions.length) * 100) : 0;
      const barColor = docPct >= 80 ? 'var(--accent2)' : docPct >= 50 ? '#e3b341' : '#ff7b72';
      return `<tr>
        <td style="padding:7px 12px;white-space:nowrap;vertical-align:top;">
          <span style="color:${catColor(MODULE_DATA.indexOf(c))};font-size:1rem;margin-right:6px;">${catIcon(c.category)}</span>
          <strong style="color:var(--text);font-size:0.85rem;">${c.category}</strong>
        </td>
        <td style="padding:7px 12px;color:var(--text-muted);font-size:0.83rem;vertical-align:top;">${c.description || ''}</td>
        <td style="padding:7px 12px;text-align:right;vertical-align:top;">
          <span style="background:var(--bg-active);color:var(--accent);border:1px solid var(--accent);border-radius:10px;padding:1px 9px;font-size:0.75rem;font-weight:600;">${c.functions.length}</span>
        </td>
        <td style="padding:7px 20px 7px 12px;width:140px;vertical-align:top;">
          <div style="display:flex;align-items:center;gap:6px;margin-top:4px;">
            <div style="flex:1;background:var(--border);border-radius:4px;height:6px;overflow:hidden;">
              <div style="background:${barColor};width:${docPct}%;height:100%;border-radius:4px;" title="${docCount} of ${c.functions.length} functions documented"></div>
            </div>
            <span style="font-size:0.72rem;color:var(--text-muted);white-space:nowrap;min-width:30px;text-align:right;">${docPct}%</span>
          </div>
        </td>
      </tr>`;
    }).join('');

  detail.innerHTML = `
    <div style="max-width:860px;">
      <div style="margin-bottom:28px;">
        <div style="font-size:1.6rem;font-weight:700;color:var(--accent);font-family:'Cascadia Code','Consolas',monospace;margin-bottom:8px;">UserAdminModule</div>
        <div style="font-size:0.95rem;color:var(--text);line-height:1.7;margin-bottom:16px;">
          A comprehensive PowerShell module suite for Windows infrastructure administration.
          Organised into <strong style="color:var(--accent2);">${MODULE_DATA.length} submodules</strong> covering
          Active Directory, Azure, Exchange, PKI, Security, Networking, and more —
          with a total of <strong style="color:var(--accent2);">${total} exported functions</strong>.
        </div>
        <div style="display:flex;gap:14px;flex-wrap:wrap;">
          <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius);padding:14px 20px;text-align:center;min-width:120px;">
            <div style="font-size:1.8rem;font-weight:700;color:var(--accent);">${total}</div>
            <div style="font-size:0.75rem;color:var(--text-muted);text-transform:uppercase;letter-spacing:.06em;">Functions</div>
          </div>
          <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius);padding:14px 20px;text-align:center;min-width:120px;">
            <div style="font-size:1.8rem;font-weight:700;color:var(--accent3);">${MODULE_DATA.length}</div>
            <div style="font-size:0.75rem;color:var(--text-muted);text-transform:uppercase;letter-spacing:.06em;">Submodules</div>
          </div>
          <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius);padding:14px 20px;text-align:center;min-width:120px;">
            <div style="font-size:1.8rem;font-weight:700;color:var(--accent2);">${MODULE_DATA.reduce((s,c)=>s+(c.functions.filter(f=>f.examples&&f.examples.length>0).length),0)}</div>
            <div style="font-size:0.75rem;color:var(--text-muted);text-transform:uppercase;letter-spacing:.06em;">With Examples</div>
          </div>
          <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius);padding:14px 20px;text-align:center;min-width:120px;">
            <div style="font-size:1.8rem;font-weight:700;color:#ffa657;">${MODULE_DATA.reduce((s,c)=>s+(c.functions.filter(f=>f.parameters&&f.parameters.length>0).length),0)}</div>
            <div style="font-size:0.75rem;color:var(--text-muted);text-transform:uppercase;letter-spacing:.06em;">With Params</div>
          </div>
        </div>
      </div>

      <div style="font-size:0.72rem;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:var(--accent2);margin-bottom:10px;padding-bottom:6px;border-bottom:1px solid var(--border);">
        Submodule Overview
      </div>
      <table style="width:100%;border-collapse:collapse;">
        <thead>
          <tr style="border-bottom:1px solid var(--border);">
            <th style="text-align:left;padding:8px 12px;font-size:0.73rem;text-transform:uppercase;letter-spacing:.05em;color:var(--text-muted);">Submodule</th>
            <th style="text-align:left;padding:8px 12px;font-size:0.73rem;text-transform:uppercase;letter-spacing:.05em;color:var(--text-muted);">Description</th>
            <th style="text-align:right;padding:8px 12px;font-size:0.73rem;text-transform:uppercase;letter-spacing:.05em;color:var(--text-muted);">Functions</th>
            <th style="padding:8px 20px 8px 12px;font-size:0.73rem;text-transform:uppercase;letter-spacing:.05em;color:var(--text-muted);" title="Percentage of functions with a documented synopsis">Doc Coverage</th>
          </tr>
        </thead>
        <tbody style="background:var(--bg-card);border-radius:var(--radius);">
          ${catRows}
        </tbody>
      </table>

      <div style="margin-top:24px;font-size:0.8rem;color:var(--text-muted);line-height:1.6;">
        <strong style="color:var(--text);">Usage:</strong>
        Select a submodule from the left panel to expand it, then click any function to view its full help documentation including synopsis, parameters, examples, and source path.
        Use the search box to filter across all ${total} functions.
      </div>
    </div>`;
}

// ── Setup Guide ──
function showSetupGuide() {
  document.getElementById('setupModal').style.display = 'block';
  document.body.style.overflow = 'hidden';
  document.getElementById('setupModal').addEventListener('click', function(e) {
    if (e.target === this) {
      this.style.display = 'none';
      document.body.style.overflow = '';
    }
  }, { once: true });
  // Re-attach on every open
  setTimeout(() => {
    document.getElementById('setupModal').onclick = function(e) {
      if (e.target === this) { this.style.display = 'none'; document.body.style.overflow = ''; }
    };
  }, 0);
}

// ── Search ──
function showSearchResults(q) {
  const detail = document.getElementById('detail');
  const trimmed = q.trim().toLowerCase();

  if (!trimmed) { showHome(); return; }

  const matches = [];
  MODULE_DATA.forEach(cat => {
    cat.functions.forEach(fn => {
      if (fn.name.toLowerCase().includes(trimmed) ||
          (fn.synopsis || '').toLowerCase().includes(trimmed) ||
          (fn.fullDesc || fn.description || '').toLowerCase().includes(trimmed)) {
        matches.push({ fn, category: cat.category });
      }
    });
  });

  const hl = str => {
    if (!str) return '';
    const esc = s => s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
    const safe = esc(str);
    const re = new RegExp(esc(trimmed).replace(/[.*+?^${}()|[\]\\]/g,'\\$&'), 'gi');
    return safe.replace(re, m => `<mark style="background:var(--accent);color:#000;border-radius:2px;padding:0 2px;">${m}</mark>`);
  };

  const rows = matches.map(({ fn, category }) => `
    <tr class="search-result-row" style="cursor:pointer;" data-fn="${fn.name}" data-cat="${category}">
      <td style="padding:8px 10px;vertical-align:top;">
        <span style="color:var(--accent);font-family:monospace;font-size:0.92rem;">${hl(fn.name)}</span>
      </td>
      <td style="padding:8px 10px;vertical-align:top;">
        <span class="fn-module-badge" style="font-size:0.75rem;">${category}</span>
      </td>
      <td style="padding:8px 10px;vertical-align:top;color:var(--text-muted);font-size:0.88rem;">
        ${hl(fn.synopsis || '')}
      </td>
    </tr>`).join('');

  detail.innerHTML = `
    <div class="fn-header" style="border-bottom:1px solid var(--border);padding-bottom:14px;margin-bottom:18px;">
      <div style="font-size:1.4rem;font-weight:700;color:var(--fg);">Search Results</div>
      <div style="color:var(--text-muted);margin-top:4px;">
        ${matches.length === 0
          ? 'No functions matched <strong style="color:var(--accent);">' + q.replace(/</g,'&lt;') + '</strong>'
          : `<strong style="color:var(--accent);">${matches.length}</strong> function${matches.length === 1 ? '' : 's'} matching <strong style="color:var(--accent);">${q.replace(/</g,'&lt;')}</strong>`}
      </div>
    </div>
    ${matches.length > 0 ? `
    <table style="width:100%;border-collapse:collapse;">
      <thead>
        <tr style="border-bottom:1px solid var(--border);text-transform:uppercase;font-size:0.72rem;letter-spacing:.06em;color:var(--text-muted);">
          <th style="padding:6px 10px;text-align:left;width:28%;">Function</th>
          <th style="padding:6px 10px;text-align:left;width:20%;">Module</th>
          <th style="padding:6px 10px;text-align:left;">Synopsis</th>
        </tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>` : ''}`;

  detail.querySelectorAll('.search-result-row').forEach(row => {
    row.addEventListener('mouseenter', () => row.style.background = 'var(--hover)');
    row.addEventListener('mouseleave', () => row.style.background = '');
    row.addEventListener('click', () => {
      const fnName = row.dataset.fn;
      const catName = row.dataset.cat;
      const catObj = MODULE_DATA.find(c => c.category === catName);
      if (!catObj) return;
      const fn = catObj.functions.find(f => f.name === fnName);
      if (fn) showFunction(fn, catName);
    });
  });
}

document.getElementById('searchInput').addEventListener('input', function() {
  showSearchResults(this.value);
});

// ── Home button ──
document.getElementById('homeBtn').addEventListener('click', showHome);

// ── Init ──
buildSidebar();
showHome();

// Total count badge
const total = MODULE_DATA.reduce((s, c) => s + c.functions.length, 0);
document.getElementById('totalBadge').textContent = total + ' functions';
</script>
</body>
</html>
'@

$html = $htmlTemplate.Replace('__MODULE_DATA_PLACEHOLDER__', $jsonData)

$html | Set-Content -Path $OutputPath -Encoding UTF8
Write-Host "Generated: $OutputPath" -ForegroundColor Green
Write-Host "Functions indexed: $(($moduleData | ForEach-Object { $_.functions.Count } | Measure-Object -Sum).Sum)" -ForegroundColor Cyan
