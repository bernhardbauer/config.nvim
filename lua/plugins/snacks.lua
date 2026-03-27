return {
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      dashboard = {
        sections = {
          { section = 'header' },
          { section = 'recent_files', cwd = true, limit = 8, padding = 1 },
          { section = 'startup' },
        },
      },
      input = {}, -- used by opencode.ask()
      picker = {
        hidden = true, -- show hidden files by default across all sources
        sources = {
          explorer = {
            jump = { close = false, tagstack = true },
          },
        },
      },
      explorer = {
        replace_netrw = false, -- don't auto-open explorer on `nvim .`
      },
      indent = {},
      gitbrowse = {},
      lazygit = {},
      notifier = {},
    },
    keys = {
      { '<leader>gg', "<cmd>lua Snacks.lazygit.open()<cr>", desc = 'Lazygit' },
      { '\\', "<cmd>lua Snacks.explorer.open()<cr>", desc = 'Toggle Explorer' },
      { '<leader>xn', "<cmd>lua Snacks.notifier.show_history()<cr>", desc = 'Notification History' },
    },
  },
}
