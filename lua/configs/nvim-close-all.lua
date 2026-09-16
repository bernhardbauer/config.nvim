-- lua/configs/nvim-close-all.lua

local M = {}

-- Close all non-DAP panels (used when opening DAP UI)
function M.close_non_dap_panels()
  local explorer = Snacks.picker.get({ source = 'explorer' })[1]
  if explorer then
    explorer:close()
  end
  if package.loaded['overseer'] then
    require('overseer').close()
  end
  if package.loaded['neotest'] then
    require('neotest').summary.close()
    require('neotest').output_panel.close()
  end
end

-- Close all plugin open panels
function M.close_all_panels()
  M.close_non_dap_panels()
  if package.loaded['dapui'] then
    require('dapui').close()
  end
  require('configs.layout').hide_right_terminals()
end

return M
