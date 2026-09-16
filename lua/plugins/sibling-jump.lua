return {
  {
    'subev/sibling-jump.nvim',
    config = function()
      require('sibling_jump').setup {
        -- <C-j>/<C-k> are window navigation (init.lua); use bracket motions instead.
        next_key = ']j',
        prev_key = '[j',
        center_on_jump = true, -- Center screen after jump (default: false)
      }
    end,
  },
}
