#Requires -Version 5.1
param(
    [string]$Root
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Import-Module (Join-Path $PSScriptRoot 'Kit.psm1') -Force

$SchemaVersion = 1
$KitDir = $PSScriptRoot
$UsbRoot = Split-Path $KitDir -Parent

function Get-AppComponent($Dist, [string]$Name) {
    ($Dist.components.PSObject.Properties | Where-Object { $_.Value.app -and $_.Value.app.name -eq $Name }).Value
}

function Read-InstalledState([string]$Path) {
    $state = @{}
    if (Test-Path $Path) {
        (Read-Json $Path).PSObject.Properties | ForEach-Object { $state[$_.Name] = $_.Value }
    }
    $state
}

function Test-ComponentInstalled($Dist, [string]$Name) {
    $script:State[$Name] -eq $Dist.components.$Name.key
}

function Install-Apps($Dist, [string]$KitRoot) {
    $pathDirs = @()
    foreach ($component in $Dist.components.PSObject.Properties) {
        if ($component.Value.app) {
            $pathDirs += Install-KitApp -KitDir $KitDir -Component $component.Value -Root $KitRoot
        }
    }
    $pathDirs
}

function Install-Wheels($Dist, [string]$Destination) {
    if (-not $Dist.components.wheels -or (Test-ComponentInstalled $Dist 'wheels')) { return }

    Assert-KitFiles $KitDir $Dist.components.wheels
    Remove-Item -Recurse -Force $Destination -ErrorAction SilentlyContinue
    Copy-Item -Recurse (Join-Path $KitDir 'dist\wheels') $Destination
    $script:State['wheels'] = $Dist.components.wheels.key
}

function Install-NodeTools($Dist, [string]$Destination) {
    if (-not $Dist.components.'node-tools') { return }

    if (-not (Test-ComponentInstalled $Dist 'node-tools')) {
        Assert-KitFiles $KitDir $Dist.components.'node-tools'
        Remove-Item -Recurse -Force $Destination -ErrorAction SilentlyContinue
        Expand-Zip (Join-Path $KitDir 'dist\node-tools.zip') $Destination
        $script:State['node-tools'] = $Dist.components.'node-tools'.key
    }
    Join-Path $Destination 'node_modules\.bin'
}

function Install-NvimData($Dist) {
    if (-not $Dist.components.'nvim-data' -or (Test-ComponentInstalled $Dist 'nvim-data')) { return }

    Assert-KitFiles $KitDir $Dist.components.'nvim-data'
    $dataDir = Join-Path $env:LOCALAPPDATA 'nvim-data'
    $incoming = "$dataDir.incoming"
    Remove-Item -Recurse -Force $incoming -ErrorAction SilentlyContinue
    Expand-Zip (Join-Path $KitDir 'dist\nvim-data.zip') $incoming

    $owned = @(Get-Item (Join-Path $incoming 'lazy') -ErrorAction SilentlyContinue) +
             @(Get-ChildItem (Join-Path $incoming 'site') -Directory -ErrorAction SilentlyContinue)
    foreach ($directory in $owned) {
        $target = Join-Path $dataDir $directory.FullName.Substring($incoming.Length + 1)
        Remove-Item -Recurse -Force -LiteralPath $target -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
        Move-Item -LiteralPath $directory.FullName $target
    }

    Remove-Item -Recurse -Force $incoming
    $script:State['nvim-data'] = $Dist.components.'nvim-data'.key
}

function Install-PythonTools($Manifest, $Dist, [string]$KitRoot) {
    $tools = @($Manifest.python.tools)
    if ($tools.Count -eq 0) { return }

    $python = Join-Path $KitRoot 'apps\python\current\python.exe'
    $wheels = Join-Path $KitRoot 'wheels'
    $key = "$($script:State['wheels'])|$((Get-AppComponent $Dist 'python').app.version)|$($tools -join ',')"

    if ($script:State['uv-tools'] -ne $key) {
        foreach ($tool in $tools) {
            Invoke-Native uv tool install --reinstall --offline --no-index --find-links $wheels --python $python $tool | Out-Host
        }
        $script:State['uv-tools'] = $key
    }
    & uv tool dir --bin
}

function Set-KitEnvironment($Manifest, [hashtable]$Vars) {
    foreach ($variable in $Manifest.env.PSObject.Properties) {
        Set-UserEnv $variable.Name (Expand-KitString $variable.Value $Vars)
    }
}

function Connect-Dotfiles($Manifest, [hashtable]$Vars) {
    if (-not (Sync-Dotfiles -UsbRoot $UsbRoot -RepoRel $Manifest.dotfiles.repo -Path $Vars.dotfiles)) { return }

    foreach ($junction in $Manifest.dotfiles.junctions.PSObject.Properties) {
        $link = Expand-KitString $junction.Name $Vars
        $target = Expand-KitString $junction.Value $Vars
        if (Test-Path $target) {
            Set-Junction $link $target
        } else {
            Write-Warning "Not linking $link; $target does not exist in the dotfiles yet"
        }
    }

    if ($Manifest.dotfiles.profile) {
        Set-ProfileStub (Expand-KitString $Manifest.dotfiles.profile $Vars)
    }
}

function Show-ExecutionPolicyWarning {
    if ((Get-EffectiveExecutionPolicy) -in 'Restricted', 'AllSigned') {
        Write-Warning 'The execution policy blocks unsigned profiles. If policy allows: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
    }
}

$distFile = Join-Path $KitDir 'dist.json'
if (-not (Test-Path $distFile)) { throw "No kit on this stick ($distFile is missing); build it first" }

$manifest = Read-Json (Join-Path $KitDir 'packages.json')
$dist = Read-Json $distFile
if ($dist.schema -ne $SchemaVersion) {
    throw "This stick was built with kit schema $($dist.schema), this installer expects $SchemaVersion; rebuild the kit"
}

$vars = Get-KitVars $manifest
if ($Root) { $vars.root = $Root }
$kitRoot = $vars.root
New-Item -ItemType Directory -Force $kitRoot | Out-Null
$script:State = Read-InstalledState (Join-Path $kitRoot 'installed.json')

Write-Host "Installing kit $($dist.revision) (dotfiles $($dist.dotfiles), built $($dist.built)) into $kitRoot"

Write-Step 'apps'
$pathDirs = Install-Apps $dist $kitRoot

Write-Step 'python wheels'
Install-Wheels $dist (Join-Path $kitRoot 'wheels')

Write-Step 'node tools'
$pathDirs += Install-NodeTools $dist (Join-Path $kitRoot 'node-tools')

Write-Step 'neovim'
Install-NvimData $dist

Write-Step 'environment'
Set-UserPath -Prepend $pathDirs -ManagedRoot $kitRoot
Set-KitEnvironment $manifest $vars

Write-Step 'python tools'
$pathDirs += Install-PythonTools $manifest $dist $kitRoot
Set-UserPath -Prepend $pathDirs -ManagedRoot $kitRoot

Write-Step 'dotfiles'
Connect-Dotfiles $manifest $vars

Write-Json (Join-Path $kitRoot 'installed.json') $script:State
Show-ExecutionPolicyWarning
Write-Host 'Done. Open a new terminal to pick up the PATH and environment changes.'
exit 0
