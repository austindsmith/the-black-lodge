#Requires -Version 5.1

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$BuildToolsUrl = 'https://aka.ms/vs/17/release/vs_BuildTools.exe'
$CppToolsComponent = 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64'
$RebootRequiredExitCode = 3010

function Get-MsvcInstallPath {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) { return $null }
    & $vswhere -latest -products * -requires $CppToolsComponent -property installationPath
}

function Install-BuildTools {
    Write-Host 'Installing Visual Studio Build Tools (C++ workload); this takes a while'
    $installer = Join-Path $env:TEMP 'vs_BuildTools.exe'
    curl.exe --fail --location --silent --show-error --output $installer $BuildToolsUrl
    if ($LASTEXITCODE -ne 0) { throw "downloading the Build Tools installer failed ($LASTEXITCODE)" }

    $process = Start-Process $installer -Wait -PassThru -ArgumentList @(
        '--quiet', '--wait', '--norestart', '--nocache',
        '--add', 'Microsoft.VisualStudio.Workload.VCTools', '--includeRecommended')
    if ($process.ExitCode -notin 0, $RebootRequiredExitCode) {
        throw "Build Tools install failed (exit $($process.ExitCode))"
    }
}

function Set-GitIdentity([string]$Name, [string]$Email) {
    $gitconfig = Join-Path $HOME '.gitconfig'
    if (-not $Email -or (Test-Path $gitconfig)) { return }
    [IO.File]::WriteAllLines($gitconfig, [string[]]@('[user]', "`tname = $Name", "`temail = $Email"))
}

if (-not (Get-MsvcInstallPath)) { Install-BuildTools }
Set-GitIdentity $env:GIT_NAME $env:GIT_EMAIL
