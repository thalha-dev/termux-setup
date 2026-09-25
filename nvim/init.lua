-- Neovim config shipped with termux-setup (repo: thalha-dev/termux-setup)
-- Self-contained; leader = Space.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ── options ─────────────────────────────────────────────────────────────────
local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.breakindent = true
opt.undofile = true
opt.ignorecase = true
opt.smartcase = true
opt.signcolumn = "yes"
opt.updatetime = 250
opt.timeoutlen = 400
opt.completeopt = { "menu", "menuone", "noselect" }
opt.termguicolors = true
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.smartindent = true
opt.clipboard = "unnamedplus" -- OSC52-friendly if terminal supports it

-- ── keymaps ─────────────────────────────────────────────────────────────────
local map = vim.keymap.set
map("n", "<Esc>", "<cmd>nohlsearch<CR>")
map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Diagnostic details" })

-- ── bootstrap lazy.nvim ─────────────────────────────────────────────────────
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("Failed to clone lazy.nvim:\n" .. out)
  end
end
opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { "catppuccin/nvim", name = "catppuccin", priority = 1000,
      opts = { flavour = "mocha", transparent_background = false } },
    { "nvim-lualine/lualine.nvim", opts = { options = { theme = "catppuccin" } } },
    {
      "nvim-treesitter/nvim-treesitter",
      branch = "main", -- per the treesitter 'main' rewrite
      build = ":TSUpdate",
      opts = {
        ensure_installed = { "c", "cpp", "go", "javascript", "typescript",
          "tsx", "python", "bash", "lua", "vimdoc", "json", "yaml", "markdown" },
      },
    },
    {
      "nvim-telescope/telescope.nvim",
      dependencies = { "nvim-lua/plenary.nvim" },
      keys = {
        { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find files" },
        { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Grep" },
        { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
        { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Help" },
      },
      opts = {
        defaults = {
          mappings = { i = { ["<C-u>"] = false, ["<C-d>"] = false } },
        },
      },
    },
    {
      "neovim/nvim-lspconfig",
      config = function()
        local lsp = require("lspconfig")
        local caps = vim.lsp.protocol.make_client_capabilities()
        -- servers come from apt/npm (clangd, gopls, typescript-language-server,
        -- bash-language-server) — deliberately no Mason under proot
        lsp.clangd.setup({ capabilities = caps })
        lsp.gopls.setup({ capabilities = caps })
        lsp.ts_ls.setup({ capabilities = caps })
        lsp.bashls.setup({ capabilities = caps })
        lsp.pyright.setup({ capabilities = caps })

        vim.diagnostic.config({ severity_sort = true, float = { border = "rounded" } })
        vim.api.nvim_create_autocmd("LspAttach", {
          callback = function(args)
            local b = args.buf
            map("n", "gd", vim.lsp.buf.definition, { buffer = b, desc = "Definition" })
            map("n", "gr", vim.lsp.buf.references, { buffer = b, desc = "References" })
            map("n", "gi", vim.lsp.buf.implementation, { buffer = b, desc = "Implementation" })
            map("n", "K", vim.lsp.buf.hover, { buffer = b, desc = "Hover" })
            map("n", "<leader>rn", vim.lsp.buf.rename, { buffer = b, desc = "Rename" })
            map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, { buffer = b, desc = "Code action" })
          end,
        })
      end,
    },
    {
      "hrsh7th/nvim-cmp",
      dependencies = {
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "L3MON4D3/LuaSnip",
        "saadparwaiz1/cmp_luasnip",
      },
      config = function()
        local cmp = require("cmp")
        local luasnip = require("luasnip")
        cmp.setup({
          snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
          mapping = cmp.mapping.preset.insert({
            ["<C-Space>"] = cmp.mapping.complete(),
            ["<CR>"] = cmp.mapping.confirm({ select = true }),
            ["<Tab>"] = cmp.mapping(function(fallback)
              if cmp.visible() then cmp.select_next_item()
              elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
              else fallback() end
            end, { "i", "s" }),
            ["<S-Tab>"] = cmp.mapping(function(fallback)
              if cmp.visible() then cmp.select_prev_item()
              elseif luasnip.jumpable(-1) then luasnip.jump(-1)
              else fallback() end
            end, { "i", "s" }),
          }),
          sources = cmp.config.sources({
            { name = "nvim_lsp" }, { name = "luasnip" },
          }, { { name = "buffer" }, { name = "path" } }),
        })
        local capabilities = require("cmp_nvim_lsp").default_capabilities()
        -- re-applied to all clients that attach after cmp loads
        vim.lsp.config("*", { capabilities = capabilities })
      end,
    },
  },
  install = { colorscheme = { "catppuccin" } },
  checker = { enabled = false }, -- no update pings on a phone
})

vim.cmd.colorscheme("catppuccin")
