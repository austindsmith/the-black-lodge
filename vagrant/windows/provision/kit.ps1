# Runs one kit step against the USB stick passed through to this VM.
# Set by the Vagrantfile: KIT_ACTION (build|install|test), KIT_USB_LABEL, KIT_REVISION.
$ErrorActionPreference = 'Stop'

# Windows mounts a passed-through stick a few seconds after boot.
$volume = $null
foreach ($i in 1..30) {
    $volume = Get-Volume -FileSystemLabel $env:KIT_USB_LABEL -ErrorAction SilentlyContinue |
        Where-Object DriveLetter | Select-Object -First 1
    if ($volume) { break }
    Start-Sleep -Seconds 1
}
if (-not $volume) {
    Write-Warning "USB stick '$env:KIT_USB_LABEL' is not attached; skipping '$env:KIT_ACTION'. Plug it in, 'just usb-attach', then re-provision."
    exit 0
}
$usb = "$($volume.DriveLetter):"

if ($env:KIT_ACTION -eq 'build') {
    & C:\kit-src\build.ps1 -UsbRoot "$usb\" -Revision $env:KIT_REVISION
    exit 0
}

# install/test run from the stick itself, exactly as they will at work.
$script = "$usb\kit\$env:KIT_ACTION.ps1"
if (-not (Test-Path $script)) {
    Write-Warning "$script not found; build the kit first ('just build')."
    exit 0
}
& $script
exit $LASTEXITCODE
