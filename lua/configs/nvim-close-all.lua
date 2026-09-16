-- lua/configs/nvim-close-all.lua

local M = {}

-- Close all non-DAP panels (used when opening DAP UI)
function M.close_non_dap_panels()
  local explorer = Snacks.picker.get({ source = 'explorer' })[1]
  if explorer then
    explorer:close()
  end
  require('overseer').close()
  require('neotest').summary.close()
  require('neotest').output_panel.close()
end

-- Close all plugin open panels
function M.close_all_panels()
  M.close_non_dap_panels()
  require('dapui').close()
  require('configs.layout').hide_right_terminals()
end

return M
