-- Largest normal (non-plugin, non-fixed) window: the "editor pane".
local function main_editor_win()
  local best, best_area
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if
      vim.api.nvim_win_get_config(win).relative == ''
      and vim.bo[buf].buftype == ''
      and not vim.wo[win].winfixwidth
      and not vim.wo[win].winfixheight
    then
      local area = vim.api.nvim_win_get_width(win) * vim.api.nvim_win_get_height(win)
      if not best or area > best_area then
        best, best_area = win, area
      end
    end
  end
  return best
end

-- Toggle the explorer as a sidebar next to the editor pane only (same height
-- as the editor), so it sits above a bottom panel such as the overseer list
-- instead of squeezing it. Snacks always opens sidebar layouts as a
-- full-height editor split (it drops `relative`/`win` for split layouts), so
-- the sidebar's root window is moved next to the editor pane after it shows.
local function toggle_explorer()
  local explorer = Snacks.picker.get({ source = 'explorer' })[1]
  if explorer then
    return explorer:close()
  end
  local main = main_editor_win()
  if main then
    vim.api.nvim_set_current_win(main)
  end
  Snacks.explorer.open {
    on_show = function(picker)
      local root = picker.layout and picker.layout.root and picker.layout.root.win
      if not (main and root and vim.api.nvim_win_is_valid(root) and vim.api.nvim_win_is_valid(main)) then
        return
      end
      local width = vim.api.nvim_win_get_width(root)
      vim.api.nvim_win_set_config(root, { split = 'left', win = main })
      vim.api.nvim_win_set_width(root, width)
    end,
  }
end

return {
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      dashboard = {
        sections = {
          { section = 'header' },
          { section = 'recent_files', cwd = true, limit = 8, padding = 1 },
          { section = 'startup' },
        },
      },
      input = {}, -- also used by opencode.ask()
      picker = {
        sources = {
          explorer = {
            hidden = true, -- show hidden files in the explorer
            jump = { close = false, tagstack = true },
          },
        },
      },
      explorer = {
        replace_netrw = false, -- don't auto-open explorer on `nvim .`
      },
      indent = {},
      gitbrowse = {},
      lazygit = {
        config = {
          quitOnTopLevelReturn = true,
          os = { editPreset = 'nvim-remote' },
          git = {
            branchPrefix = 'feature/',
            disableForcePushing = true,
          },
          branches = {
            defaultRemote = 'origin',
          },
        },
      },
      notifier = {},
    },
    keys = {
      {
        '<leader>gg',
        function()
          Snacks.lazygit.open()
        end,
        desc = '[G]it (Lazygit)',
      },
      { '<leader>gl', '<cmd>lua Snacks.lazygit.log_file()<cr>', desc = '[G]it file log' },
      { '\\', toggle_explorer, desc = 'Toggle Explorer' },
      { '<leader>xn', '<cmd>lua Snacks.notifier.show_history()<cr>', desc = 'Notification History' },
    },
  },
}
