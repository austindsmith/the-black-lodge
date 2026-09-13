-- Run by build.ps1 as `nvim --headless` with the dotfiles config loaded, after
-- `Lazy! restore`. Compiles the treesitter parsers listed in packages.json
-- (neovim.treesitter) with nvim-treesitter's `main` branch and the builder's MSVC.
local function main()
  local parsers = vim.split(vim.env.KIT_TS_PARSERS or '', ',', { trimempty = true })
  if #parsers == 0 then
    return true
  end

  local ok, ts = pcall(require, 'nvim-treesitter')
  if not ok then
    io.stderr:write('kit: nvim-treesitter is not in the Neovim config; skipping parsers\n')
    return true
  end
  if type(ts.install) ~= 'function' then
    error('kit: needs the nvim-treesitter `main` branch (the old `master` API has no install())')
  end

  ts.install(parsers):wait(30 * 60 * 1000)

  local site = vim.fn.stdpath('data') .. '/site/parser/'
  local missing = vim.tbl_filter(function(lang)
    return vim.fn.glob(site .. lang .. '.*') == ''
  end, parsers)
  if #missing > 0 then
    error('kit: parsers failed to build: ' .. table.concat(missing, ', '))
  end
  return true
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
  io.stderr:write(tostring(err) .. '\n')
end
-- Always exit, or a headless nvim sits there until build.ps1's timeout.
vim.cmd(ok and 'qa!' or 'cq!')
