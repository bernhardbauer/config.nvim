-- lua/configs/layout.lua
--
-- Window layout helpers shared between plugin configs.

local M = {}

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
  local hidden = {}
  for _, term in ipairs(require('snacks.terminal').list()) do
    if term:valid() and term.opts.position == 'right' and vim.api.nvim_win_get_config(term.win).relative == '' then
      term:hide()
      hidden[#hidden + 1] = term
    end
  end

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
