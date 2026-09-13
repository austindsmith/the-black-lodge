#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

$StandardUser = 'worker'
$UsersGroupSid = 'S-1-5-32-545'

function New-StandardUser([string]$Name) {
    if (Get-LocalUser -Name $Name -ErrorAction SilentlyContinue) { return }
    $password = ConvertTo-SecureString $Name -AsPlainText -Force
    New-LocalUser -Name $Name -Password $password -PasswordNeverExpires | Out-Null
    Add-LocalGroupMember -SID $UsersGroupSid -Member $Name
}

function Assert-Offline {
    $reachable = Test-NetConnection -ComputerName github.com -Port 443 `
        -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($reachable) { throw 'This VM can reach github.com; the work VM is supposed to be offline' }
    Write-Host 'Offline, as intended'
}

New-StandardUser $StandardUser
Assert-Offline
