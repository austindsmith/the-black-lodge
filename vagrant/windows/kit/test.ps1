#Requires -Version 5.1

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Kit.psm1') -Force

$KitDir = $PSScriptRoot

function Test-AppBinaries($Dist, [string]$KitRoot) {
    $failures = @()
    foreach ($component in $Dist.components.PSObject.Properties) {
        $app = $component.Value.app
        if (-not $app) { continue }

        foreach ($binary in $app.bin) {
            $name = Split-Path $binary -Leaf
            $resolved = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if (-not $resolved) {
                $failures += "$name ($($app.name)) is not on PATH"
            } elseif (-not $resolved.Source.StartsWith($KitRoot, [StringComparison]::OrdinalIgnoreCase)) {
                Write-Warning "$name resolves to $($resolved.Source), which shadows the kit's copy"
            }
        }
    }
    $failures
}

function Test-Neovim($Dist, [string[]]$Parsers) {
    if (-not $Dist.components.'nvim-data') { return }

    $probe = Join-Path $env:TEMP 'kit-test.lua'
    Set-Content -Path $probe -Encoding ASCII -Value @'
local ok, err = pcall(function()
  assert(pcall(require, 'lazy'), 'lazy.nvim did not load')
  for _, lang in ipairs(vim.split(vim.env.KIT_TS_PARSERS or '', ',', { trimempty = true })) do
    assert(vim.treesitter.language.add(lang), 'no treesitter parser for ' .. lang)
  end
end)
if not ok then io.stderr:write(tostring(err) .. '\n') end
vim.cmd(ok and 'qa!' or 'cq!')
'@
    $env:KIT_TS_PARSERS = $Parsers -join ','
    try {
        Invoke-Nvim "--headless -c `"lua dofile([[$probe]])`"" -TimeoutMinutes 2
    } catch {
        "neovim: $_"
    } finally {
        Remove-Item $probe, env:KIT_TS_PARSERS -ErrorAction SilentlyContinue
    }
}

function Test-PythonTools([string[]]$Tools) {
    if ($Tools.Count -eq 0) { return }

    $installed = (& uv tool list) -join "`n"
    foreach ($tool in $Tools) {
        if ($installed -notmatch "(?m)^$([regex]::Escape($tool)) v") { "python tool $tool is not installed" }
    }
}

$manifest = Read-Json (Join-Path $KitDir 'packages.json')
$dist = Read-Json (Join-Path $KitDir 'dist.json')
$kitRoot = (Get-KitVars $manifest).root
Update-SessionPath

$failures = @()
$failures += Test-AppBinaries $dist $kitRoot
$failures += Test-Neovim $dist @($manifest.neovim.treesitter)
$failures += Test-PythonTools @($manifest.python.tools)
$failures = @($failures | Where-Object { $_ })

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host "FAIL $_" -ForegroundColor Red }
    exit 1
}

Write-Host "kit $($dist.revision) OK" -ForegroundColor Green
exit 0
