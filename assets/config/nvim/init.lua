-- Add lazy.nvim to runtime path
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  error("lazy.nvim not found! Run the git clone command first.")
end
vim.opt.rtp:prepend(lazypath)

-- Load your plugins
require("plugins")

-- Load your options
require("options")

-- Load your lsp config
require("lsp")

-- Load your autocmds
require("autocmds")

-- Load your keymaps
require("keymaps")

-- Load your colorscheme
vim.cmd.colorscheme("gruvbox")

