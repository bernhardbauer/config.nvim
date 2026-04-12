return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    build = ':TSUpdate',
    init = function()
      -- Prepend nvim-treesitter so its parsers and queries take precedence
      -- over Neovim 0.12's bundled (older) versions
      local ts_path = vim.fn.stdpath 'data' .. '/lazy/nvim-treesitter'
      vim.opt.runtimepath:prepend(ts_path)
    end,
    opts = {
      ensure_installed = {
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
      },
      auto_install = true,
    },
  },
}
