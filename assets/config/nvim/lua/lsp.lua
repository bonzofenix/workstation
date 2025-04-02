local lspconfig = require("lspconfig")

-- 🔧 Shared on_attach for all LSPs
local on_attach = function(_, bufnr)
  local keymap = vim.keymap.set
  local opts = { buffer = bufnr }

  keymap("n", "gd", vim.lsp.buf.definition, opts)
  keymap("n", "gr", vim.lsp.buf.references, opts)
  keymap("n", "K", vim.lsp.buf.hover, opts)
  keymap("n", "<leader>rn", vim.lsp.buf.rename, opts)
  keymap("n", "<leader>ca", vim.lsp.buf.code_action, opts)

  -- Optional: format on save
  vim.api.nvim_create_autocmd("BufWritePre", {
    buffer = bufnr,
    callback = function()
      vim.lsp.buf.format({ async = false })
    end,
  })
end

-- 🌞 Ruby: Solargraph
lspconfig.solargraph.setup({
  on_attach = on_attach,
})

-- 🐹 Go: Gopls
lspconfig.gopls.setup({
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
