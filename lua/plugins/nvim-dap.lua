local dotnet_adapter = {
  type = 'executable',
  -- command = vim.fn.stdpath 'data' .. '/mason/bin/netcoredbg',
  command = os.getenv 'HOME' .. '/git/netcoredbg/build/src/netcoredbg',
  args = { '--interpreter=vscode' },
}

local dotnet_configuration = {
  {
    type = 'coreclr',
    name = 'launch - dotnet run',
    request = 'launch',
    program = function()
      return require('configs.nvim-dap-dotnet').build_and_get_dll_path()
    end,
    cwd = function()
      return require('configs.nvim-dap-dotnet').build_debug_cwd()
    end,
    env = function()
      return require('configs.nvim-dap-dotnet').get_launch_env()
    end,
    args = function()
      return require('configs.nvim-dap-dotnet').get_launch_args()
    end,
    stopAtEntry = false,
  },
}

-- Launch the single matching DAP config automatically, or fall back to the picker.
local smart_continue = function()
  local dap = require 'dap'
  -- If a session is already active, just continue it.
  if dap.session() then
    dap.continue()
    return
  end
  local ft = vim.bo.filetype
  local configs = dap.configurations[ft] or {}
  local matching = vim.tbl_filter(function(c)
    return c.condition == nil or c.condition()
  end, configs)
  if #matching == 1 then
    dap.run(matching[1])
  else
    dap.continue()
  end
end

local close_non_dap_ui = function()
  require('configs.nvim-close-all').close_non_dap_panels()
end

local toggle_dap_ui = function()
  close_non_dap_ui()
  require('dapui').toggle { reset = true }
end

local set_debug_keymaps = function()
  vim.keymap.set('n', '<Up>', '<cmd>lua require("dap").continue()<cr>', { desc = 'Debug: Continue', silent = true })
  vim.keymap.set('n', '<Down>', '<cmd>lua require("dap").step_over()<cr>', { desc = 'Debug: Step Over', silent = true })
  vim.keymap.set('n', '<Right>', '<cmd>lua require("dap").step_into()<cr>', { desc = 'Debug: Step Into', silent = true })
  vim.keymap.set('n', '<Left>', '<cmd>lua require("dap").step_out()<cr>', { desc = 'Debug: Step Out', silent = true })
end

local unset_debug_keymaps = function()
  pcall(vim.keymap.del, 'n', '<Up>')
  pcall(vim.keymap.del, 'n', '<Down>')
  pcall(vim.keymap.del, 'n', '<Right>')
  pcall(vim.keymap.del, 'n', '<Left>')
end

