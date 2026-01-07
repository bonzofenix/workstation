--Set indentation behavior for 2 spaces
vim.opt.tabstop = 2        -- Visual tab width (2 spaces)
vim.opt.softtabstop = 2    -- How many spaces a tab feels like when editing
vim.opt.shiftwidth = 2     -- Number of spaces for indentation
vim.opt.expandtab = true   -- Use spaces instead of tabs

vim.opt.autoindent = true
vim.opt.formatoptions:append("o")
vim.opt.hlsearch = true
vim.opt.backupdir = "/tmp//"
vim.opt.undodir = "/tmp//"
vim.opt.directory = vim.fn.expand("~/.vim/swap//")
vim.opt.listchars = { tab = "\\-", trail = ".", eol = "$" }
vim.opt.list = false
vim.opt.number = true
vim.opt.numberwidth = 1
vim.opt.cursorline = true
vim.opt.visualbell = false
vim.opt.wrap = false
vim.opt.compatible = false
vim.opt.termguicolors = true
vim.opt.modeline = true
vim.opt.clipboard = "unnamed"
vim.opt.splitright = true
vim.opt.wildmode = { "longest", "list" }
vim.opt.laststatus = 2

-- Auto-reload files changed outside of Neovim
vim.opt.autoread = true
-- vim.g.ackprg = "ag --vimgrep"

-- set up folds through treesitter
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldenable = false  -- start with folds closed = false
vim.opt.foldlevelstart = 99 -- so folds are open by default

vim.api.nvim_set_hl(0, "Folded", { fg = "#888888", bg = "#1e1e1e" })
vim.opt.foldtext = "v:lua.FoldText()"
function _G.FoldText()
  local line = vim.fn.getline(vim.v.foldstart)
  local lines_count = vim.v.foldend - vim.v.foldstart + 1
  return "📂 " .. line .. "  … [" .. lines_count .. " lines]"
end
