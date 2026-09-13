# Builder-only toolchain. MSVC Build Tools compile Python sdists, tree-sitter parsers
# and Neovim plugins with native build steps. None of it ships to the USB stick.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$msvc = if (Test-Path $vswhere) {
    & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
}
if (-not $msvc) {
    Write-Host 'Installing Visual Studio Build Tools (C++ workload); this takes a while...'
    $installer = Join-Path $env:TEMP 'vs_BuildTools.exe'
    curl.exe --fail --location --silent --show-error --output $installer https://aka.ms/vs/17/release/vs_BuildTools.exe
    if ($LASTEXITCODE -ne 0) { throw "downloading the Build Tools installer failed ($LASTEXITCODE)" }
    $p = Start-Process $installer -Wait -PassThru -ArgumentList @(
        '--quiet', '--wait', '--norestart', '--nocache',
        '--add', 'Microsoft.VisualStudio.Workload.VCTools', '--includeRecommended')
    # 3010 is "succeeded, reboot suggested"; command-line builds work without one.
    if ($p.ExitCode -notin 0, 3010) { throw "Build Tools install failed (exit $($p.ExitCode))" }
}

# Commits made here (e.g. while sketching dotfiles) carry the host's git identity.
$gitconfig = Join-Path $HOME '.gitconfig'
if ($env:GIT_EMAIL -and -not (Test-Path $gitconfig)) {
    [IO.File]::WriteAllLines($gitconfig, [string[]]@('[user]', "`tname = $env:GIT_NAME", "`temail = $env:GIT_EMAIL"))
}
