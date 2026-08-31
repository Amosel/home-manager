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
    withRuby = true;
    plugins = with pkgs.vimPlugins; [
      luasnip
      catppuccin-nvim
      cmp-buffer
      cmp-nvim-lsp
      cmp-path
      cmp_luasnip
      conform-nvim
      friendly-snippets
      gitsigns-nvim
      lualine-nvim
      neo-tree-nvim
      nui-nvim
      nvim-cmp
      nvim-lint
      nvim-lspconfig
      nvim-treesitter
      nvim-web-devicons
      persistence-nvim
      plenary-nvim
      todo-comments-nvim
      telescope-nvim
      trouble-nvim
      which-key-nvim
      (nvim-treesitter.withPlugins (parsers: with parsers; [
        bash
        cmake
        go
        json
        lua
        markdown
        markdown_inline
        nix
        python
        regex
        rust
        toml
        tsx
        typescript
        vim
        vimdoc
        yaml
      ]))
    ];
    initLua = ''
      vim.g.mapleader = " "
      vim.g.maplocalleader = "\\"

      vim.o.number = true
      vim.o.relativenumber = true
      vim.o.termguicolors = true
      vim.o.expandtab = true
      vim.o.shiftwidth = 2
      vim.o.tabstop = 2
      vim.o.smartindent = true
      vim.o.ignorecase = true
      vim.o.smartcase = true
      vim.o.updatetime = 250
      vim.o.scrolloff = 8
      vim.o.signcolumn = "yes"
      vim.o.cursorline = true
      vim.o.clipboard = "unnamedplus"
      vim.o.undofile = true
      vim.o.undolevels = 10000
      vim.o.completeopt = "menu,menuone,noselect"
      vim.opt.shortmess:append("c")

      require("catppuccin").setup({
        flavour = "mocha",
        integrations = {
          cmp = true,
          gitsigns = true,
          treesitter = true,
          which_key = true,
        },
      })
      vim.cmd.colorscheme("catppuccin-mocha")

      require("lualine").setup({
        options = {
          theme = "auto",
          globalstatus = true,
          section_separators = "",
          component_separators = "",
        },
      })

      require("gitsigns").setup({})
      require("which-key").setup({})
      require("telescope").setup({})
      require("todo-comments").setup({})
      require("trouble").setup({})
      require("persistence").setup({})

      local ok_treesitter, treesitter = pcall(require, "nvim-treesitter.configs")
      if ok_treesitter then
        treesitter.setup({
          highlight = { enable = true },
          indent = { enable = true },
        })
      end

      require("neo-tree").setup({
        close_if_last_window = true,
        filesystem = {
          follow_current_file = {
            enabled = true,
          },
          use_libuv_file_watcher = true,
        },
      })

      local cmp = require("cmp")
      local luasnip = require("luasnip")

      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" },
        }, {
          { name = "buffer" },
        }),
      })

      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      local servers = {
        bashls = {},
        cmake = {},
        gopls = {},
        lua_ls = {
          settings = {
            Lua = {
              diagnostics = {
                globals = { "vim" },
              },
            },
          },
        },
        nil_ls = {},
        protols = {},
        pyright = {},
        rust_analyzer = {},
        tailwindcss = {},
        ts_ls = {},
        yamlls = {},
      }

      local on_attach = function(_, bufnr)
        local opts = { buffer = bufnr, silent = true }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
      end

      for server, config in pairs(servers) do
        config.capabilities = capabilities
        config.on_attach = on_attach
        vim.lsp.config(server, config)
        vim.lsp.enable(server)
      end

      require("conform").setup({
        notify_on_error = false,
        formatters_by_ft = {
          lua = { "stylua" },
          nix = { "alejandra" },
          python = { "isort", "black" },
          sh = { "shfmt" },
          bash = { "shfmt" },
          zsh = { "shfmt" },
          javascript = { "prettier" },
          javascriptreact = { "prettier" },
          typescript = { "prettier" },
          typescriptreact = { "prettier" },
          json = { "prettier" },
          yaml = { "prettier" },
          markdown = { "prettier" },
        },
      })

      require("lint").linters_by_ft = {
        bash = { "shellcheck" },
        dockerfile = { "hadolint" },
        nix = { "statix", "deadnix" },
        python = { "ruff" },
        sh = { "shellcheck" },
        yaml = { "yamllint" },
      }

      local lint = require("lint")
      local lint_group = vim.api.nvim_create_augroup("nvim_lint", { clear = true })
      vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "InsertLeave" }, {
        group = lint_group,
        callback = function()
          lint.try_lint()
        end,
      })

      vim.api.nvim_create_autocmd("BufWritePre", {
        callback = function(args)
          require("conform").format({ bufnr = args.buf, lsp_format = "fallback", quiet = true })
        end,
      })

      vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { silent = true, desc = "Find files" })
      vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { silent = true, desc = "Live grep" })
      vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { silent = true, desc = "Buffers" })
      vim.keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { silent = true, desc = "Help" })
      vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle<cr>", { silent = true, desc = "Explorer" })
      vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { silent = true, desc = "Diagnostics" })
      vim.keymap.set("n", "<leader>xq", "<cmd>Trouble qflist toggle<cr>", { silent = true, desc = "Quickfix" })
      vim.keymap.set("n", "<leader>ft", "<cmd>TodoTelescope<cr>", { silent = true, desc = "Todo comments" })
      vim.keymap.set("n", "<leader>qs", function() require("persistence").load() end, { silent = true, desc = "Restore session" })
      vim.keymap.set("n", "<leader>ql", function() require("persistence").load({ last = true }) end, { silent = true, desc = "Restore last session" })
      vim.keymap.set("n", "<leader>qd", function() require("persistence").stop() end, { silent = true, desc = "Stop session save" })
    '';
  };
}
