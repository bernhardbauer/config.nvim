local M = {}

-- Map each boolean keyword to its opposite
local opposites = {
  ['true'] = 'false',
  ['false'] = 'true',
  ['True'] = 'False',
  ['False'] = 'True',
  ['TRUE'] = 'FALSE',
  ['FALSE'] = 'TRUE',
}

-- Try to toggle the word under the cursor.
-- Returns true if a toggle was performed, false otherwise.
function M.toggle()
  local word = vim.fn.expand '<cword>'
  local replacement = opposites[word]
  if replacement then
    vim.cmd('normal! ciw' .. replacement)
    return true
  end
  return false
end

return M