return {
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      -- Creates a beautiful debugger UI
      'rcarriga/nvim-dap-ui',
      'theHamsta/nvim-dap-virtual-text',

      -- Required dependency for nvim-dap-ui
      'nvim-neotest/nvim-nio',

      -- Installs the debug adapters for you
      'mason-org/mason.nvim',
      'jay-babu/mason-nvim-dap.nvim',
    },
    keys = {
      { '<leader>dd', smart_continue, desc = '[C]ontinue/Run' },
      { '<leader>dB', '<cmd>lua require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))<cr>', desc = '[B]reakpoint Condition' },
      { '<leader>db', '<cmd>lua require("dap").toggle_breakpoint()<cr>', desc = '[B]reakpoint Toggle' },
      {
        '<leader>da',
        function()
          require('dap').continue {
            -- Prompt for program arguments and run the chosen configuration with them.
            before = function(config)
              local args = vim.fn.input 'Args: '
              config = vim.deepcopy(config)
              config.args = vim.split(args, ' +', { trimempty = true })
              return config
            end,
          }
        end,
        desc = 'Continue/Run with [A]rgs',
      },
      { '<leader>dC', '<cmd>lua require("dap").run_to_cursor()<cr>', desc = 'Run to [C]ursor' },
      { '<leader>dg', '<cmd>lua require("dap").goto_()<cr>', desc = '[G]o to Line (No Execute)' },
      { '<leader>dj', '<cmd>lua require("dap").down()<cr>', desc = 'Down' },
      { '<leader>dk', '<cmd>lua require("dap").up()<cr>', desc = 'Up' },
      { '<leader>dl', '<cmd>lua require("dap").run_last()<cr>', desc = 'Run [L]ast' },
      { '<leader>dP', '<cmd>lua require("dap").pause()<cr>', desc = '[P]ause' },
      {
        '<leader>ds',
        function()
          local widgets = require 'dap.ui.widgets'
          widgets.centered_float(widgets.sessions)
        end,
        desc = '[S]essions',
      },
      { '<leader>dt', '<cmd>lua require("dap").terminate()<cr>', desc = '[T]erminate' },
      { '<leader>dx', '<cmd>lua require("dap").clear_breakpoints()<cr>', desc = '[X] Clear all breakpoints' },
      { '<leader>de', '<cmd>lua require("dap.ui.widgets").hover()<cr>', desc = '[E]xpand current variable' },
      -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
      { '<leader>du', toggle_dap_ui, desc = 'DAP [U]I: See last session result.' },
    },
    config = function()
      local dap = require 'dap'
      local dapui = require 'dapui'
      local dapui_virtual_text = require 'nvim-dap-virtual-text'

      require('mason-nvim-dap').setup {
        -- Makes a best effort to setup the various debuggers with
        -- reasonable debug configurations
        automatic_installation = true,
        handlers = {},
        -- coreclr/netcoredbg is managed manually via a local build (see dotnet_adapter above)
        ensure_installed = { 'js' },
      }

      -- Dap UI setup
      -- For more information, see |:help nvim-dap-ui|
      dapui.setup()
      dapui_virtual_text.setup()

      -- Change breakpoint icons
      vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
      vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
      local breakpoint_icons = vim.g.have_nerd_font
          and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
        or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }

      for type, icon in pairs(breakpoint_icons) do
        local tp = 'Dap' .. type
        local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
        vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
      end

      -- Auto open dap ui and close other ui elements
      dap.listeners.after.event_initialized['dapui_config'] = function()
        close_non_dap_ui()
        require('dapui').open { reset = true }
        set_debug_keymaps()
      end

      dap.listeners.before.event_terminated['dapui_config'] = function()
        unset_debug_keymaps()
      end

      dap.listeners.before.event_exited['dapui_config'] = function()
        unset_debug_keymaps()
      end

      -- dotnet
      dap.adapters.coreclr = dotnet_adapter -- unit test debugging
      dap.adapters.netcoredbg = dotnet_adapter -- normal debugging
      dap.configurations.cs = dotnet_configuration

      -- nodejs
      dap.adapters['pwa-node'] = {
        type = 'server',
        host = 'localhost',
        port = '${port}',
        executable = {
          command = 'node',
          args = { os.getenv 'HOME' .. '/.local/share/nvim/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js', '${port}' },
        },
      }

      -- typescript
      local is_test_file = function()
        return vim.fn.expand('%:t'):match '%.spec%.[tj]sx?$' ~= nil or vim.fn.expand('%:t'):match '%.test%.[tj]sx?$' ~= nil
      end

      local typescript_configuration = {
        {
          type = 'pwa-node',
          request = 'launch',
          name = 'launch - ts-node (current file)',
          condition = function()
            return not is_test_file()
          end,
          program = '${file}',
          cwd = '${workspaceFolder}',
          runtimeExecutable = 'node',
          runtimeArgs = { '--loader', 'ts-node/esm' },
          resolveSourceMapLocations = { '${workspaceFolder}/**', '!**/node_modules/**' },
          sourceMaps = true,
          skipFiles = { '<node_internals>/**', '**/node_modules/**' },
        },
        {
          type = 'pwa-node',
          request = 'launch',
          name = 'launch - tsx (current file)',
          condition = function()
            return not is_test_file()
          end,
          program = '${file}',
          cwd = '${workspaceFolder}',
          runtimeExecutable = 'node',
          runtimeArgs = { '--import', 'tsx' },
          resolveSourceMapLocations = { '${workspaceFolder}/**', '!**/node_modules/**' },
          sourceMaps = true,
          skipFiles = { '<node_internals>/**', '**/node_modules/**' },
        },
        {
          type = 'pwa-node',
          request = 'launch',
          name = 'launch - jest (current file)',
          condition = is_test_file,
          runtimeExecutable = 'node',
          runtimeArgs = function()
            local jest_bin = vim.fn.filereadable(vim.fn.getcwd() .. '/node_modules/.bin/jest') == 1 and './node_modules/.bin/jest' or 'jest'
            return { '--experimental-vm-modules', jest_bin, '--testPathPattern', '${fileBasenameNoExtension}', '--no-coverage' }
          end,
          rootDir = '${workspaceFolder}',
          cwd = '${workspaceFolder}',
          console = 'integratedTerminal',
          internalConsoleOptions = 'neverOpen',
          sourceMaps = true,
          skipFiles = { '<node_internals>/**', '**/node_modules/**' },
        },
      }

      dap.configurations.typescript = typescript_configuration
      dap.configurations.typescriptreact = typescript_configuration
    end,
  },
}
