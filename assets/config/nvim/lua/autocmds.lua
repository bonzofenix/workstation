local augroup = vim.api.nvim_create_augroup

-- General group for misc autocommands
local general = augroup("General", { clear = true })

vim.api.nvim_create_autocmd("VimResized", {
  group = general,
  command = "wincmd =",
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = general,
  pattern = "*.tt",
  command = "set filetype=mason",
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = general,
  pattern = { "*.yaml", "*.yml" },
  command = "set et ts=2 sw=2 sts=2",
})

vim.api.nvim_create_autocmd("FileType", {
  group = general,
  pattern = "make",
  command = "set noexpandtab shiftwidth=4 softtabstop=0",
})

vim.api.nvim_create_autocmd("FileType", {
  group = general,
  pattern = "python",
  command = "set expandtab ts=4",
})

-- auto-convert tabs to spaces on save
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function()
    if vim.bo.expandtab then
      vim.cmd("retab")
    end
  end,
})

