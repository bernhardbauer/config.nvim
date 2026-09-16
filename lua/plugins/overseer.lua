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
    config = function()
      require('overseer').setup {
        task_list = {
          -- Free <C-hjkl> for window navigation; overseer maps them to scrolling by default.
          keymaps = {
            ['<C-h>'] = false,
            ['<C-j>'] = false,
            ['<C-k>'] = false,
            ['<C-l>'] = false,
          },
        },
      }

      -- Kill a task's whole process tree on stop/restart.
      --
      -- Overseer stops tasks with jobstop(), which hangs up the pty and only
      -- kills the process *tree* two seconds later. A parent that died from
      -- the hangup (nx does) has had its children reparented by then, so they
      -- are missed; nx task children run in their own pty session, lose
      -- their terminal and spin at 100% CPU. Snapshot the descendants while
      -- the tree is intact, terminate them and the process group, and SIGKILL
      -- survivors. The default strategy is hardcoded to jobstart, so wrap it.
      local jobstart = require 'overseer.strategy.jobstart'
      local orig_stop = jobstart.stop
      function jobstart.stop(self)
        local pid = self.job_id and self.job_id > 0 and vim.fn.jobpid(self.job_id) or nil
        if pid and pid > 0 then
          local pids = { pid }
          local function walk(p)
            local ok, children = pcall(vim.api.nvim_get_proc_children, p)
            for _, child in ipairs(ok and children or {}) do
              pids[#pids + 1] = child
              walk(child)
            end
          end
          walk(pid)
          local function signal(sig)
            for _, p in ipairs(pids) do
              pcall(vim.uv.kill, p, sig)
            end
            pcall(vim.uv.kill, -pid, sig) -- pty jobs lead their own group: pgid == pid
          end
          signal 'sigterm'
          vim.defer_fn(function()
            signal 'sigkill'
          end, 2000)
        end
        orig_stop(self)
      end

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

      -- Prevent switching buffers in the task list window.
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('overseer_list_winfixbuf', { clear = true }),
        pattern = 'OverseerList',
        callback = function()
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
