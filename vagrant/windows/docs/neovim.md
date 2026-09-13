# Neovim, offline

The builder runs your real configuration headless and ships the result, so Neovim at
work never downloads anything.

## What the build does

1. Points Neovim at `<dotfiles>\nvim` for config and a clean staging directory for data.
2. Runs `nvim --headless "+Lazy! restore" +qa`, which installs the exact commits in
   `lazy-lock.json` and runs plugin build steps with MSVC and CMake available.
3. Runs `nvim-build.lua`, which compiles the parsers listed under
   `neovim.treesitter` in `packages.json` and fails if any is missing afterwards.
4. Verifies every plugin in the lockfile exists on disk, because lazy.nvim does not
   fail the process when a clone or build fails.
5. Packs `lazy\` and `site\` into `dist\nvim-data.zip`.

At work, `install.ps1` replaces `%LOCALAPPDATA%\nvim-data\lazy` and the `site`
subdirectories it ships, leaving shada, undo history and `site\spell` alone, and links
`%LOCALAPPDATA%\nvim` to `<dotfiles>\nvim`.

## What your config must do

- **Commit `nvim/lazy-lock.json`.** It is what pins plugins; without it the build warns
  and the set is whatever was newest that day. Run `:Lazy update` in the builder, then
  commit the diff.
- **Use nvim-treesitter's `main` branch and do not lazy-load it.** The build calls
  `require('nvim-treesitter').install(...)`, which only exists there. Start
  highlighting per filetype with `vim.treesitter.start()`; never call `install()` at
  startup.
- **Do not use Mason.** Its shims and virtual environments contain absolute paths that
  break under a different username. Tools come from the kit and are found on PATH:
  `lua-language-server`, `stylua`, `ruff`, `basedpyright` (a uv tool) and `prettier`
  (an npm tool). `vim.lsp.enable()`, `conform.nvim` and `nvim-lint` all resolve
  executables from PATH.
- **Turn off anything that reaches the network at startup:** in `lazy.setup`, set
  `checker = { enabled = false }` and `rocks = { enabled = false }` unless you need
  luarocks.
- Prefer plugins with no download step. Where one exists, make sure it runs during
  `Lazy! restore` (a `build` key) rather than on first use; `blink.cmp`, for instance,
  should either use its Lua fuzzy implementation or build its binary at install time.

## Starting point

If `<dotfiles>\nvim\init.lua` does not exist yet the build skips this stage. A config
that satisfies the rules above looks roughly like:

```lua
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({ 'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git', '--branch=stable', lazypath })
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  spec = {
    { 'nvim-treesitter/nvim-treesitter', branch = 'main', lazy = false },
    { 'neovim/nvim-lspconfig' },
    { 'stevearc/conform.nvim', opts = { formatters_by_ft = { lua = { 'stylua' }, python = { 'ruff_format' } } } },
  },
  checker = { enabled = false },
  rocks = { enabled = false },
})

vim.lsp.enable({ 'lua_ls', 'basedpyright', 'ruff' })

vim.api.nvim_create_autocmd('FileType', {
  callback = function(args)
    pcall(vim.treesitter.start, args.buf)
  end,
})
```

Parsers come from `packages.json`, not from the plugin spec: add the language there and
rebuild.

## Checking it

`kit/test.ps1` (run by `just work`, or directly from the stick) loads Neovim headless,
asserts lazy.nvim is present and that every listed parser can be loaded. For anything
deeper, open the work VM with `just console` and run `:checkhealth` there, where there
is genuinely no network to fall back on.
