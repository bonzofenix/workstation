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

