#Requires -Version 5.1
param(
    [Parameter(Mandatory)] [string]$UsbRoot,
    [string]$Revision = 'unknown',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Import-Module (Join-Path $PSScriptRoot 'Kit.psm1') -Force

$SchemaVersion = 1
$SourceDir = $PSScriptRoot
$KitDir = Join-Path $UsbRoot 'kit'
$DistDir = Join-Path $KitDir 'dist'
$CacheDir = Join-Path $KitDir '.cache'
$StageDir = 'C:\kit-stage'
$InstallerFiles = @('install.ps1', 'test.ps1', 'Kit.psm1', 'packages.json')
$ParserTimeoutMs = 30 * 60 * 1000

function Get-LockedVersion($Lock, [string]$Name) {
    ($Lock.apps | Where-Object name -eq $Name).version
}

function Test-ReusableComponent([string]$Name, [string]$Key) {
    if ($Force -or -not $script:Previous) { return $false }

    $existing = $script:Previous.$Name
    if (-not $existing -or $existing.key -ne $Key) { return $false }
    foreach ($file in $existing.files.PSObject.Properties) {
        if (-not (Test-Path (Join-Path $KitDir $file.Name))) { return $false }
    }

    $script:Components[$Name] = $existing
    Write-Host "  $Name unchanged"
    $true
}

function Add-BuiltComponent([string]$Name, [string]$Key, [string[]]$Files, [hashtable]$Extra = @{}) {
    $hashes = [ordered]@{}
    foreach ($file in $Files) { $hashes[$file] = Get-Sha256 (Join-Path $KitDir $file) }

    $entry = [ordered]@{ key = $Key; files = $hashes }
    foreach ($property in $Extra.Keys) { $entry[$property] = $Extra[$property] }

    $script:Components[$Name] = $entry | ConvertTo-Json -Depth 10 | ConvertFrom-Json
}

function Get-VerifiedDownload($App) {
    $assetName = [uri]::UnescapeDataString((Split-Path ([uri]$App.url).AbsolutePath -Leaf))
    $cached = Join-Path $CacheDir ('{0}-{1}' -f $App.sha256.Substring(0, 12), $assetName)
    if ((Test-Path $cached) -and (Get-Sha256 $cached) -eq $App.sha256) { return $cached }

    Write-Host "  downloading $($App.url)"
    Invoke-Native curl.exe --fail --location --silent --show-error --retry 3 --output "$cached.part" $App.url

    $actual = Get-Sha256 "$cached.part"
    if ($actual -ne $App.sha256) {
        Remove-Item "$cached.part"
        throw "$($App.name): sha256 mismatch for $($App.url): expected $($App.sha256), got $actual"
    }

    Move-Item -Force "$cached.part" $cached
    $cached
}

function Expand-GZipFile([string]$Path, [string]$Destination) {
    $source = [IO.File]::OpenRead($Path)
    try {
        $gzip = New-Object IO.Compression.GZipStream($source, [IO.Compression.CompressionMode]::Decompress)
        $target = [IO.File]::Create($Destination)
        try { $gzip.CopyTo($target) } finally { $target.Dispose(); $gzip.Dispose() }
    } finally {
        $source.Dispose()
    }
}

function Expand-AppArchive($App, [string]$Download, [string]$Destination) {
    $staging = "$Destination.tmp"
    Remove-Item -Recurse -Force $staging, $Destination -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $staging | Out-Null

    $assetName = Split-Path $Download -Leaf
    switch -Regex ($assetName) {
        '\.7z\.exe$' {
            $process = Start-Process $Download -ArgumentList "-o`"$staging`"", '-y' -Wait -PassThru
            if ($process.ExitCode -ne 0) { throw "$assetName failed to extract (exit $($process.ExitCode))" }
            break
        }
        '\.msi$' {
            $process = Start-Process msiexec.exe -Wait -PassThru `
                -ArgumentList '/a', "`"$Download`"", '/qn', "TARGETDIR=`"$staging`""
            if ($process.ExitCode -ne 0) { throw "msiexec /a $assetName failed (exit $($process.ExitCode))" }
            Remove-Item (Join-Path $staging '*.msi')
            break
        }
        '\.(zip|tar\.gz|tgz)$' { Expand-Zip $Download $staging; break }
        '\.gz$' { Expand-GZipFile $Download (Join-Path $staging $App.rename); break }
        '\.exe$' { Copy-Item $Download (Join-Path $staging $App.rename); break }
        default { throw "$($App.name): no unpack rule for $assetName" }
    }

    $unpacked = if ($App.extract_dir) { Join-Path $staging $App.extract_dir } else { $staging }
    if (-not (Test-Path $unpacked)) {
        throw "$($App.name): extract_dir '$($App.extract_dir)' not found; archive contains: $((Get-ChildItem $staging).Name -join ', ')"
    }

    Move-Item $unpacked $Destination
    Remove-Item -Recurse -Force $staging -ErrorAction SilentlyContinue
}

function Assert-AppBinaries($App, [string]$Destination) {
    foreach ($binary in $App.bin) {
        if (Test-Path (Join-Path $Destination $binary)) { continue }
        $found = Get-ChildItem $Destination -Recurse -Include *.exe, *.cmd |
            ForEach-Object { $_.FullName.Substring($Destination.Length + 1) } | Select-Object -First 20
        throw "$($App.name): expected '$binary', found: $($found -join ', ')"
    }
}

function Enter-MsvcEnvironment {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $installPath = if (Test-Path $vswhere) {
        & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    }
    if (-not $installPath) { throw 'MSVC Build Tools not found; run the "toolchain" provisioner first' }

    Import-Module (Join-Path $installPath 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll')
    Enter-VsDevShell -VsInstallPath $installPath -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null
}

function Build-Apps($Lock, [string]$Root) {
    $pathDirs = @()
    foreach ($app in $Lock.apps) {
        $name = "app:$($app.name)"
        $file = "dist\apps\$($app.name)-$($app.version).zip"
        $key = Get-StringHash ($app | ConvertTo-Json -Compress -Depth 5)

        if (-not (Test-ReusableComponent $name $key)) {
            Write-Host "  building $($app.name) $($app.version)"
            $tree = Join-Path $StageDir "apps\$($app.name)"
            Expand-AppArchive $app (Get-VerifiedDownload $app) $tree
            Assert-AppBinaries $app $tree
            New-Zip $tree (Join-Path $KitDir $file)
            Add-BuiltComponent $name $key @($file) @{
                app = [ordered]@{
                    name    = $app.name
                    version = $app.version
                    file    = $file
                    path    = @($app.path)
                    bin     = @($app.bin)
                }
            }
        }

        $pathDirs += Install-KitApp -KitDir $KitDir -Component $script:Components[$name] -Root $Root
    }
    $pathDirs
}

function Build-Wheels($Lock, [string]$Root) {
    $python = Join-Path $Root 'apps\python\current\python.exe'
    $requirements = Join-Path $SourceDir 'python\requirements.txt'
    $key = Get-StringHash ((Get-Content -Raw $requirements) + (Get-LockedVersion $Lock 'python'))
    if (Test-ReusableComponent 'wheels' $key) { return }

    $staged = Join-Path $StageDir 'wheels'
    Remove-Item -Recurse -Force $staged -ErrorAction SilentlyContinue
    Invoke-Native $python -m pip wheel --disable-pip-version-check --no-deps --require-hashes `
        --wheel-dir $staged -r $requirements

    $published = Join-Path $DistDir 'wheels'
    Remove-Item -Recurse -Force $published -ErrorAction SilentlyContinue
    Copy-Item -Recurse $staged $published
    Add-BuiltComponent 'wheels' $key @(
        Get-ChildItem $published -Filter *.whl | ForEach-Object { "dist\wheels\$($_.Name)" }
    )
}

function Build-NodeTools($Lock) {
    $lockFile = Join-Path $SourceDir 'node\package-lock.json'
    if (-not (Test-Path $lockFile)) {
        Write-Host '  no node\package-lock.json, skipping'
        return
    }

    $key = Get-StringHash ((Get-Content -Raw $lockFile) + (Get-LockedVersion $Lock 'node'))
    if (Test-ReusableComponent 'node-tools' $key) { return }

    $staged = Join-Path $StageDir 'node-tools'
    Remove-Item -Recurse -Force $staged -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $staged | Out-Null
    Copy-Item (Join-Path $SourceDir 'node\package.json'), $lockFile $staged
    Invoke-Native npm.cmd ci --prefix $staged --no-audit --no-fund

    New-Zip $staged (Join-Path $DistDir 'node-tools.zip')
    Add-BuiltComponent 'node-tools' $key @('dist\node-tools.zip')
}

function Build-NvimData($Manifest, $Lock, [string]$DotfilesPath) {
    $config = Join-Path $DotfilesPath 'nvim'
    if (-not (Test-Path (Join-Path $config 'init.lua'))) {
        Write-Host '  no nvim\init.lua in the dotfiles, skipping'
        return
    }

    $lazyLock = Join-Path $config 'lazy-lock.json'
    if (-not (Test-Path $lazyLock)) {
        Write-Warning 'nvim\lazy-lock.json is not committed in the dotfiles; plugins are unpinned until it is'
    }

    $parsers = @($Manifest.neovim.treesitter)
    $lazyLockText = if (Test-Path $lazyLock) { Get-Content -Raw $lazyLock } else { '' }
    $key = Get-StringHash ($lazyLockText + ($parsers -join ',') +
        (Get-LockedVersion $Lock 'neovim') + (Get-LockedVersion $Lock 'tree-sitter'))
    if (Test-ReusableComponent 'nvim-data' $key) { return }

    $staged = Join-Path $StageDir 'nvim'
    Remove-Item -Recurse -Force $staged -ErrorAction SilentlyContinue
    $env:XDG_CONFIG_HOME = $DotfilesPath
    $env:XDG_DATA_HOME = $staged
    $env:KIT_TS_PARSERS = $parsers -join ','
    $env:KIT_TS_TIMEOUT_MS = $ParserTimeoutMs
    try {
        Invoke-Nvim '--headless "+Lazy! restore" +qa'
        Invoke-Nvim "--headless -c `"lua dofile([[$SourceDir\nvim-build.lua]])`""
    } finally {
        Remove-Item env:XDG_CONFIG_HOME, env:XDG_DATA_HOME, env:KIT_TS_PARSERS, env:KIT_TS_TIMEOUT_MS
    }

    $dataDir = Join-Path $staged 'nvim-data'
    if (Test-Path $lazyLock) {
        $missing = (Read-Json $lazyLock).PSObject.Properties.Name |
            Where-Object { -not (Test-Path (Join-Path $dataDir "lazy\$_")) }
        if ($missing) { throw "plugins missing after Lazy restore: $($missing -join ', ')" }
    }

    $items = @('lazy', 'site') | Where-Object { Test-Path (Join-Path $dataDir $_) }
    New-Zip $dataDir (Join-Path $DistDir 'nvim-data.zip') $items
    Add-BuiltComponent 'nvim-data' $key @('dist\nvim-data.zip')
}

function Copy-Installer {
    foreach ($file in $InstallerFiles) { Copy-Item (Join-Path $SourceDir $file) $KitDir -Force }
}

function Remove-UnreferencedDistFiles {
    $referenced = @{}
    foreach ($component in $script:Components.Values) {
        foreach ($file in $component.files.PSObject.Properties) {
            $referenced[(Join-Path $KitDir $file.Name)] = $true
        }
    }
    Get-ChildItem $DistDir -Recurse -File |
        Where-Object { -not $referenced.ContainsKey($_.FullName) } | Remove-Item
}

function Write-DistRecord([string]$KitRevision, [string]$DotfilesRevision) {
    Write-Json (Join-Path $KitDir 'dist.json') ([ordered]@{
            schema     = $SchemaVersion
            revision   = $KitRevision
            dotfiles   = $DotfilesRevision
            built      = (Get-Date).ToUniversalTime().ToString('o')
            components = $script:Components
        })
}

$manifest = Read-Json (Join-Path $SourceDir 'packages.json')
$lock = Read-Json (Join-Path $SourceDir 'packages.lock.json')
if ($lock.schema -ne $SchemaVersion) {
    throw "packages.lock.json has schema $($lock.schema), this build expects $SchemaVersion; run 'just lock'"
}

$vars = Get-KitVars $manifest
New-Item -ItemType Directory -Force (Join-Path $DistDir 'apps'), $CacheDir, $StageDir | Out-Null
$script:Previous = if (Test-Path (Join-Path $KitDir 'dist.json')) {
    (Read-Json (Join-Path $KitDir 'dist.json')).components
} else {
    $null
}
$script:Components = [ordered]@{}

Write-Step 'apps'
Set-UserPath -Prepend (Build-Apps $lock $vars.root) -ManagedRoot $vars.root
Enter-MsvcEnvironment

Write-Step 'dotfiles'
$dotfilesRevision = 'none'
if (Sync-Dotfiles -UsbRoot $UsbRoot -RepoRel $manifest.dotfiles.repo -Path $vars.dotfiles) {
    $dotfilesRevision = & git -C $vars.dotfiles describe --always --dirty --abbrev=12
}

Write-Step 'python wheels'
Build-Wheels $lock $vars.root

Write-Step 'node tools'
Build-NodeTools $lock

Write-Step 'neovim'
Build-NvimData $manifest $lock $vars.dotfiles

Write-Step 'installer'
Copy-Installer
Remove-UnreferencedDistFiles
Write-DistRecord $Revision $dotfilesRevision

Write-Host "Kit $Revision (dotfiles $dotfilesRevision) written to $KitDir"
exit 0
