return {
  {
    'AckslD/nvim-neoclip.lua',
    dependencies = {
      { 'nvim-telescope/telescope.nvim' },
    },
    config = function()
      require('neoclip').setup()
    end,
    event = 'VeryLazy', -- the yank listener is registered in setup(); load before the first yank
    keys = {
      { '<leader>fc', '<cmd>Telescope neoclip<cr>', desc = '[C]lipboard history' },
      { '<leader>fm', '<cmd>Telescope macroscope<cr>', desc = '[M]acro history' },
    },
  },
}
