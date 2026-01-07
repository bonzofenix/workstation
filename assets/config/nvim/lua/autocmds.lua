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

-- Auto-reload files when changed externally
-- This is especially useful when working with external tools like Claude Code
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  group = general,
  callback = function()
    if vim.fn.mode() ~= "c" then
      vim.cmd("checktime")
    end
  end,
})

-- Notification when file is changed outside of Neovim
vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = general,
  callback = function()
    vim.notify("File changed on disk. Buffer reloaded.", vim.log.levels.WARN)
  end,
})

