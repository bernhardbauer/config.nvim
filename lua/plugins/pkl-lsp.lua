return {
  {
    'apple/pkl-neovim',
    lazy = true,
    ft = 'pkl',
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'L3MON4D3/LuaSnip',
    },
    config = function()
      require('luasnip.loaders.from_snipmate').lazy_load()

      vim.g.pkl_neovim = {
        start_command = { 'pkl-lsp' },
      }
    end,
  },
}
