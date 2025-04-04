-- ~/.config/nvim/lua/keymaps.lua
vim.g.mapleader = ","
local keymap = vim.keymap.set

-- Telescope bindings
keymap("n", "<leader>ff", "<cmd>Telescope find_files<cr>")
keymap("n", "<leader>fg", "<cmd>Telescope live_grep<cr>")
keymap("n", "<leader>fb", "<cmd>Telescope buffers<cr>")
keymap("n", "<leader>fh", "<cmd>Telescope help_tags<cr>")
keymap("n", "<leader>gw", "<cmd>Telescope grep_string<cr>")

-- go back to last buffer
vim.keymap.set("n", "gb", "<cmd>b#<CR>", { desc = "Go back to previous buffer" })

-- Find & Replace current word
keymap("n", "<leader>r", ":%s/\\<<C-r><C-w>\\>//gc<left><left><left>")

-- Zoom
vim.cmd [[map <leader>z <Plug>(zoom-toggle)]]

-- Git blame
vim.cmd [[map <leader>g :Git blame<Enter>]]

-- Copilot navigation
vim.cmd [[
imap <silent> <C-j> <Plug>(copilot-next)
imap <silent> <C-k> <Plug>(copilot-previous)
imap <silent> <C-l> <Plug>(copilot-accept-word)
]]

-- Whitespace and cleanup maps
vim.cmd [[
map ;fws :%s/\s\+$//
map ;n GoZ<Esc>:g/^[ <Tab>]*$/.,/[^ <Tab>]/-j<CR>Gdd
map ;c :,s/^[ <Tab>]*//g<CR>i
]]

