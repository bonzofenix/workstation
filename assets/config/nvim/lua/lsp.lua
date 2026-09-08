-- Shared on_attach for all LSPs
local on_attach = function(client, bufnr)
  local keymap = vim.keymap.set
  local opts = { buffer = bufnr }

  keymap("n", "gd", vim.lsp.buf.definition, opts)
  keymap("n", "gr", vim.lsp.buf.references, opts)
  keymap("n", "K", vim.lsp.buf.hover, opts)
  keymap("n", "<leader>rn", vim.lsp.buf.rename, opts)
  keymap("n", "<leader>ca", vim.lsp.buf.code_action, opts)

  -- LSP completion (built into nvim 0.11+). autotrigger fires as you type.
  if vim.lsp.completion and vim.lsp.completion.enable then
    vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })

    -- vim-go sets omnifunc to go#complete#Complete, which bypasses gopls and
    -- gives poor results. Force the LSP omnifunc for buffers with a client.
    vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

  end

  -- Format on save (skip shell scripts to preserve tabs)
  vim.api.nvim_create_autocmd("BufWritePre", {
    buffer = bufnr,
    callback = function()
      local ft = vim.bo.filetype
      if ft == "sh" or ft == "bash" then
        return
      end
      -- Go: organize imports first (adds missing, drops unused), then format.
      -- vim.lsp.buf.format() alone runs gofmt and will NOT touch imports.
      if ft == "go" then
        local params = vim.lsp.util.make_range_params(0, "utf-8")
        params.context = { only = { "source.organizeImports" } }
        local res = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 1500)
        for _, r in pairs(res or {}) do
          for _, action in pairs(r.result or {}) do
            if action.edit then
              vim.lsp.util.apply_workspace_edit(action.edit, "utf-8")
            end
          end
        end
      end
      vim.lsp.buf.format({ async = false })
    end,
  })
end

-- Go: gopls. Uses the nvim 0.11+ API (vim.lsp.config/enable); the old
-- require("lspconfig").gopls.setup{} path is deprecated and prints a warning.
vim.lsp.config("gopls", {
  on_attach = on_attach,
  settings = {
    gopls = {
      usePlaceholders = true,
      analyses = {
        unusedparams = true,
        unreachable = true,
      },
    },
  },
})

vim.lsp.enable("gopls")

-- Completion keymaps live OUTSIDE on_attach on purpose: on_attach only fires
-- once a language server attaches, so a fresh buffer (or one gopls has not
-- claimed yet) would get no <Tab> mapping at all and Tab would insert a literal
-- tab even while Copilot ghost text was on screen.
local function set_completion_keys(bufnr)
  local K = function(k) return vim.api.nvim_replace_termcodes(k, true, true, true) end

  -- <Tab>: Copilot ghost text -> LSP popup -> open popup -> literal tab
  vim.keymap.set("i", "<Tab>", function()
    local ok, sug = pcall(vim.fn["copilot#GetDisplayedSuggestion"])
    if ok and type(sug) == "table" and sug.text and sug.text ~= "" then
      return vim.fn["copilot#Accept"]("")
    end
    if vim.fn.pumvisible() == 1 then
      local sel = vim.fn.complete_info({ "selected" }).selected
      return (sel ~= nil and sel >= 0) and K("<C-y>") or K("<C-n><C-y>")
    end
    local col = vim.fn.col(".") - 1
    local line = vim.fn.getline(".")
    if col == 0 or line:sub(col, col):match("%s") then
      return K("<Tab>")
    end
    return K("<C-x><C-o>")
  end, { buffer = bufnr, expr = true, replace_keycodes = false,
         desc = "Accept Copilot / LSP completion / tab" })

  vim.keymap.set("i", "<S-Tab>", function()
    return vim.fn.pumvisible() == 1 and K("<C-p>") or K("<S-Tab>")
  end, { buffer = bufnr, expr = true, replace_keycodes = false, desc = "Prev completion item" })

  vim.keymap.set("i", "<CR>", function()
    return vim.fn.pumvisible() == 1 and K("<C-y>") or K("<CR>")
  end, { buffer = bufnr, expr = true, replace_keycodes = false, desc = "Accept completion / newline" })
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "go", "gomod", "lua", "python", "sh", "bash", "yaml", "json", "markdown" },
  callback = function(args) set_completion_keys(args.buf) end,
})
