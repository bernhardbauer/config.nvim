-- lua/configs/layout.lua
--
-- Window layout helpers shared between plugin configs.

local M = {}

-- Width (columns) of the right-hand terminal slot, shared by opencode and
-- claude code so switching between them doesn't shift the editor.
M.right_terminal_width = 80

-- Window options for a terminal in the right-hand slot. No winbar: snacks
-- would otherwise show "1: <term title>" above the terminal.
---@return snacks.win.Config
function M.right_terminal_win()
  return { position = 'right', width = M.right_terminal_width, wo = { winbar = '' } }
end

-- Visible right-hand snacks terminals (opencode, claude code). Both are
-- created through Snacks.terminal with `position = 'right'`; claudecode.nvim
-- patches hide/show on its instance, so `term:hide()` keeps either job alive.
local function visible_right_terminals()
  local terms = {}
  for _, term in ipairs(require('snacks.terminal').list()) do
    if term:valid() and term.opts.position == 'right' and vim.api.nvim_win_get_config(term.win).relative == '' then
      terms[#terms + 1] = term
    end
  end
  return terms
end

-- Hide all visible right-hand terminals. The right side is a single slot:
-- only one of opencode / claude code is shown at a time, so call this before
-- showing either. Returns the hidden terminals.
function M.hide_right_terminals()
  local hidden = visible_right_terminals()
  for _, term in ipairs(hidden) do
    term:hide()
  end
  return hidden
end

-- Toggle a snacks terminal in the right-hand slot. Showing it hides whatever
-- else is in the slot; toggling a shown terminal just hides it.
---@param cmd? string|string[] command, defaults to the shell
---@param opts? snacks.terminal.Opts
function M.toggle_right_terminal(cmd, opts)
  local terminal = require 'snacks.terminal'
  local shown = terminal.get(cmd, { create = false })
  if not (shown and shown:valid()) then
    M.hide_right_terminals()
  end
  return terminal.toggle(cmd, vim.tbl_deep_extend('force', { win = M.right_terminal_win() }, opts or {}))
end

-- Run `fn` (which opens a full-width bottom panel, e.g. the overseer task
-- list) with all visible right-hand snacks terminals (e.g. opencode) hidden,
-- then show them again.
--
-- A `botright split` also runs under a right-hand terminal, shrinking it and
-- resizing its pty; re-showing the terminal afterwards resizes it again. TUIs
-- don't like two resizes in quick succession. A hidden terminal keeps its
-- size, so hiding it first and showing it afterwards sends no resize at all,
-- and the re-shown window is a fresh full-height column on the right.
function M.with_right_terminals_hidden(fn)
  local hidden = M.hide_right_terminals()

  fn()

  local cur = vim.api.nvim_get_current_win()
  for _, term in ipairs(hidden) do
    term:show()
  end
  if vim.api.nvim_win_is_valid(cur) then
    vim.api.nvim_set_current_win(cur)
  end
end

return M
