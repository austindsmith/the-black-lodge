<#
.SYNOPSIS
Smoke-tests an installed kit, offline: every declared binary resolves from the kit,
Neovim loads its plugins and parsers, and the Python tools are installed.
#>
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Kit.psm1') -Force

$manifest = Read-Json (Join-Path $PSScriptRoot 'packages.json')
$dist     = Read-Json (Join-Path $PSScriptRoot 'dist.json')
$root     = (Get-KitVars $manifest).root
Update-SessionPath  # pick up what install.ps1 wrote, even in an old shell
$failures = New-Object System.Collections.Generic.List[string]

foreach ($c in $dist.components.PSObject.Properties) {
    $app = $c.Value.app
    if (-not $app) { continue }
    foreach ($bin in $app.bin) {
        $name = Split-Path $bin -Leaf
        $cmd = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $cmd) {
            $failures.Add("$name ($($app.name)) is not on PATH")
        } elseif (-not $cmd.Source.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
            # The machine PATH comes before the user PATH, and only an admin can change it.
            Write-Warning "$name resolves to $($cmd.Source), which shadows the kit's copy"
        }
    }
}

if ($dist.components.'nvim-data') {
    $lua = Join-Path $env:TEMP 'kit-test.lua'
    Set-Content -Path $lua -Encoding ASCII -Value @'
local ok, err = pcall(function()
  assert(pcall(require, 'lazy'), 'lazy.nvim did not load')
  for _, lang in ipairs(vim.split(vim.env.KIT_TS_PARSERS or '', ',', { trimempty = true })) do
    assert(vim.treesitter.language.add(lang), 'no treesitter parser for ' .. lang)
  end
end)
if not ok then io.stderr:write(tostring(err) .. '\n') end
vim.cmd(ok and 'qa!' or 'cq!')
'@
    $env:KIT_TS_PARSERS = @($manifest.neovim.treesitter) -join ','
    try { Invoke-Nvim "--headless -c `"lua dofile([[$lua]])`"" -TimeoutMinutes 2 }
    catch { $failures.Add("neovim: $_") }
    finally { Remove-Item $lua, env:KIT_TS_PARSERS -ErrorAction SilentlyContinue }
}

$tools = @($manifest.python.tools)
if ($tools.Count -gt 0) {
    $installed = (& uv tool list) -join "`n"
    foreach ($t in $tools) {
        if ($installed -notmatch "(?m)^$([regex]::Escape($t)) v") { $failures.Add("python tool $t is not installed") }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host "FAIL $_" -ForegroundColor Red }
    exit 1
}
Write-Host "kit $($dist.revision) OK" -ForegroundColor Green
exit 0
