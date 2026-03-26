return {
  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',
        'mrloop/telescope-git-branch.nvim',

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
            find_command = {
              'rg',
              '--files',
              '--hidden',
              '--no-ignore-vcs',
              '-g',
              '!{.git,.idea,.vs,.vscode,.angular,.cache,node_modules,dist,out,out-tsc,bin,obj,coverage}',
            },
          },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
    end,
    keys = {
      { '<leader>fh', '<cmd>Telescope help_tags<cr>', desc = '[F]ind [H]elp' },
      { '<leader>fk', '<cmd>Telescope keymaps<cr>', desc = '[F]ind [K]eymaps' },
      { '<leader>ff', '<cmd>Telescope find_files<cr>', desc = '[F]ind [F]iles' },
      { '<leader>fs', '<cmd>Telescope builtin<cr>', desc = '[F]ind [S]elect Telescope' },
      { '<leader>fw', '<cmd>Telescope grep_string<cr>', desc = '[F]ind current [W]ord' },
      { '<leader>fg', '<cmd>Telescope live_grep<cr>', desc = '[F]ind by [G]rep' },
      { '<leader>fd', '<cmd>Telescope diagnostics<cr>', desc = '[F]ind [D]iagnostics' },
      { '<leader>fr', '<cmd>Telescope resume<cr>', desc = '[F]ind [R]esume' },
      { '<leader>f.', '<cmd>Telescope oldfiles<cr>', desc = '[F]ind Recent Files ("." for repeat)' },
      { '<leader><leader>', '<cmd>Telescope buffers<cr>', desc = '[ ] Find existing buffers' },
      { '<leader>ft', '<cmd>TodoTelescope<cr>', desc = '[F]ind [T]odos' },
      { '<leader>fb', '<cmd>Telescope git_branch<cr>', desc = '[F]ind [B]ranch files' },
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
