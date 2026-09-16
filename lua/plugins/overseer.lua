local function toggle_task_list()
  local overseer = require 'overseer'
  if require('overseer.window').is_open() then
    return overseer.close()
  end
  require('configs.layout').with_right_terminals_hidden(function()
    overseer.open()
  end)
end

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

      -- A full-height `topleft` vsplit takes its columns from the leftmost
      -- window of every row first, and 'winfixwidth' only protects a window
      -- during equalization, so the task list can end up 1 column wide.
      -- Restore its configured width when that happens.
      vim.api.nvim_create_autocmd({ 'WinNew', 'WinResized' }, {
        group = vim.api.nvim_create_augroup('overseer_list_width', { clear = true }),
        callback = function()
          vim.schedule(function()
            local winid = require('overseer.window').get_win_id()
            if not winid or not vim.api.nvim_win_is_valid(winid) then
              return
            end
            local want = require('overseer.layout').calculate_width(nil, require('overseer.config').task_list)
            if vim.api.nvim_win_get_width(winid) < want then
              vim.api.nvim_win_set_width(winid, want)
            end
          end)
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
      { '<leader>rv', toggle_task_list, desc = '[R]un [V]iew' },
      { '<leader>rt', '<cmd>OverseerTaskAction<cr>', desc = '[R]un [T]ask Action' },
      { '<leader>rs', '<cmd>OverseerShell<cr>', desc = '[R]un [S]hell' },
      {
        '<leader>rx',
        function()
          require('configs.layout').toggle_right_terminal()
        end,
        desc = '[R]un terminal (right slot)',
      },
    },
  },
}
