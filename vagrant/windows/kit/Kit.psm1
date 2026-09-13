#Requires -Version 5.1

$script:Tar = Join-Path $env:SystemRoot 'System32\tar.exe'

function Write-Step([string]$Message) {
    Write-Host "==> $Message"
}

function Invoke-Native {
    $executable = $args[0]
    $arguments = @($args | Select-Object -Skip 1)
    & $executable @arguments
    if ($LASTEXITCODE -ne 0) { throw "'$executable $arguments' failed with exit code $LASTEXITCODE" }
}

function Invoke-Nvim([string]$Arguments, [int]$TimeoutMinutes = 30) {
    $process = Start-Process nvim -ArgumentList $Arguments -NoNewWindow -PassThru
    $null = $process.Handle
    if (-not $process.WaitForExit($TimeoutMinutes * 60000)) {
        $process.Kill()
        throw "nvim $Arguments timed out after $TimeoutMinutes minutes"
    }
    if ($process.ExitCode -ne 0) { throw "nvim $Arguments failed with exit code $($process.ExitCode)" }
}

function Get-Sha256([string]$Path) {
    (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Get-StringHash([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        -join ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)) | ForEach-Object { $_.ToString('x2') })
    } finally {
        $sha.Dispose()
    }
}

function Read-Json([string]$Path) {
    Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
}

function Write-Json([string]$Path, $Object) {
    [IO.File]::WriteAllText($Path, ($Object | ConvertTo-Json -Depth 10))
}

function Expand-Zip([string]$Archive, [string]$Destination) {
    New-Item -ItemType Directory -Force $Destination | Out-Null
    Invoke-Native $script:Tar -xf $Archive -C $Destination
}

function New-Zip([string]$Source, [string]$Destination, [string[]]$Items = @('.')) {
    $partial = "$Destination.part"
    Remove-Item -LiteralPath $partial -ErrorAction SilentlyContinue
    Invoke-Native $script:Tar -c --format zip -f $partial -C $Source @Items
    Move-Item -Force -LiteralPath $partial $Destination
}

function Get-KitVars($Manifest) {
    $vars = @{ home = $HOME; localappdata = $env:LOCALAPPDATA; appdata = $env:APPDATA }
    $vars.root = Expand-KitString $Manifest.root $vars
    $vars.dotfiles = Expand-KitString $Manifest.dotfiles.path $vars
    $vars
}

function Expand-KitString([string]$Text, [hashtable]$Vars) {
    foreach ($name in $Vars.Keys) { $Text = $Text.Replace("{$name}", $Vars[$name]) }
    $Text
}

function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Publish-EnvironmentChange([string]$Root) {
    [Environment]::SetEnvironmentVariable('KIT_ROOT', $Root, 'User')
}

