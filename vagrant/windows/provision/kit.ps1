#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

function Wait-KitVolume([string]$Label, [int]$TimeoutSeconds = 30) {
    foreach ($attempt in 1..$TimeoutSeconds) {
        $volume = Get-Volume -FileSystemLabel $Label -ErrorAction SilentlyContinue |
            Where-Object DriveLetter | Select-Object -First 1
        if ($volume) { return $volume }
        Start-Sleep -Seconds 1
    }
    $null
}

$volume = Wait-KitVolume $env:KIT_USB_LABEL
if (-not $volume) {
    Write-Warning "USB stick '$env:KIT_USB_LABEL' is not attached; skipping '$env:KIT_ACTION'. Plug it in, run 'just usb-attach', then provision again."
    exit 0
}
$usb = "$($volume.DriveLetter):"

if ($env:KIT_ACTION -eq 'build') {
    & C:\kit-src\build.ps1 -UsbRoot "$usb\" -Revision $env:KIT_REVISION
    exit $LASTEXITCODE
}

$script = "$usb\kit\$env:KIT_ACTION.ps1"
if (-not (Test-Path $script)) {
    Write-Warning "$script was not found; build the kit first with 'just build'"
    exit 0
}

& $script
exit $LASTEXITCODE
