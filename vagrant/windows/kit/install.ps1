<#
.SYNOPSIS
Installs the offline kit from this USB stick. No admin rights, no network.

.DESCRIPTION
    powershell -ExecutionPolicy Bypass -File E:\kit\install.ps1

Safe to re-run: app versions already installed are skipped and everything else is
brought in line with the stick. It only touches the kit root (packages.json "root"),
the dotfiles clone, nvim-data\lazy and nvim-data\site, uv's tool dir, the user PATH
and environment, and PowerShell profile stubs it created itself.
#>
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Import-Module (Join-Path $PSScriptRoot 'Kit.psm1') -Force

$kitDir   = $PSScriptRoot
$usbRoot  = Split-Path $kitDir -Parent
$manifest = Read-Json (Join-Path $kitDir 'packages.json')
$dist     = Read-Json (Join-Path $kitDir 'dist.json')
$vars     = Get-KitVars $manifest
$root     = $vars.root
New-Item -ItemType Directory -Force $root | Out-Null

# Input keys of the unversioned components installed last time.
$stateFile = Join-Path $root 'installed.json'
$state = @{}
if (Test-Path $stateFile) { (Read-Json $stateFile).PSObject.Properties | ForEach-Object { $state[$_.Name] = $_.Value } }
function Test-Current([string]$Name) { $state[$Name] -eq $dist.components.$Name.key }

Write-Host "Installing kit $($dist.revision) (dotfiles $($dist.dotfiles), built $($dist.built)) into $root"

Write-Host "==> apps"
$pathDirs = @()
foreach ($c in $dist.components.PSObject.Properties) {
    if ($c.Value.app) { $pathDirs += Install-KitApp -KitDir $kitDir -Component $c.Value -Root $root }
}

$wheels = Join-Path $root 'wheels'
if ($dist.components.wheels -and -not (Test-Current 'wheels')) {
    Write-Host "==> python wheels"
    Assert-KitFiles $kitDir $dist.components.wheels
    Remove-Item -Recurse -Force $wheels -ErrorAction SilentlyContinue
    Copy-Item -Recurse (Join-Path $kitDir 'dist\wheels') $wheels
    $state['wheels'] = $dist.components.wheels.key
}

if ($dist.components.'node-tools') {
    $nodeTools = Join-Path $root 'node-tools'
    if (-not (Test-Current 'node-tools')) {
        Write-Host "==> node tools"
        Assert-KitFiles $kitDir $dist.components.'node-tools'
        Remove-Item -Recurse -Force $nodeTools -ErrorAction SilentlyContinue
        Expand-Zip (Join-Path $kitDir 'dist\node-tools.zip') $nodeTools
        $state['node-tools'] = $dist.components.'node-tools'.key
    }
    $pathDirs += Join-Path $nodeTools 'node_modules\.bin'
}

if ($dist.components.'nvim-data' -and -not (Test-Current 'nvim-data')) {
    Write-Host "==> neovim plugins and parsers"
    Assert-KitFiles $kitDir $dist.components.'nvim-data'
    $nvimData = Join-Path $env:LOCALAPPDATA 'nvim-data'
    $new = "$nvimData.new"
    Remove-Item -Recurse -Force $new -ErrorAction SilentlyContinue
    Expand-Zip (Join-Path $kitDir 'dist\nvim-data.zip') $new
    # Replace only what the kit owns: all of lazy\, and the site\ subdirs it ships
    # (parser, queries, ...). Shada, undo history and site\spell survive.
    $owned = @(Get-Item (Join-Path $new 'lazy') -ErrorAction SilentlyContinue) +
             @(Get-ChildItem (Join-Path $new 'site') -Directory -ErrorAction SilentlyContinue)
    foreach ($dir in $owned) {
        $target = Join-Path $nvimData $dir.FullName.Substring($new.Length + 1)
        Remove-Item -Recurse -Force -LiteralPath $target -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
        Move-Item -LiteralPath $dir.FullName $target
    }
    Remove-Item -Recurse -Force $new
    $state['nvim-data'] = $dist.components.'nvim-data'.key
}

Write-Host "==> environment"
Set-UserPath -Dirs $pathDirs -Root $root
foreach ($e in $manifest.env.PSObject.Properties) {
    Set-UserEnv $e.Name (Expand-KitString $e.Value $vars)
}

$tools = @($manifest.python.tools)
if ($tools.Count -gt 0) {
    $python = Join-Path $root 'apps\python\current\python.exe'
    $toolsKey = "$($state['wheels'])|$($dist.components.'app:python'.app.version)|$($tools -join ',')"
    if ($state['uv-tools'] -ne $toolsKey) {
        Write-Host "==> python tools"
        foreach ($t in $tools) {
            # Venvs aren't relocatable, so tools are built here, from the wheelhouse.
            Invoke-Native uv tool install --reinstall --offline --no-index --find-links $wheels --python $python $t
        }
        $state['uv-tools'] = $toolsKey
    }
    $pathDirs += (& uv tool dir --bin)
    Set-UserPath -Dirs $pathDirs -Root $root
}

Write-Host "==> dotfiles"
if (Sync-Dotfiles -UsbRoot $usbRoot -RepoRel $manifest.dotfiles.repo -Path $vars.dotfiles) {
    foreach ($j in $manifest.dotfiles.junctions.PSObject.Properties) {
        $link = Expand-KitString $j.Name $vars
        $target = Expand-KitString $j.Value $vars
        if (Test-Path $target) { Set-Junction $link $target }
        else { Write-Warning "Not linking $link; $target doesn't exist in the dotfiles yet" }
    }
    if ($manifest.dotfiles.profile) { Set-ProfileStub (Expand-KitString $manifest.dotfiles.profile $vars) }
}

Write-Json $stateFile $state

# New shells use the first policy set outside the Process scope.
$policy = Get-ExecutionPolicy -List |
    Where-Object { $_.Scope -ne 'Process' -and $_.ExecutionPolicy -ne 'Undefined' } | Select-Object -First 1
if (-not $policy -or [string]$policy.ExecutionPolicy -in 'Restricted', 'AllSigned') {
    Write-Warning 'The execution policy blocks unsigned profiles. If policy allows it: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
}
Write-Host "Done. Open a new terminal to pick up PATH and environment changes."
exit 0  # not whatever the last native command left in $LASTEXITCODE
