return {
  {
    'coder/claudecode.nvim',
    dependencies = { 'folke/snacks.nvim' },
    opts = {
      terminal = {
        -- Absolute width overriding split_width_percentage, aligned with opencode.
        snacks_win_opts = require('configs.layout').right_terminal_win(),
      },
    },
    keys = {
      {
        '<leader>ca',
        function()
          -- The right side is a single slot shared with opencode: hide
          -- whatever is there before showing claude code.
          local buf = require('claudecode.terminal').get_active_terminal_bufnr()
          local shown = buf and vim.fn.bufwinid(buf) ~= -1
          if not shown then
            require('configs.layout').hide_right_terminals()
          end
          vim.cmd 'ClaudeCode'
        end,
        desc = 'Toggle Claude',
      },
    },
  },
}
