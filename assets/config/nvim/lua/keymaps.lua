-- ~/.config/nvim/lua/keymaps.lua
vim.g.mapleader = ","
local keymap = vim.keymap.set

-- Telescope bindings
keymap("n", "<leader>ff", "<cmd>Telescope find_files<cr>")
keymap("n", "<leader>fg", "<cmd>Telescope live_grep<cr>")
keymap("n", "<leader>fb", "<cmd>Telescope buffers<cr>")
keymap("n", "<leader>fh", "<cmd>Telescope help_tags<cr>")
keymap("n", "<leader>gw", "<cmd>Telescope grep_string<cr>")
keymap("n", "<leader>gW", function()
  local word = vim.fn.expand("<cWORD>")
  require('telescope.builtin').grep_string({ search = word })
end, { desc = "Grep WORD under cursor" })



-- go back to last buffer
vim.keymap.set("n", "gb", "<cmd>b#<CR>", { desc = "Go back to previous buffer" })

-- Find & Replace current word
keymap("n", "<leader>r", ":%s/\\<<C-r><C-w>\\>//gc<left><left><left>")

-- Zoom
vim.cmd [[map <leader>z <Plug>(zoom-toggle)]]

-- Git blame
vim.cmd [[map <leader>g :Git blame<Enter>]]

-- Open current file+line in GitHub
keymap("n", "<leader>gb", ":execute '!gh browse ' . expand('%') . ':' . line('.')<CR>")

-- Whitespace and cleanup maps
vim.cmd [[
map ;fws :%s/\s\+$//
map ;n GoZ<Esc>:g/^[ <Tab>]*$/.,/[^ <Tab>]/-j<CR>Gdd
map ;c :,s/^[ <Tab>]*//g<CR>i
]]

-- toggle location list with diagnostics
vim.keymap.set('n', '<leader>ll', function()
  local winid = vim.fn.getloclist(0, { winid = 0 }).winid
  if winid ~= 0 then
    vim.cmd('lclose')
    return
  end
  vim.diagnostic.setloclist({ open = false })
  if vim.tbl_isempty(vim.fn.getloclist(0)) then
    vim.cmd('lclose')
    vim.notify('No diagnostics', vim.log.levels.INFO)
    return
  end
  vim.cmd('lopen')
end, { desc = "Toggle location list with diagnostics" })