function Set-UserPath([string[]]$Prepend, [string]$ManagedRoot) {
    $Prepend = @($Prepend | Where-Object { $_ } | Select-Object -Unique)
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
    try {
        $current = $key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
        $kept = @($current -split ';' | Where-Object {
                $_ -and ($Prepend -notcontains $_) -and
                -not $_.StartsWith("$ManagedRoot\", [StringComparison]::OrdinalIgnoreCase)
            })
        $updated = (@($Prepend) + $kept) -join ';'
        if ($updated -ne $current) {
            $key.SetValue('Path', $updated, [Microsoft.Win32.RegistryValueKind]::ExpandString)
        }
    } finally {
        $key.Close()
    }
    Publish-EnvironmentChange $ManagedRoot
    Update-SessionPath
}

function Set-UserEnv([string]$Name, [string]$Value) {
    if ([Environment]::GetEnvironmentVariable($Name, 'User') -ne $Value) {
        [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
    }
    Set-Item -Path "env:$Name" -Value $Value
}

function Set-Junction([string]$Link, [string]$Target) {
    $existing = Get-Item -LiteralPath $Link -Force -ErrorAction SilentlyContinue
    if ($existing -and $existing.LinkType -eq 'Junction') {
        [IO.Directory]::Delete($Link, $false)
    } elseif ($existing) {
        $backup = "$Link.bak-$(Get-Date -Format yyyyMMddHHmmss)"
        Write-Warning "$Link already exists; moved it to $backup"
        Move-Item -LiteralPath $Link $backup
    }
    New-Item -ItemType Directory -Force (Split-Path $Link) | Out-Null
    New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
}

function Assert-KitFiles([string]$KitDir, $Component) {
    foreach ($file in $Component.files.PSObject.Properties) {
        $path = Join-Path $KitDir $file.Name
        if (-not (Test-Path -LiteralPath $path)) { throw "$path is missing; rebuild the kit" }
        if ((Get-Sha256 $path) -ne $file.Value) {
            throw "$path fails its checksum; the stick may be damaged, rebuild the kit"
        }
    }
}

function Install-KitApp([string]$KitDir, $Component, [string]$Root) {
    $app = $Component.app
    $appRoot = Join-Path $Root "apps\$($app.name)"
    $versionDir = Join-Path $appRoot $app.version

    if (-not (Test-Path $versionDir)) {
        Write-Host "  $($app.name) $($app.version)"
        Assert-KitFiles $KitDir $Component
        $partial = "$versionDir.partial"
        Remove-Item -Recurse -Force -LiteralPath $partial -ErrorAction SilentlyContinue
        Expand-Zip (Join-Path $KitDir $app.file) $partial
        Rename-Item -LiteralPath $partial $app.version
    }

    Set-Junction (Join-Path $appRoot 'current') $versionDir
    foreach ($relative in $app.path) {
        if ($relative -eq '.') { Join-Path $appRoot 'current' }
        else { Join-Path $appRoot "current\$relative" }
    }
}

function Sync-Dotfiles([string]$UsbRoot, [string]$RepoRel, [string]$Path) {
    $remote = Join-Path $UsbRoot $RepoRel
    if (-not (Test-Path $remote)) {
        Write-Warning "No dotfiles repository at $remote; skipping dotfiles"
        return $false
    }

    $remoteForGit = $remote.Replace('\', '/')
    if (@(& git config --global --get-all safe.directory) -notcontains $remoteForGit) {
        Invoke-Native git config --global --add safe.directory $remoteForGit | Out-Host
    }

    if (-not (Test-Path (Join-Path $Path '.git'))) {
        New-Item -ItemType Directory -Force (Split-Path $Path) | Out-Null
        Invoke-Native git clone $remote $Path | Out-Host
    } else {
        Invoke-Native git -C $Path remote set-url origin $remote | Out-Host
        Invoke-Native git -C $Path fetch origin | Out-Host
        & git -C $Path merge --ff-only '@{upstream}' | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "$Path has diverged from the stick; reconcile it with git, then run this again"
        }
    }
    $true
}

function Set-ProfileStub([string]$Target) {
    $documents = [Environment]::GetFolderPath('MyDocuments')
    $marker = '# managed by kit install.ps1'
    $stub = "$marker`r`nif (Test-Path '$Target') { . '$Target' }`r`n"

    foreach ($shell in 'WindowsPowerShell', 'PowerShell') {
        $profilePath = Join-Path $documents "$shell\profile.ps1"
        if ((Test-Path $profilePath) -and -not (Select-String -LiteralPath $profilePath -SimpleMatch $marker -Quiet)) {
            Write-Warning "$profilePath is not managed by kit; add this line to it yourself: . '$Target'"
            continue
        }
        New-Item -ItemType Directory -Force (Split-Path $profilePath) | Out-Null
        [IO.File]::WriteAllText($profilePath, $stub)
    }
}

function Get-EffectiveExecutionPolicy {
    $scoped = Get-ExecutionPolicy -List |
        Where-Object { $_.Scope -ne 'Process' -and $_.ExecutionPolicy -ne 'Undefined' } |
        Select-Object -First 1
    if ($scoped) { [string]$scoped.ExecutionPolicy } else { 'Restricted' }
}
