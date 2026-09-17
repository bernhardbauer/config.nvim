return {
  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    dependencies = {
      -- Provides the textobjects.scm queries that mini.ai's treesitter specs use.
      { 'nvim-treesitter/nvim-treesitter-textobjects', branch = 'main' },
    },
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      --  - dif  - [D]elete [I]nside [F]unction (treesitter)
      --  - vac  - [V]isually select [A]round [C]lass (treesitter)
      --  - cio  - [C]hange [I]nside bl[O]ck: conditional or loop (treesitter)
      local ai = require 'mini.ai'
      ai.setup {
        n_lines = 500,
        custom_textobjects = {
          f = ai.gen_spec.treesitter { a = '@function.outer', i = '@function.inner' },
          c = ai.gen_spec.treesitter { a = '@class.outer', i = '@class.inner' },
          o = ai.gen_spec.treesitter {
            a = { '@conditional.outer', '@loop.outer' },
            i = { '@conditional.inner', '@loop.inner' },
          },
        },
      }

      -- Simple and easy statusline.
      --  You could remove this setup call if you don't like it,
      --  and try some other statusline plugin
      local statusline = require 'mini.statusline'
      -- set use_icons to true if you have a Nerd Font
      statusline.setup { use_icons = vim.g.have_nerd_font }

      -- You can configure sections in the statusline by overriding their
      -- default behavior. For example, here we set the section for
      -- cursor location to LINE:COLUMN
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
      end

      -- Branch: keep the type prefix and the ticket key, drop the description.
      --   feature/ABC-1234-add-rule-editor -> feature/ABC-1234
      --   feat/rule-test-phase-c-editors   -> feat/rule-test-p…
      --   main                             -> main
      local function short_branch(branch)
        local prefix, rest = branch:match '^([^/]+)/(.+)$'
        if not prefix then
          return branch
        end
        local ticket = rest:match '^(%u+%-%d+)'
        if ticket then
          return prefix .. '/' .. ticket
        end
        local max = 12
        if vim.fn.strchars(rest) > max then
          rest = vim.fn.strcharpart(rest, 0, max) .. '…'
        end
        return prefix .. '/' .. rest
      end

      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_git = function(args)
        if statusline.is_truncated(args.trunc_width) then
          return ''
        end
        local branch = vim.b.minigit_summary_string or vim.b.gitsigns_head
        if branch == nil then
          return ''
        end
        local icon = vim.g.have_nerd_font and '' or 'Git'
        return icon .. ' ' .. (branch == '' and '-' or short_branch(branch))
      end

      -- File name only (no path), with modified/readonly flags.
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_filename = function()
        return '%t%m%r'
      end

      -- ... and there is more!
      --  Check out: https://github.com/echasnovski/mini.nvim
    end,
  },
}
