-- Enable the following language servers
--  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
--
--  Keys are the names used by `vim.lsp.config` (nvim-lspconfig's `lsp/<name>.lua`).
--  Add any additional override configuration in the following tables. Available keys are:
--  - cmd (table): Override the default command used to start the server
--  - filetypes (table): Override the default list of associated filetypes for the server
--  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
--  - settings (table): Override the default settings passed when initializing the server.
--        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
local servers = {
  csharp_ls = {},
  ts_ls = {},
  angularls = {},
  eslint = {}, -- vscode-eslint-language-server; uses the project's eslint.config.*
  tflint = {},
  emmet_ls = {
    filetypes = { 'html', 'css', 'scss', 'sass', 'less', 'javascriptreact', 'typescriptreact', 'vue', 'svelte' },
  },
  lua_ls = {
    settings = {
      Lua = {
        completion = {
          callSnippet = 'Replace',
        },
        -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
        -- diagnostics = { disable = { 'missing-fields' } },
      },
    },
  },
}

-- Mason packages that are not language servers (formatters, debug adapters).
local tools = {
  'csharpier',
  'js-debug-adapter',
  'stylua', -- Used to format Lua code
}

return {
  -- LSP Plugins
  {
    -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
    -- used for completion, annotations and signatures of Neovim apis
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        -- Load luvit types when the `vim.uv` word is found
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },
  {
    -- Main LSP Configuration
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Automatically install LSPs and related tools to stdpath for Neovim
      -- Mason must be loaded before its dependents so we need to set it up here.
      -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
      { 'mason-org/mason.nvim', opts = {} },
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Useful status updates for LSP.
      { 'j-hui/fidget.nvim', opts = {} },

      -- Allows extra capabilities provided by blink.cmp
      'saghen/blink.cmp',
    },
    config = function()
      --  This function gets run when an LSP attaches to a particular buffer.
      --    That is to say, every time a new file is opened that is associated with
      --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
      --    function will be executed to configure the current buffer
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- Rename via ts_ls only (when available) to avoid double prompts when multiple LSP clients support rename (e.g. ts_ls + angularls).
          map('grn', function()
            local clients = vim.lsp.get_clients { bufnr = 0, method = 'textDocument/rename' }
            local preferred = vim.iter(clients):find(function(c)
              return c.name == 'ts_ls'
            end)
            vim.lsp.buf.rename(nil, preferred and {
              filter = function(c)
                return c.name == 'ts_ls'
              end,
            } or nil)
          end, '[R]e[n]ame')

          -- Execute a code action, usually your cursor needs to be on top of an error or a suggestion from your LSP for this to activate.
          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })
          -- References from every attached client (ts_ls and angularls both
          -- answer for .ts files, and angularls alone knows template usages),
          -- deduplicated by location before showing them in telescope.
          map('grr', function()
            vim.lsp.buf.references(nil, {
              on_list = function(list)
                local seen, items = {}, {}
                for _, item in ipairs(list.items) do
                  local key = item.filename .. ':' .. item.lnum .. ':' .. item.col
                  if not seen[key] then
                    seen[key] = true
                    items[#items + 1] = item
                  end
                end
                local conf = require('telescope.config').values
                require('telescope.pickers')
                  .new({}, {
                    prompt_title = 'LSP References',
                    finder = require('telescope.finders').new_table {
                      results = items,
                      entry_maker = require('telescope.make_entry').gen_from_quickfix {},
                    },
                    previewer = conf.qflist_previewer {},
                    sorter = conf.generic_sorter {},
                    push_cursor_on_edit = true,
                    push_tagstack_on_edit = true,
                  })
                  :find()
              end,
            })
          end, '[G]oto [R]eferences')
          map('gri', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
          -- Jump to the definition of the word under your cursor.
          --  This is where a variable was first declared, or where a function is defined, etc.
          --  To jump back, press <C-t>.
          map('grd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header.
          -- map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- Fuzzy find all the symbols in your current document/workspace.
          --  Symbols are things like variables, functions, types, etc.
          map('gO', require('telescope.builtin').lsp_document_symbols, 'Open Document Symbols')
          map('gW', require('telescope.builtin').lsp_dynamic_workspace_symbols, 'Open Workspace Symbols')

          -- Jump to the type of the word under your cursor.
          --  Useful when you're not sure what type a variable is and you want to see
          --  the definition of its *type*, not where it was *defined*.
          map('grt', require('telescope.builtin').lsp_type_definitions, '[G]oto [T]ype Definition')

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          -- The following code creates a keymap to toggle inlay hints in your
          -- code, if the language server you are using supports them
          --
          -- This may be unwanted, since they displace some of your code
          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map('<leader>xh', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, 'Toggle LSP Inlay [H]ints')
          end

          -- typescript specifics
          if client and client.name == 'ts_ls' then
            local make_source_action_command = function(bufnr, client, source_action)
              local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
              params.context = {
                only = { source_action },
                diagnostics = vim.diagnostic.get(bufnr),
              }

              client:request('textDocument/codeAction', params, function(err, res)
                assert(not err, err)
                if res and res[1] and res[1].edit then
                  vim.lsp.util.apply_workspace_edit(res[1].edit, client.offset_encoding)
                end
              end, bufnr)
            end

            map('gru', function()
              make_source_action_command(event.buf, client, 'source.removeUnused.ts')
            end, 'TS Remove Unused')

            map('gro', function()
              make_source_action_command(event.buf, client, 'source.organizeImports.ts')
            end, 'TS Organize Imports')

            map('grO', function()
              make_source_action_command(event.buf, client, 'source.addMissingImports.ts')
            end, 'TS Add Missing Imports')
          end
        end,
      })

      -- Diagnostic Config
      -- See :help vim.diagnostic.Opts
      vim.diagnostic.config {
        severity_sort = true,
        float = { border = 'rounded', source = 'if_many' },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs = vim.g.have_nerd_font and {
          text = {
            [vim.diagnostic.severity.ERROR] = '󰅚 ',
            [vim.diagnostic.severity.WARN] = '󰀪 ',
            [vim.diagnostic.severity.INFO] = '󰋽 ',
            [vim.diagnostic.severity.HINT] = '󰌶 ',
          },
        } or {},
        virtual_text = {
          source = 'if_many',
          spacing = 2,
          format = function(diagnostic)
            local diagnostic_message = {
              [vim.diagnostic.severity.ERROR] = diagnostic.message,
              [vim.diagnostic.severity.WARN] = diagnostic.message,
              [vim.diagnostic.severity.INFO] = diagnostic.message,
              [vim.diagnostic.severity.HINT] = diagnostic.message,
            }
            return diagnostic_message[diagnostic.severity]
          end,
        },
      }

      -- Per-server overrides. blink.cmp registers its completion capabilities
      -- for every server itself (vim.lsp.config('*', ...)), so nothing to merge.
      for name, config in pairs(servers) do
        if next(config) then
          vim.lsp.config(name, config)
        end
      end

      -- Ensure the servers and tools above are installed
      --
      -- To check the current status of installed tools and/or manually install
      -- other tools, you can run
      --    :Mason
      local ensure_installed = vim.tbl_keys(servers)
      vim.list_extend(ensure_installed, tools)
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      -- mason-lspconfig v2 enables every installed server through vim.lsp.enable().
      -- stylua is installed as a formatter only; keep its LSP mode off.
      require('mason-lspconfig').setup {
        ensure_installed = {},
        automatic_enable = { exclude = { 'stylua' } },
      }
    end,
  },
}
