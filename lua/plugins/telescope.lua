-- Directories never worth searching: VCS/IDE metadata, package and build
-- output, caches (Angular, Nx), test output and in-repo git worktrees.
local ignored_dirs = '!{.git,.worktrees,.idea,.vs,.vscode,.angular,.cache,.nx,node_modules,dist,out,out-tsc,tmp,bin,obj,coverage,test-results}'

local find_command = { 'rg', '--files', '--hidden', '--no-ignore-vcs', '-g', ignored_dirs }

-- File groups hidden by default in the file/grep pickers, each with a key
-- that toggles it inside the picker (the typed prompt is kept). The globs are
-- deliberately explicit so no other file is caught. The prompt title always
-- states the current state and the keys.
local filters = {
  { name = 'tests', key = '<C-t>', glob = '!*.{spec,test}.{ts,tsx,js,mjs}' },
  { name = 'md', key = '<C-e>', glob = '!*.{md,mdx}' },
}

---@param picker string builtin picker name
---@param title string
local function with_filters(picker, title)
  local function open(shown, prompt)
    local globs, states = {}, {}
    for _, filter in ipairs(filters) do
      if not shown[filter.name] then
        globs[#globs + 1] = filter.glob
      end
      states[#states + 1] = string.format('%s %s %s', filter.name, shown[filter.name] and 'shown' or 'hidden', filter.key:gsub('[<>]', ''))
    end

    local opts = { default_text = prompt, prompt_title = title .. ' [' .. table.concat(states, ', ') .. ']' }
    if picker == 'find_files' then
      opts.find_command = vim.deepcopy(find_command)
      for _, glob in ipairs(globs) do
        vim.list_extend(opts.find_command, { '-g', glob })
      end
    else
      opts.additional_args = {}
      for _, glob in ipairs(globs) do
        vim.list_extend(opts.additional_args, { '--glob', glob })
      end
    end
    opts.attach_mappings = function(_, map)
      for _, filter in ipairs(filters) do
        map({ 'i', 'n' }, filter.key, function(bufnr)
          local text = require('telescope.actions.state').get_current_line()
          require('telescope.actions').close(bufnr)
          local next_shown = vim.deepcopy(shown)
          next_shown[filter.name] = not shown[filter.name]
          open(next_shown, text)
        end, { desc = 'toggle ' .. filter.name .. ' files' })
      end
      return true
    end
    require('telescope.builtin')[picker](opts)
  end
  return function()
    open({})
  end
end

return {
  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- Two important keymaps to use while in Telescope are:
      --  - Insert mode: <c-/>
      --  - Normal mode: ?
      --
      -- This opens a window that shows you all of the keymaps for the current
      -- Telescope picker. This is really useful to discover what Telescope can
      -- do as well as how to actually do it!

      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      require('telescope').setup {
        pickers = {
          find_files = {
            hidden = true,
            push_tagstack_on_edit = true,
            find_command = find_command,
          },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
    end,
    keys = {
      { '<leader>fh', '<cmd>Telescope help_tags<cr>', desc = '[F]ind [H]elp' },
      { '<leader>fk', '<cmd>Telescope keymaps<cr>', desc = '[F]ind [K]eymaps' },
      { '<leader>ff', with_filters('find_files', 'Find Files'), desc = '[F]ind [F]iles' },
      { '<leader>fs', '<cmd>Telescope builtin<cr>', desc = '[F]ind [S]elect Telescope' },
      { '<leader>fw', with_filters('grep_string', 'Find Word'), desc = '[F]ind current [W]ord' },
      { '<leader>fg', with_filters('live_grep', 'Live Grep'), desc = '[F]ind by [G]rep' },
      { '<leader>fd', '<cmd>Telescope diagnostics<cr>', desc = '[F]ind [D]iagnostics' },
      { '<leader>fr', '<cmd>Telescope resume<cr>', desc = '[F]ind [R]esume' },
      { '<leader>f.', '<cmd>Telescope oldfiles<cr>', desc = '[F]ind Recent Files ("." for repeat)' },
      { '<leader><leader>', '<cmd>Telescope buffers<cr>', desc = '[ ] Find existing buffers' },
      { '<leader>ft', '<cmd>TodoTelescope<cr>', desc = '[F]ind [T]odos' },
      { '<leader>fb', function() require('configs.telescope-git-branch').files() end, desc = '[F]ind [B]ranch files' },
      {
        '<leader>/',
        function()
          -- You can pass additional configuration to Telescope to change the theme, layout, etc.
          require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
            winblend = 10,
            previewer = false,
          })
        end,
        desc = '[/] Fuzzily search in current buffer',
      },
      {
        '<leader>f/',
        function()
          -- See `:help telescope.builtin.live_grep()` for information about particular keys
          require('telescope.builtin').live_grep {
            grep_open_files = true,
            prompt_title = 'Live Grep in Open Files',
          }
        end,
        desc = '[F]ind [/] in Open Files',
      },
      {
        '<leader>fn',
        function()
          require('telescope.builtin').find_files { cwd = vim.fn.stdpath 'config' }
        end,
        desc = '[F]ind [N]eovim files',
      },
    },
  },
}
