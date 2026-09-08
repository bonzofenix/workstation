vim.api.nvim_create_user_command("AA", function()
  -- Save current buffer
  vim.cmd("write")

  -- Get full path of current file and stage it
  local file = vim.fn.expand("%:p")
  vim.fn.jobstart({ "git", "add", file })

  -- Get the staged diff
  local diff = vim.fn.system("git diff --staged")
  if vim.v.shell_error ~= 0 then
    print("Failed to get staged diff.")
    return
  end

  -- Use sgpt to generate commit message
  local handle = io.popen("echo " .. vim.fn.shellescape(diff) ..
    " | sgpt 'Generate a concise git commit message that summarizes the key changes. Stay high-level and combine smaller changes to overarching topics. Skip describing any reformatting changes.'")
  if not handle then
    print("Failed to run sgpt.")
    return
  end

  local msg = handle:read("*a")
  handle:close()
  msg = vim.trim(msg)

  if msg == "" then
    print("sgpt returned an empty message.")
    return
  end

  -- Write commit message to temp file
  local tmpfile = os.tmpname()
  local f = io.open(tmpfile, "w")
  if f then
    f:write(msg)
    f:close()
  else
    print("Could not write temp commit message.")
    return
  end

  -- Call Fugitive’s :Git commit -F <file> -e (edit message)
  vim.cmd("Git commit -e -F " .. tmpfile)
end, {})

-- Interview mode: kill Copilot so nothing writes code on a shared screen.
-- :InterviewMode  /  :InterviewModeOff
vim.api.nvim_create_user_command("InterviewMode", function()
  pcall(vim.cmd, "Copilot disable")
  vim.notify("Interview mode ON — Copilot disabled, LSP completion on <Tab>", vim.log.levels.INFO)
end, { desc = "Disable Copilot for live coding interviews" })

vim.api.nvim_create_user_command("InterviewModeOff", function()
  pcall(vim.cmd, "Copilot enable")
  vim.notify("Interview mode OFF — Copilot re-enabled", vim.log.levels.INFO)
end, { desc = "Re-enable Copilot" })

-- :CopilotDebug — run this in INSERT mode while ghost text is visible.
-- Prints what the Tab mapping sees, so we can tell why it fell through.
vim.api.nvim_create_user_command("CopilotDebug", function()
  local ok, sug = pcall(vim.fn["copilot#GetDisplayedSuggestion"])
  local parts = {
    "call_ok=" .. tostring(ok),
    "text_len=" .. tostring(ok and sug and sug.text and #sug.text or "nil"),
    "pumvisible=" .. tostring(vim.fn.pumvisible()),
    "clients=" .. tostring(#vim.lsp.get_clients({ bufnr = 0 })),
    "tab_mapped=" .. tostring((vim.fn.maparg("<Tab>", "i", 0, 1) or {}).desc or "NONE"),
    "copilot_enabled=" .. tostring(vim.fn.exists("*copilot#Enabled") == 1 and vim.fn["copilot#Enabled"]() or "?"),
  }
  vim.notify(table.concat(parts, "\n"), vim.log.levels.INFO)
  print(table.concat(parts, " | "))
end, { desc = "Diagnose why Tab did not accept a Copilot suggestion" })
