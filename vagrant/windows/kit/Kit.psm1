# Shared helpers for build.ps1 (builder VM) and install.ps1 / test.ps1 (work laptop).
# Must stay Windows PowerShell 5.1 compatible and pure ASCII: 5.1 reads BOM-less
# scripts as ANSI, and it's what the work laptop has.

function Invoke-Native {
    # Runs an external program and throws on a non-zero exit code (5.1 doesn't).
    # Deliberately not an advanced function, so flags like -C pass straight through.
    $exe = $args[0]
    $rest = @($args | Select-Object -Skip 1)
    & $exe @rest
    if ($LASTEXITCODE -ne 0) { throw "'$exe $rest' failed with exit code $LASTEXITCODE" }
}

function Invoke-Nvim([string]$Arguments, [int]$TimeoutMinutes = 30) {
    # nvim --headless waits forever if the config errors before `+qa`; never hang.
    $p = Start-Process nvim -ArgumentList $Arguments -NoNewWindow -PassThru
    $null = $p.Handle  # without this, 5.1 can't read ExitCode after exit
    if (-not $p.WaitForExit($TimeoutMinutes * 60000)) {
        $p.Kill()
        throw "nvim $Arguments timed out after $TimeoutMinutes minutes"
    }
    if ($p.ExitCode -ne 0) { throw "nvim $Arguments failed with exit code $($p.ExitCode)" }
}

function Get-Sha256([string]$Path) {
    (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Get-StringHash([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        -join ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)) | ForEach-Object { $_.ToString('x2') })
    } finally { $sha.Dispose() }
}

function Read-Json([string]$Path) {
    Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
}

function Write-Json([string]$Path, $Object) {
    [IO.File]::WriteAllText($Path, ($Object | ConvertTo-Json -Depth 10))
}

# Windows' bundled bsdtar handles zip and tar.gz, and is much faster than Expand-Archive.
$script:Tar = Join-Path $env:SystemRoot 'System32\tar.exe'

function Expand-Zip([string]$Archive, [string]$Destination) {
    New-Item -ItemType Directory -Force $Destination | Out-Null
    Invoke-Native $script:Tar -xf $Archive -C $Destination
}

function New-Zip([string]$Source, [string]$Destination, [string[]]$Items = @('.')) {
    $part = "$Destination.part"
    Remove-Item -LiteralPath $part -ErrorAction SilentlyContinue
    Invoke-Native $script:Tar -c --format zip -f $part -C $Source @Items
    Move-Item -Force -LiteralPath $part $Destination
}

function Get-KitVars($Manifest) {
    # Placeholders usable in packages.json: {home} {localappdata} {appdata} {root} {dotfiles}
    $vars = @{ home = $HOME; localappdata = $env:LOCALAPPDATA; appdata = $env:APPDATA }
    $vars.root = Expand-KitString $Manifest.root $vars
    $vars.dotfiles = Expand-KitString $Manifest.dotfiles.path $vars
    $vars
}

function Expand-KitString([string]$Text, [hashtable]$Vars) {
    foreach ($k in $Vars.Keys) { $Text = $Text.Replace("{$k}", $Vars[$k]) }
    $Text
}

