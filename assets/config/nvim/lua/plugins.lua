-- ~/.config/nvim/lua/plugins.lua
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

  -- Copilot
  { "github/copilot.vim" },

  -- Go development
  { "fatih/vim-go",
    ft = "go",
    build = ":GoUpdateBinaries",
  },

  -- JavaScript syntax
  { "pangloss/vim-javascript", ft = { "javascript", "typescript" } },

  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = "Telescope",
    config = function()
      require("telescope").setup()
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
