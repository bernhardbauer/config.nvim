local oc = function(method, ...)
  local args = { ... }
  return function()
    return require('opencode')[method](unpack(args))
  end
end

local opencode_cmd = 'opencode --port'
local opencode_width = require('configs.layout').right_terminal_width
---@type snacks.terminal.Opts
local opencode_start_opts = { win = { position = 'right', width = opencode_width, enter = false } }

return {
  {
    'nickjvandyke/opencode.nvim',
    version = '*', -- Latest stable release
    dependencies = {
      {
        -- `snacks.nvim` integration is recommended, but optional
        ---@module "snacks" <- Loads `snacks.nvim` types for configuration intellisense
        'folke/snacks.nvim',
        optional = true,
        opts = {
          picker = { -- Enhances `select()`
            actions = {
              opencode_send = function(picker) ---@param picker snacks.Picker
                local items = vim.tbl_map(function(item) ---@param item snacks.picker.Item
                  return item.file and require('opencode').format { path = item.file, from = item.pos, to = item.end_pos } or item.text
                end, picker:selected { fallback = true })
                require('opencode').prompt(table.concat(items, ', ') .. ' ')
              end,
            },
            win = {
              input = {
                keys = {
                  ['<leader>ca'] = { 'opencode_send', mode = { 'n' } },
                },
              },
            },
          },
        },
      },
    },
    init = function()
      ---@type opencode.Opts
      vim.g.opencode_opts = {
        server = {
          start = function()
            require('configs.layout').hide_right_terminals()
            require('snacks.terminal').open(opencode_cmd, opencode_start_opts)
          end,
        },
      }

      -- Disable normal-mode mouse scrolling over the opencode window regardless
      -- of which window is currently focused, so the TUI viewport stays fixed.
      local function is_opencode_win(winid)
        local buf = vim.api.nvim_win_get_buf(winid)
        return vim.bo[buf].buftype == 'terminal' and vim.api.nvim_buf_get_name(buf):match 'opencode'
      end
      local function guard_scroll(fallback)
        return function()
          local mousewin = vim.fn.getmousepos().winid
          if mousewin ~= 0 and is_opencode_win(mousewin) then
            return -- suppress
          end
          return fallback
        end
      end
      vim.keymap.set('n', '<ScrollWheelUp>', guard_scroll '<ScrollWheelUp>', { expr = true })
      vim.keymap.set('n', '<ScrollWheelDown>', guard_scroll '<ScrollWheelDown>', { expr = true })

      -- Keep the opencode window a full-height column on the right at its
      -- configured width.
      --  * Width: snacks opens split sidebars (e.g. the explorer) as a
      --    half-screen split followed by a resize, and Neovim hands the surplus
      --    columns to the rightmost window of the row, ignoring 'winfixwidth'.
      --  * Height: a bottom panel (e.g. the overseer task list) is a full-width
      --    `botright` split that also runs under this window. Re-showing the
      --    terminal makes it a fresh full-height column again.
      local function is_full_height(win)
        local layout = vim.fn.winlayout()
        if layout[1] == 'leaf' then
          return true
        end
        if layout[1] ~= 'row' then
          return false
        end
        for _, node in ipairs(layout[2]) do
          if node[1] == 'leaf' and node[2] == win then
            return true
          end
        end
        return false
      end
      vim.api.nvim_create_autocmd({ 'WinNew', 'WinResized' }, {
        group = vim.api.nvim_create_augroup('opencode_fixed_layout', { clear = true }),
        callback = function()
          vim.schedule(function()
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
              if vim.api.nvim_win_get_config(win).relative == '' and is_opencode_win(win) then
                if not is_full_height(win) then
                  local buf = vim.api.nvim_win_get_buf(win)
                  for _, term in ipairs(require('snacks.terminal').list()) do
                    if term.buf == buf then
                      local cur = vim.api.nvim_get_current_win()
                      term:hide()
                      term:show()
                      if cur ~= win and vim.api.nvim_win_is_valid(cur) then
                        vim.api.nvim_set_current_win(cur)
                      end
                      return
                    end
                  end
                elseif vim.api.nvim_win_get_width(win) ~= opencode_width then
                  vim.api.nvim_win_set_width(win, opencode_width)
                end
              end
            end
          end)
        end,
      })

      local augroup = vim.api.nvim_create_augroup('opencode_focus_insert', { clear = true })
      vim.api.nvim_create_autocmd('WinEnter', {
        group = augroup,
        callback = function()
          local win = vim.api.nvim_get_current_win()
          if not vim.api.nvim_win_is_valid(win) or not is_opencode_win(win) then
            return
          end

          vim.schedule(function()
            if vim.api.nvim_win_is_valid(win) and vim.api.nvim_get_current_win() == win then
              vim.cmd 'startinsert'
            end
          end)
        end,
      })
    end,
    keys = {
      { '<leader>cc', oc('ask', '@this: '), desc = 'Ask opencode…', mode = { 'n', 'x' } },
      { '<leader>cx', oc 'select', desc = 'Execute opencode action…', mode = { 'n', 'x' } },
      {
        '<C-,>',
        function()
          require('configs.layout').toggle_right_terminal(opencode_cmd)
        end,
        desc = 'Toggle opencode',
        mode = { 'n', 't' },
      },
      { 'go', oc('operator', '@this '), desc = 'Add range to opencode', mode = { 'n', 'x' }, expr = true },
      {
        'goo',
        function()
          return require('opencode').operator '@this ' .. '_'
        end,
        desc = 'Add line to opencode',
        expr = true,
      },
    },
  },
}