function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Set-UserPath([string[]]$Dirs, [string]$Root) {
    # Puts $Dirs at the front of the user PATH and drops stale entries under $Root
    # (apps removed from the manifest). Other entries are untouched, %VARS% included.
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
    try {
        $current = $key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
        $keep = @($current -split ';' | Where-Object {
            $_ -and ($Dirs -notcontains $_) -and
            -not $_.StartsWith("$Root\", [StringComparison]::OrdinalIgnoreCase)
        })
        $new = (@($Dirs) + $keep) -join ';'
        if ($new -ne $current) { $key.SetValue('Path', $new, [Microsoft.Win32.RegistryValueKind]::ExpandString) }
    } finally { $key.Close() }
    # A raw registry write doesn't notify running programs (Explorer, new terminals);
    # SetEnvironmentVariable does (WM_SETTINGCHANGE), so set KIT_ROOT through it after.
    [Environment]::SetEnvironmentVariable('KIT_ROOT', $Root, 'User')
    Update-SessionPath
}

function Set-UserEnv([string]$Name, [string]$Value) {
    if ([Environment]::GetEnvironmentVariable($Name, 'User') -ne $Value) {
        [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
    }
    Set-Item -Path "env:$Name" -Value $Value
}

function Set-Junction([string]$Link, [string]$Target) {
    # Directory junctions need no admin rights or Developer Mode, unlike symlinks.
    $item = Get-Item -LiteralPath $Link -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType -eq 'Junction') {
        # Deletes only the link. Remove-Item -Recurse on a junction in 5.1 can empty the target.
        [IO.Directory]::Delete($Link, $false)
    } elseif ($item) {
        $backup = "$Link.bak-$(Get-Date -Format yyyyMMddHHmmss)"
        Write-Warning "$Link already exists; moved it to $backup"
        Move-Item -LiteralPath $Link $backup
    }
    New-Item -ItemType Directory -Force (Split-Path $Link) | Out-Null
    New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
}

function Assert-KitFiles([string]$KitDir, $Component) {
    foreach ($f in $Component.files.PSObject.Properties) {
        $path = Join-Path $KitDir $f.Name
        if (-not (Test-Path -LiteralPath $path)) { throw "$path is missing; rebuild the kit" }
        if ((Get-Sha256 $path) -ne $f.Value) { throw "$path fails its checksum; the stick may be corrupt, rebuild the kit" }
    }
}

function Install-KitApp([string]$KitDir, $Component, [string]$Root) {
    # Unzips one app to <root>\apps\<name>\<version> (skipped if present), points
    # <name>\current at it and returns the app's PATH directories. Upgrades only
    # move the junction, so PATH never has to change.
    $app = $Component.app
    $base = Join-Path $Root "apps\$($app.name)"
    $dest = Join-Path $base $app.version
    if (-not (Test-Path $dest)) {
        Write-Host "  $($app.name) $($app.version)"
        Assert-KitFiles $KitDir $Component
        $partial = "$dest.partial"
        Remove-Item -Recurse -Force -LiteralPath $partial -ErrorAction SilentlyContinue
        Expand-Zip (Join-Path $KitDir $app.file) $partial
        Rename-Item -LiteralPath $partial $app.version
    }
    Set-Junction (Join-Path $base 'current') $dest
    foreach ($p in $app.path) {
        if ($p -eq '.') { Join-Path $base 'current' } else { Join-Path $base "current\$p" }
    }
}

function Sync-Dotfiles([string]$UsbRoot, [string]$RepoRel, [string]$Path) {
    # Clones the dotfiles from the bare repo on the stick, or fast-forwards an existing
    # clone. `origin` always points at the stick's current drive letter, so plain
    # `git pull` / `git push` sync with it. Local commits are never rewritten.
    # Returns $true when a clone is available. Git output goes to the host, not the
    # pipeline, so it can't leak into the return value.
    $remote = Join-Path $UsbRoot $RepoRel
    if (-not (Test-Path $remote)) {
        Write-Warning "No dotfiles repo at $remote; skipping dotfiles"
        return $false
    }
    # The stick's files are owned by whoever created them (or nobody, on exFAT).
    $safe = $remote.Replace('\', '/')
    if (@(& git config --global --get-all safe.directory) -notcontains $safe) {
        Invoke-Native git config --global --add safe.directory $safe
    }
    if (-not (Test-Path (Join-Path $Path '.git'))) {
        New-Item -ItemType Directory -Force (Split-Path $Path) | Out-Null
        Invoke-Native git clone $remote $Path | Out-Host
    } else {
        Invoke-Native git -C $Path remote set-url origin $remote | Out-Host
        Invoke-Native git -C $Path fetch origin | Out-Host
        & git -C $Path merge --ff-only '@{upstream}' | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "$Path has diverged from the stick; merge it by hand (git pull), then re-run."
        }
    }
    $true
}

function Set-ProfileStub([string]$Target) {
    # Windows PowerShell 5.1 and PowerShell 7 each get a one-line profile that
    # dot-sources the real one from the dotfiles clone, so edits there apply everywhere.
    $docs = [Environment]::GetFolderPath('MyDocuments')  # follows OneDrive redirection
    $marker = '# managed by kit install.ps1'
    $stub = "$marker`r`nif (Test-Path '$Target') { . '$Target' }`r`n"
    foreach ($dir in 'WindowsPowerShell', 'PowerShell') {
        $path = Join-Path $docs "$dir\profile.ps1"
        if ((Test-Path $path) -and -not (Select-String -LiteralPath $path -SimpleMatch $marker -Quiet)) {
            Write-Warning "$path isn't managed by kit; add this line to it yourself: . '$Target'"
            continue
        }
        New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
        [IO.File]::WriteAllText($path, $stub)
    }
}
