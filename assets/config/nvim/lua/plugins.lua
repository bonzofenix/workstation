-- ~/.config/nvim/lua/plugins.lua
-- Copilot must not own <Tab> — LSP completion uses it (see lua/lsp.lua).
-- Accept Copilot suggestions with <M-l> instead. Toggle Copilot: :Copilot disable
vim.g.copilot_no_tab_map = true
vim.g.copilot_assume_mapped = true

return require("lazy").setup({

  -- Core utilities
  { "nvim-lua/plenary.nvim" },

  -- Git
  { "tpope/vim-fugitive" },

  -- Comments and surrounding
  { "tpope/vim-surround" },
  { "preservim/nerdcommenter" },

  -- Markdown & tabular formatting
  { "godlygeek/tabular" },
  { "preservim/vim-markdown" },

  -- GitHub Copilot. NOTE: a copy also exists in pack/github/start/ but lazy.nvim
  -- owns runtimepath, so the native pack/ dir is never sourced. Managed here.
  {
    "github/copilot.vim",
    lazy = false,  -- load at startup so :Copilot exists without entering insert mode first
    config = function()
      -- <Tab> belongs to LSP completion (see lua/lsp.lua); accept Copilot with <M-l>
      vim.g.copilot_no_tab_map = true
      vim.keymap.set("i", "<M-l>", 'copilot#Accept("\\<CR>")',
        { expr = true, replace_keycodes = false, desc = "Accept Copilot suggestion" })
      vim.keymap.set("i", "<M-]>", "<Plug>(copilot-next)", { desc = "Next Copilot suggestion" })
      vim.keymap.set("i", "<M-[>", "<Plug>(copilot-previous)", { desc = "Prev Copilot suggestion" })
      vim.keymap.set("i", "<C-]>", "<Plug>(copilot-dismiss)", { desc = "Dismiss Copilot" })
    end,
  },

  -- Go development
  { "fatih/vim-go",
    ft = "go",
    build = ":GoUpdateBinaries",
    init = function()
      -- lspconfig owns gopls. Without these, vim-go starts a SECOND gopls and
      -- overrides omnifunc with its own (non-LSP) completion.
      vim.g.go_gopls_enabled = 0
      vim.g.go_code_completion_enabled = 0
      vim.g.go_def_mapping_enabled = 0
      vim.g.go_doc_keywordprg_enabled = 0
      vim.g.go_fmt_autosave = 0        -- LSP formats on save already
      vim.g.go_imports_autosave = 0    -- organizeImports handles this
      vim.g.go_diagnostics_enabled = 0 -- avoid duplicate diagnostics
    end,
  },

  -- JavaScript syntax
  { "pangloss/vim-javascript", ft = { "javascript", "typescript" } },

  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = "Telescope",
    config = function()
      require('telescope').setup({
        pickers = {
          find_files = {
            hidden = true,
            file_ignore_patterns = { "^.git/" },
          }
        }
      })
    end,
  },

  -- Treesitter for modern syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "go", "lua", "python", "yaml", "gomod" , "make", "ruby", "python", "properties", "json", "bash" },
        highlight = { enable = true },
        indent = { enable = true },
        fold = { enable = true },
      })
    end,
  },

  -- lspconfig
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
  },

  -- Gruvbox theme
  { "morhetz/gruvbox" },

  -- Zoom plugin
  { "dhruvasagar/vim-zoom" },

  -- Terraform support
  { "hashivim/vim-terraform", ft = { "terraform", "tf" } },
})
