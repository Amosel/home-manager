{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withNodeJs = true;
    withPython3 = true;
    plugins = with pkgs.vimPlugins; [
      catppuccin-nvim
      gitsigns-nvim
      lualine-nvim
      nvim-lspconfig
      nvim-treesitter
      nvim-web-devicons
      plenary-nvim
      telescope-nvim
    ];
    initLua = ''
      vim.o.number = true
      vim.o.relativenumber = true
      vim.o.termguicolors = true
      vim.o.expandtab = true
      vim.o.shiftwidth = 2
      vim.o.tabstop = 2
      vim.o.ignorecase = true
      vim.o.smartcase = true
      vim.o.updatetime = 250
      vim.g.mapleader = " "

      require("catppuccin").setup({})
      vim.cmd.colorscheme("catppuccin-mocha")

      require("lualine").setup({
        options = {
          theme = "auto",
          globalstatus = true,
        },
      })

      require("gitsigns").setup({})
      require("telescope").setup({})
      require("nvim-treesitter.configs").setup({
        highlight = { enable = true },
        indent = { enable = true },
      })

      local lspconfig = require("lspconfig")
      local servers = {
        "bashls",
        "cmake",
        "gopls",
        "lua_ls",
        "nil_ls",
        "protols",
        "pyright",
        "rust_analyzer",
        "tailwindcss",
        "ts_ls",
        "yamlls",
      }

      for _, server in ipairs(servers) do
        lspconfig[server].setup({})
      end

      vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { silent = true })
      vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { silent = true })
      vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { silent = true })
      vim.keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { silent = true })
    '';
  };
}
