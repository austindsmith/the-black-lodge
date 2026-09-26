[CmdletBinding()]
param(
    [string]$Source = $PSScriptRoot,

    [switch]$SkipVerify,

    [switch]$WhatIfOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step { param([string]$Message) Write-Host "==> $Message" -ForegroundColor Cyan }

$lockPath = Join-Path $Source 'kit.lock.json'
if (-not (Test-Path $lockPath)) {
    throw "No kit.lock.json in $Source. Point -Source at a kit directory."
}

$lock = Get-Content $lockPath -Raw | ConvertFrom-Json
$installRoot = $lock.install_root

Write-Step "Kit $($lock.build_id) built $($lock.built_at)"
Write-Step "Install root: $installRoot"

if (-not $SkipVerify) {
    $sums = Join-Path $Source 'SHA256SUMS'
    if (Test-Path $sums) {
        Write-Step 'Verifying payload'
        $bad = 0
        foreach ($line in Get-Content $sums) {
            if ($line -notmatch '^(\S+)\s+\*?(.+)$') { continue }
            $expected, $relative = $Matches[1], $Matches[2]
            $file = Join-Path $Source $relative
            if (-not (Test-Path $file)) {
                Write-Warning "missing: $relative"; $bad++; continue
            }
            $actual = (Get-FileHash $file -Algorithm SHA256).Hash
            if ($actual -ne $expected.ToUpper()) {
                Write-Warning "checksum mismatch: $relative"; $bad++
            }
        }
        if ($bad -gt 0) { throw "$bad file(s) failed verification. Re-copy the kit." }
    }
    else {
        Write-Warning 'No SHA256SUMS found; skipping verification.'
    }
}

if ($WhatIfOnly) { Write-Step 'WhatIfOnly set; stopping before any changes.'; return }

Write-Step "Copying payload to $installRoot"

New-Item -ItemType Directory -Force -Path $installRoot | Out-Null

robocopy $Source $installRoot /MIR /NFL /NDL /NJH /NJS /NP /R:2 /W:2 `
    /XF 'kit.lock.json' 'SHA256SUMS' 'Install-Kit.ps1' | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }


function Add-UserPath {
    param([string]$Directory)
    if (-not (Test-Path $Directory)) { return }
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = @($current -split ';' | Where-Object { $_ })
    if ($entries -contains $Directory) { return }
    Write-Host "    PATH += $Directory"
    [Environment]::SetEnvironmentVariable('Path', (@($Directory) + $entries) -join ';', 'User')
}

Write-Step 'Updating user PATH'
Add-UserPath (Join-Path $installRoot 'scoop\shims')
Add-UserPath (Join-Path $installRoot 'nvim\bin')
Add-UserPath (Join-Path $installRoot 'python')
Add-UserPath (Join-Path $installRoot 'python\Scripts')
Add-UserPath (Join-Path $installRoot 'node')
Add-UserPath (Join-Path $installRoot 'node-tools')
Add-UserPath (Join-Path $installRoot 'bin')

Write-Step 'Setting user environment'
[Environment]::SetEnvironmentVariable('SCOOP', (Join-Path $installRoot 'scoop'), 'User')
[Environment]::SetEnvironmentVariable(
    'KOMOREBI_CONFIG_HOME', (Join-Path $env:USERPROFILE '.config\komorebi'), 'User')

[Environment]::SetEnvironmentVariable('PIP_NO_INDEX', '1', 'User')
[Environment]::SetEnvironmentVariable(
    'PIP_FIND_LINKS', (Join-Path $installRoot 'wheelhouse'), 'User')

$mirrors = Join-Path $installRoot 'plugin-mirrors'
if (Test-Path $mirrors) {
    Write-Step 'Pointing github.com at the bundled plugin mirrors'
    $url = 'file:///' + ($mirrors -replace '\\', '/') + '/'
    & (Join-Path $installRoot 'scoop\shims\git.exe') config --global `
        "url.$url.insteadOf" 'https://github.com/'
}


Write-Step 'Deploying dotfiles'
$dotfiles = Join-Path $installRoot 'dotfiles'
$targets = @{
    'nvim'       = Join-Path $env:LOCALAPPDATA 'nvim'
    'komorebi'   = Join-Path $env:USERPROFILE '.config\komorebi'
    'powershell' = Join-Path $env:USERPROFILE 'Documents\PowerShell'
    'starship'   = Join-Path $env:USERPROFILE '.config\starship'
    'wezterm'    = Join-Path $env:USERPROFILE '.config\wezterm'
    'yazi'       = Join-Path $env:APPDATA 'yazi\config'
}
foreach ($name in $targets.Keys) {
    $from = Join-Path $dotfiles $name
    if (-not (Test-Path $from)) { continue }
    New-Item -ItemType Directory -Force -Path $targets[$name] | Out-Null
    robocopy $from $targets[$name] /E /NFL /NDL /NJH /NJS /NP /R:2 /W:2 | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed for $name ($LASTEXITCODE)" }
}

$parsers = Join-Path $installRoot 'treesitter'
if (Test-Path $parsers) {
    Write-Step 'Installing treesitter parsers'
    $dest = Join-Path $env:LOCALAPPDATA 'nvim-data\site\parser'
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    robocopy $parsers $dest /E /NFL /NDL /NJH /NJS /NP /R:2 /W:2 | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed for parsers ($LASTEXITCODE)" }
}

Write-Step 'Done. Open a new terminal for the PATH change to take effect.'
Write-Host ''
Write-Host "  nvim      $((Join-Path $installRoot 'nvim\bin\nvim.exe'))"
Write-Host "  python    $((Join-Path $installRoot 'python\python.exe'))"
Write-Host "  wheelhouse $((Join-Path $installRoot 'wheelhouse'))"
Write-Host ''
Write-Host '  Offline installs:  pip install -r requirements.txt'
Write-Host '  (PIP_NO_INDEX and PIP_FIND_LINKS are already set for your user.)'
