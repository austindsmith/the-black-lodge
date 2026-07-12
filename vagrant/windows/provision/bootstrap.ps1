if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = `
    [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString(
    'https://community.chocolatey.org/install.ps1'
    ))
}

$env:Path += ";$env:ALLUSERSPROFILE\\chocolatey\\bin"

if (!(Get-Command rsync -ErrorAction SilentlyContinue)) {
    choco install rsync -y --force
}
