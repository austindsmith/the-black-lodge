# Makes this VM behave like the locked-down work laptop.
$ErrorActionPreference = 'Stop'

# A standard (non-admin) account, for running E:\kit\install.ps1 by hand from the
# console the way it runs at work. The vagrant account is an administrator.
$user = 'worker'
if (-not (Get-LocalUser -Name $user -ErrorAction SilentlyContinue)) {
    $password = ConvertTo-SecureString $user -AsPlainText -Force
    New-LocalUser -Name $user -Password $password -PasswordNeverExpires | Out-Null
    Add-LocalGroupMember -SID 'S-1-5-32-545' -Member $user  # BUILTIN\Users
}

# libvirt isolates the network; prove it, or a passing offline test means nothing.
$online = Test-NetConnection -ComputerName github.com -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
if ($online) { throw 'The work VM can reach github.com; it is supposed to be offline.' }
Write-Host 'Offline, as intended.'
