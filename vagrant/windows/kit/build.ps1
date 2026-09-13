<#
.SYNOPSIS
Builds the offline kit onto the USB stick. Runs in the builder VM (online, MSVC).

.DESCRIPTION
Every input is pinned by this directory's lock files (see lock.sh). Each component
is keyed on its inputs and only rebuilt when they change; -Force rebuilds all.

Written to <usb>\kit\:
  install.ps1 test.ps1 Kit.psm1 packages.json   the installer that runs at work
  dist.json                    per component: input key, files and their sha256
  dist\apps\<name>-<ver>.zip   app trees, already unpacked from zip/msi/sfx/gz here
  dist\wheels\*.whl            Python wheelhouse; sdists are compiled here with MSVC
  dist\node-tools.zip          npm ci of node\package-lock.json
  dist\nvim-data.zip           lazy.nvim plugins (native build steps done) + parsers
  .cache\                      verified downloads, reused by later builder VMs
#>
param(
    [Parameter(Mandatory)] [string]$UsbRoot,
    [string]$Revision = 'unknown',
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Import-Module (Join-Path $PSScriptRoot 'Kit.psm1') -Force

$src      = $PSScriptRoot
$kitDir   = Join-Path $UsbRoot 'kit'
$cacheDir = Join-Path $kitDir '.cache'
# Unpack on local disk under a short path: faster than the stick, and deep trees
# (node_modules, plugins) stay under MAX_PATH.
$stage    = 'C:\kit-stage'
New-Item -ItemType Directory -Force (Join-Path $kitDir 'dist\apps'), $cacheDir, $stage | Out-Null

$manifest = Read-Json (Join-Path $src 'packages.json')
$lock     = Read-Json (Join-Path $src 'packages.lock.json')
$vars     = Get-KitVars $manifest
$distFile = Join-Path $kitDir 'dist.json'
$previous = if (Test-Path $distFile) { (Read-Json $distFile).components } else { $null }
$components = [ordered]@{}

function Get-LockVersion([string]$Name) { ($lock.apps | Where-Object name -eq $Name).version }

# Reuses the previous build's component when its inputs are unchanged and files present.
function Copy-Previous([string]$Name, [string]$Key) {
    if ($Force -or -not $previous) { return $false }
    $old = $previous.$Name
    if (-not $old -or $old.key -ne $Key) { return $false }
    foreach ($f in $old.files.PSObject.Properties) {
        if (-not (Test-Path (Join-Path $kitDir $f.Name))) { return $false }
    }
    $components[$Name] = $old
    Write-Host "  $Name unchanged"
    $true
}

# Records a freshly built component, hashing its files for install-time verification.
function Add-Component([string]$Name, [string]$Key, [string[]]$Files, [hashtable]$Extra = @{}) {
    $hashes = [ordered]@{}
    foreach ($f in $Files) { $hashes[$f] = Get-Sha256 (Join-Path $kitDir $f) }
    $entry = [ordered]@{ key = $Key; files = $hashes }
    foreach ($k in $Extra.Keys) { $entry[$k] = $Extra[$k] }
    # Round-trip so fresh and reused entries are the same shape (PSCustomObject).
    $components[$Name] = $entry | ConvertTo-Json -Depth 10 | ConvertFrom-Json
}

function Get-Download($App) {
    $leaf = [uri]::UnescapeDataString((Split-Path ([uri]$App.url).AbsolutePath -Leaf))
    $file = Join-Path $cacheDir ('{0}-{1}' -f $App.sha256.Substring(0, 12), $leaf)
    if ((Test-Path $file) -and (Get-Sha256 $file) -eq $App.sha256) { return $file }
    Write-Host "  downloading $($App.url)"
    Invoke-Native curl.exe --fail --location --silent --show-error --retry 3 --output "$file.part" $App.url
    $actual = Get-Sha256 "$file.part"
    if ($actual -ne $App.sha256) {
        Remove-Item "$file.part"
        throw "$($App.name): sha256 mismatch for $($App.url): expected $($App.sha256), got $actual"
    }
    Move-Item -Force "$file.part" $file
    $file
}

function Expand-GZip([string]$Path, [string]$Destination) {
    $in = [IO.File]::OpenRead($Path)
    try {
        $gz = New-Object IO.Compression.GZipStream($in, [IO.Compression.CompressionMode]::Decompress)
        $out = [IO.File]::Create($Destination)
        try { $gz.CopyTo($out) } finally { $out.Dispose(); $gz.Dispose() }
    } finally { $in.Dispose() }
}

# Unpacks a download into a plain directory. Every installer format is dealt with
# here, online and tested, so the work laptop only ever unzips.
function Expand-App($App, [string]$Download, [string]$Dest) {
    $tmp = "$Dest.tmp"
    Remove-Item -Recurse -Force $tmp, $Dest -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $tmp | Out-Null
    $leaf = Split-Path $Download -Leaf
    switch -Regex ($leaf) {
        '\.7z\.exe$' {
            # 7-Zip self-extractor (PortableGit); also runs its post-install step.
            $p = Start-Process $Download -ArgumentList "-o`"$tmp`"", '-y' -Wait -PassThru
            if ($p.ExitCode -ne 0) { throw "$leaf failed to extract (exit $($p.ExitCode))" }
            break
        }
        '\.msi$' {
            # Administrative install: extracts the files, registers nothing.
            $p = Start-Process msiexec.exe -ArgumentList '/a', "`"$Download`"", '/qn', "TARGETDIR=`"$tmp`"" -Wait -PassThru
            if ($p.ExitCode -ne 0) { throw "msiexec /a $leaf failed (exit $($p.ExitCode))" }
            Remove-Item (Join-Path $tmp '*.msi')
            break
        }
        '\.(zip|tar\.gz|tgz)$' { Expand-Zip $Download $tmp; break }
        '\.gz$'  { Expand-GZip $Download (Join-Path $tmp $App.rename); break }
        '\.exe$' { Copy-Item $Download (Join-Path $tmp $App.rename); break }
        default  { throw "$($App.name): don't know how to unpack $leaf" }
    }
    $root = if ($App.extract_dir) { Join-Path $tmp $App.extract_dir } else { $tmp }
    if (-not (Test-Path $root)) {
        throw "$($App.name): extract_dir '$($App.extract_dir)' not found; archive has: $((Get-ChildItem $tmp).Name -join ', ')"
    }
    Move-Item $root $Dest
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    foreach ($bin in $App.bin) {
        if (-not (Test-Path (Join-Path $Dest $bin))) {
            $found = Get-ChildItem $Dest -Recurse -Include *.exe, *.cmd |
                ForEach-Object { $_.FullName.Substring($Dest.Length + 1) } | Select-Object -First 20
            throw "$($App.name): expected '$bin', found: $($found -join ', ')"
        }
    }
}

function Use-Msvc {
    # Puts cl, link, cmake and ninja on PATH, as a "Developer PowerShell" would.
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $vs = if (Test-Path $vswhere) {
        & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    }
    if (-not $vs) { throw 'MSVC Build Tools not found; run the "toolchain" provisioner first' }
    Import-Module (Join-Path $vs 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll')
    Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null
}

Write-Host "==> apps"
$appDirs = @()
foreach ($app in $lock.apps) {
    $name = "app:$($app.name)"
    $file = "dist\apps\$($app.name)-$($app.version).zip"
    $key  = Get-StringHash ($app | ConvertTo-Json -Compress -Depth 5)
    if (-not (Copy-Previous $name $key)) {
        Write-Host "  building $($app.name) $($app.version)"
        $tree = Join-Path $stage "apps\$($app.name)"
        Expand-App $app (Get-Download $app) $tree
        New-Zip $tree (Join-Path $kitDir $file)
        Add-Component $name $key @($file) @{
            app = [ordered]@{ name = $app.name; version = $app.version; file = $file; path = @($app.path); bin = @($app.bin) }
        }
    }
    # The builder uses exactly the binaries it ships.
    $appDirs += Install-KitApp -KitDir $kitDir -Component $components[$name] -Root $vars.root
}
Set-UserPath -Dirs $appDirs -Root $vars.root
Use-Msvc  # after Set-UserPath, which resets the session PATH

Write-Host "==> dotfiles"
$dotfiles = $vars.dotfiles
$dotfilesRev = 'none'
if (Sync-Dotfiles -UsbRoot $UsbRoot -RepoRel $manifest.dotfiles.repo -Path $dotfiles) {
    $dotfilesRev = (& git -C $dotfiles describe --always --dirty --abbrev=12)
}

Write-Host "==> python wheels"
$python = Join-Path $vars.root 'apps\python\current\python.exe'
$requirements = Join-Path $src 'python\requirements.txt'
$key = Get-StringHash ((Get-Content -Raw $requirements) + (Get-LockVersion 'python'))
if (-not (Copy-Previous 'wheels' $key)) {
    $wheels = Join-Path $stage 'wheels'
    Remove-Item -Recurse -Force $wheels -ErrorAction SilentlyContinue
    # requirements.txt is fully resolved and hash-pinned by lock.sh, hence --no-deps.
    Invoke-Native $python -m pip wheel --disable-pip-version-check --no-deps --require-hashes `
        --wheel-dir $wheels -r $requirements
    $dest = Join-Path $kitDir 'dist\wheels'
    Remove-Item -Recurse -Force $dest -ErrorAction SilentlyContinue
    Copy-Item -Recurse $wheels $dest
    Add-Component 'wheels' $key @(Get-ChildItem $dest -Filter *.whl | ForEach-Object { "dist\wheels\$($_.Name)" })
}

$npmLock = Join-Path $src 'node\package-lock.json'
if (Test-Path $npmLock) {
    Write-Host "==> node tools"
    $key = Get-StringHash ((Get-Content -Raw $npmLock) + (Get-LockVersion 'node'))
    if (-not (Copy-Previous 'node-tools' $key)) {
        $dir = Join-Path $stage 'node-tools'
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
        New-Item -ItemType Directory $dir | Out-Null
        Copy-Item (Join-Path $src 'node\package.json'), $npmLock $dir
        Invoke-Native npm.cmd ci --prefix $dir --no-audit --no-fund
        New-Zip $dir (Join-Path $kitDir 'dist\node-tools.zip')
        Add-Component 'node-tools' $key @('dist\node-tools.zip')
    }
}

$nvimConfig = Join-Path $dotfiles 'nvim'
if (Test-Path (Join-Path $nvimConfig 'init.lua')) {
    Write-Host "==> neovim plugins and parsers"
    $lazyLock = Join-Path $nvimConfig 'lazy-lock.json'
    if (-not (Test-Path $lazyLock)) {
        Write-Warning 'nvim\lazy-lock.json is not committed in the dotfiles; plugins are unpinned. Commit the one this build creates.'
    }
    $parsers = @($manifest.neovim.treesitter)
    $lockText = if (Test-Path $lazyLock) { Get-Content -Raw $lazyLock } else { '' }
    $key = Get-StringHash ($lockText + ($parsers -join ',') + (Get-LockVersion 'neovim') + (Get-LockVersion 'tree-sitter'))
    if (-not (Copy-Previous 'nvim-data' $key)) {
        $data = Join-Path $stage 'nvim'
        Remove-Item -Recurse -Force $data -ErrorAction SilentlyContinue
        # For this build only: config from the dotfiles clone, data into a clean dir.
        $env:XDG_CONFIG_HOME = $dotfiles
        $env:XDG_DATA_HOME = $data
        $env:KIT_TS_PARSERS = $parsers -join ','
        try {
            Invoke-Nvim '--headless "+Lazy! restore" +qa'
            Invoke-Nvim "--headless -c `"lua dofile([[$src\nvim-build.lua]])`""
        } finally {
            Remove-Item env:XDG_CONFIG_HOME, env:XDG_DATA_HOME, env:KIT_TS_PARSERS
        }
        $nvimData = Join-Path $data 'nvim-data'
        # lazy.nvim doesn't fail the process when a clone or build fails; check instead.
        if (Test-Path $lazyLock) {
            $missing = (Read-Json $lazyLock).PSObject.Properties.Name |
                Where-Object { -not (Test-Path (Join-Path $nvimData "lazy\$_")) }
            if ($missing) { throw "plugins missing after Lazy restore: $($missing -join ', ')" }
        }
        $items = @('lazy', 'site') | Where-Object { Test-Path (Join-Path $nvimData $_) }
        New-Zip $nvimData (Join-Path $kitDir 'dist\nvim-data.zip') $items
        Add-Component 'nvim-data' $key @('dist\nvim-data.zip')
    }
} else {
    Write-Host "==> neovim: no nvim\init.lua in the dotfiles yet, skipping"
}

Write-Host "==> installer"
foreach ($f in 'install.ps1', 'test.ps1', 'Kit.psm1', 'packages.json') {
    Copy-Item (Join-Path $src $f) $kitDir -Force
}

# Drop files nothing references any more (old app versions, removed wheels).
$live = @{}
foreach ($c in $components.Values) {
    foreach ($f in $c.files.PSObject.Properties) { $live[(Join-Path $kitDir $f.Name)] = $true }
}
Get-ChildItem (Join-Path $kitDir 'dist') -Recurse -File |
    Where-Object { -not $live.ContainsKey($_.FullName) } | Remove-Item

# Written last: a build that dies halfway leaves the previous dist.json, and
# install.ps1's checksums refuse anything it doesn't describe.
Write-Json $distFile ([ordered]@{
    revision   = $Revision
    dotfiles   = $dotfilesRev
    built      = (Get-Date).ToUniversalTime().ToString('o')
    components = $components
})
Write-Host "Kit $Revision (dotfiles $dotfilesRev) written to $kitDir"
