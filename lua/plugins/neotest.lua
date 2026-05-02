local function find_config_dir(path, config_names)
  path = path or vim.fn.getcwd()
  -- Start from the file's directory (or the path itself if already a dir)
  local dir = vim.fn.isdirectory(path) == 1 and path or vim.fn.fnamemodify(path, ':h')
  local root = vim.fn.getcwd()

  while true do
    for _, name in ipairs(config_names) do
      if vim.fn.filereadable(dir .. '/' .. name) == 1 then
        return dir
      end
    end
    -- Stop once we've reached or passed the project root
    if dir == root or dir == '/' then
      return root
    end
    dir = vim.fn.fnamemodify(dir, ':h')
  end
end

local function find_jest_config_dir(path)
  return find_config_dir(path, {
    'jest.config.ts',
    'jest.config.js',
    'jest.config.mjs',
    'jest.config.cjs',
  })
end

local function find_vitest_config_dir(path)
  return find_config_dir(path, {
    'vitest.config.ts',
    'vitest.config.js',
    'vitest.config.mts',
    'vitest.config.mjs',
    'vitest.config.cts',
    'vitest.config.cjs',
    'vite.config.ts',
    'vite.config.js',
    'vite.config.mts',
    'vite.config.mjs',
    'vite.config.cts',
    'vite.config.cjs',
    'package.json',
  })
end

local function current_file_path()
  return vim.fn.expand '%:p'
end

return {
  {
    'nvim-neotest/neotest',
    -- ft = { 'cs', 'typescript', 'javascript' },
    dependencies = {
      'nvim-neotest/nvim-nio',
      'nvim-lua/plenary.nvim',
      'antoinemadec/FixCursorHold.nvim',
      'nvim-treesitter/nvim-treesitter',
      'mfussenegger/nvim-dap',
      'nvim-neotest/neotest-jest',
      'marilari88/neotest-vitest',
      'Issafalcon/neotest-dotnet',
    },
    opts = function()
      return {
        discovery = {
          enabled = true,
          -- Only scan for TypeScript/JavaScript test files; avoids scanning
          -- compiled output dirs and other noise.
          filter_dir = function(name, _rel, _root)
            -- node_modules / dist / build: JS/TS build artifacts
            -- bin / obj: .NET build artifacts (also excluded by neotest-dotnet's own filter_dir)
            -- .git / .vs: VCS and Visual Studio metadata
            return name ~= 'node_modules'
              and name ~= 'dist'
              and name ~= 'build'
              and name ~= '.angular'
              and name ~= '.cache'
              and name ~= '.git'
              and name ~= '.vs'
              and name ~= 'coverage'
              and name ~= 'out'
              and name ~= 'out-tsc'
              and name ~= 'bin'
              and name ~= 'obj'
          end,
        },
        adapters = {
          require 'neotest-dotnet' {
            dap = {
              -- Extra arguments for nvim-dap configuration
              -- See https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for values
              args = { justMyCode = false },
              adapter_name = 'netcoredbg',
            },
          },
          -- Put Angular ahead of the generic JS adapters so Angular workspaces
          -- execute through `ng test` even when a parent package also exposes
          -- Jest or Vitest dependencies.
          require 'neotest-angular'(),
          require 'neotest-jest' {
            jest_test_discovery = false,
            cwd = find_jest_config_dir,
          },
          require 'neotest-vitest' {
            cwd = find_vitest_config_dir,
          },
        },
        log_level = vim.log.levels.DEBUG, -- Set the log level
      }
    end,
    keys = {
      { '<leader>tt', '<cmd>lua require("neotest").run.run()<cr>', desc = '[R]un Nearest' },
      {
        '<leader>tf',
        function()
          require('neotest').run.run(current_file_path())
        end,
        desc = 'Run Current [F]ile',
      },
      { '<leader>tA', '<cmd>lua require("neotest").run.run(vim.uv.cwd())<cr>', desc = 'Run [A]ll Test Files' },
      { '<leader>tl', '<cmd>lua require("neotest").run.run_last()<cr>', desc = 'Run [L]ast' },
      { '<leader>ts', '<cmd>lua require("neotest").summary.toggle()<cr>', desc = 'Toggle [S]ummary' },
      { '<leader>to', '<cmd>lua require("neotest").output.open({ enter = true, auto_close = true })<cr>', desc = 'Show [O]utput' },
      { '<leader>tO', '<cmd>lua require("neotest").output_panel.toggle()<cr>', desc = 'Toggle [O]utput Panel' },
      { '<leader>tS', '<cmd>lua require("neotest").run.stop()<cr>', desc = '[S]top' },
      {
        '<leader>tw',
        function()
          require('neotest').watch.toggle(current_file_path())
        end,
        desc = '[W]atch Toggle',
      },
      { '<leader>td', '<cmd>lua require("neotest").run.run({strategy = "dap"})<cr>', desc = '[D]ebug Nearest' },
    },
  },
}
