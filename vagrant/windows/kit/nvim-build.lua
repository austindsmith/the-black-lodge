local function install_parsers()
  local parsers = vim.split(vim.env.KIT_TS_PARSERS or '', ',', { trimempty = true })
  if #parsers == 0 then
    return
  end

  local loaded, treesitter = pcall(require, 'nvim-treesitter')
  if not loaded then
    error('nvim-treesitter is not in the Neovim config; add it, or clear neovim.treesitter in packages.json')
  end
  if type(treesitter.install) ~= 'function' then
    error('nvim-treesitter must be the main branch; the master branch has no install()')
  end

  treesitter.install(parsers):wait(tonumber(vim.env.KIT_TS_TIMEOUT_MS) or 1800000)

  local parser_dir = vim.fn.stdpath('data') .. '/site/parser/'
  local missing = vim.tbl_filter(function(language)
    return vim.fn.glob(parser_dir .. language .. '.*') == ''
  end, parsers)
  if #missing > 0 then
    error('parsers failed to build: ' .. table.concat(missing, ', '))
  end
end

local ok, err = xpcall(install_parsers, debug.traceback)
if not ok then
  io.stderr:write(tostring(err) .. '\n')
end
vim.cmd(ok and 'qa!' or 'cq!')
