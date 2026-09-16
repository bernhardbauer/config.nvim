-- nvim-treesitter `main` branch: it only installs parsers and queries (into
-- its install_dir, which it prepends to the runtimepath itself). Highlighting,
-- folding and indentation are Neovim features enabled per filetype below.
local languages = {
  'angular',
  'bash',
  'c',
  'css',
  'csv',
  'c_sharp',
  'diff',
  'dockerfile',
  'git_config',
  'git_rebase',
  'gitattributes',
  'gitcommit',
  'gitignore',
  'html',
  'javascript',
  'json',
  'lua',
  'luadoc',
  'markdown',
  'markdown_inline',
  'nginx',
  'pem',
  'pkl',
  'query',
  'regex',
  'scss',
  'sql',
  'terraform',
  'typescript',
  'vim',
  'vimdoc',
  'yaml',
}

return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false, -- the plugin does not support lazy-loading
    build = ':TSUpdate',
    config = function()
      local ts = require 'nvim-treesitter'
      ts.setup {}

      -- No-op for languages that are already installed.
      ts.install(languages)

      -- Enable treesitter highlighting for every filetype whose parser is
      -- installed. Parsers installed later are picked up at the next
      -- FileType event.
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('treesitter_highlight', { clear = true }),
        callback = function(ev)
          local lang = vim.treesitter.language.get_lang(ev.match)
          if lang and vim.treesitter.language.add(lang) then
            vim.treesitter.start(ev.buf, lang)
          end
        end,
      })
    end,
  },
}
