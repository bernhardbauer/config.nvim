local oc = function(method, ...)
  local args = { ... }
  return function()
    return require('opencode')[method](unpack(args))
  end
end

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
          input = {}, -- Enhances `ask()`
          picker = { -- Enhances `select()`
            actions = {
              opencode_send = function(...)
                return require('opencode').snacks_picker_send(...)
              end,
            },
            win = {
              input = {
                keys = {
                  ['<leader>ca'] = { 'opencode_send', mode = { 'n', 'i' } },
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
        -- Your configuration, if any; goto definition on the type or field for details
        lsp = { enabled = true },
      }

      vim.o.autoread = true -- Required for `opts.events.reload`

      -- Disable normal-mode mouse scrolling over the opencode window regardless
      -- of which window is currently focused, so the TUI viewport stays fixed.
      local function is_opencode_win(winid)
        local buf = vim.api.nvim_win_get_buf(winid)
        return vim.bo[buf].buftype == 'terminal'
          and vim.api.nvim_buf_get_name(buf):match('opencode')
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
      vim.keymap.set('n', '<ScrollWheelUp>',   guard_scroll('<ScrollWheelUp>'),   { expr = true })
      vim.keymap.set('n', '<ScrollWheelDown>', guard_scroll('<ScrollWheelDown>'), { expr = true })

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
      { '<leader>cc', oc('ask', '@this: ', { submit = true }), desc = 'Ask opencode…', mode = { 'n', 'x' } },
      { '<leader>cx', oc 'select', desc = 'Execute opencode action…', mode = { 'n', 'x' } },
      { '<C-,>', oc 'toggle', desc = 'Toggle opencode', mode = { 'n', 't' } },
      { 'go', oc('operator', '@this '), desc = 'Add range to opencode', mode = { 'n', 'x' }, expr = true },
      { 'goo', oc('@this ' .. '_'), desc = 'Add line to opencode', expr = true },
    },
  },
}
