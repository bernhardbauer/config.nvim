return {
  {
    'stevearc/overseer.nvim',
    opts = {},
    config = function()
      require('overseer').setup {
        templates = { 'builtin', 'user.dotnet_run' },
        task_list = {
          bindings = {
            ['<C-h>'] = false,
            ['<C-j>'] = false,
            ['<C-k>'] = false,
            ['<C-l>'] = false,
          },
        },
      }

      -- Keep the task's pty in sync with the window that shows its output.
      -- Overseer's jobstart strategy sizes the pty once (columns-4 x lines-4)
      -- and never resizes it, while the nvim_open_term grid follows the window.
      -- Full-screen TUIs (e.g. `nx --tui`) then lay out for the wrong size.
      -- Also disable 'list' there: a real :terminal does this automatically,
      -- an nvim_open_term buffer does not, so trailing spaces show as dots.
      vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinResized' }, {
        group = vim.api.nvim_create_augroup('overseer_pty_resize', { clear = true }),
        callback = function()
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            local task_id = vim.b[buf].overseer_task
            if task_id then
              local task = require('overseer').list_tasks({
                include_ephemeral = true,
                filter = function(t)
                  return t.id == task_id
                end,
              })[1]
              local job = task and task.strategy and task.strategy.job_id
              if job then
                vim.wo[win].list = false
                local width = vim.api.nvim_win_get_width(win) - vim.fn.getwininfo(win)[1].textoff
                pcall(vim.fn.jobresize, job, width, vim.api.nvim_win_get_height(win))
              end
            end
          end
        end,
      })

      -- Make Overseer windows non-editable and prevent buffer switching
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'OverseerList',
        callback = function()
          vim.bo.modifiable = false
          vim.bo.buftype = 'nofile'
          -- Prevent switching buffers in this window (Neovim 0.10+)
          vim.wo.winfixbuf = true
        end,
      })
    end,
    keys = {
      { '<leader>rr', '<cmd>OverseerRun<cr>', desc = '[R]un [A]ny' },
      { '<leader>rv', '<cmd>OverseerToggle<cr>', desc = '[R]un [V]iew' },
      { '<leader>rt', '<cmd>OverseerTaskAction<cr>', desc = '[R]un [T]ask Action' },
      { '<leader>rs', '<cmd>OverseerShell<cr>', desc = '[R]un [S]hell' },
    },
  },
}
