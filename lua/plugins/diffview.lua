-- Side-by-side diffs, branch review and merge-conflict resolution.
-- lazygit (<leader>gg) covers committing; this covers reading diffs.
local function close_maps()
  return {
    { 'n', 'q', '<cmd>DiffviewClose<cr>', { desc = 'Close diffview' } },
  }
end

return {
  {
    -- Maintained fork of sindrets/diffview.nvim (drop-in); gitlab.nvim needs it
    -- for GitLab-compatible rename detection.
    'dlyongemallo/diffview-plus.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewFileHistory', 'DiffviewClose' },
    opts = {
      enhanced_diff_hl = true,
      view = {
        -- 3-way merge view with the result at the bottom.
        merge_tool = { layout = 'diff3_mixed' },
      },
      keymaps = {
        view = close_maps(),
        file_panel = close_maps(),
        file_history_panel = close_maps(),
      },
    },
    keys = {
      { '<leader>gd', '<cmd>DiffviewOpen<cr>', desc = '[G]it [D]iff working tree' },
      {
        '<leader>gD',
        function()
          -- Everything the current branch changed since it left main/master.
          local main = vim.fn.systemlist("git branch -l main master --format '%(refname:short)'")[1] or 'main'
          vim.cmd('DiffviewOpen ' .. main .. '...HEAD')
        end,
        desc = '[G]it [D]iff branch vs main',
      },
      { '<leader>gf', '<cmd>DiffviewFileHistory %<cr>', desc = '[G]it [F]ile history' },
      { '<leader>gH', '<cmd>DiffviewFileHistory<cr>', desc = '[G]it repo [H]istory' },
      -- Merge view: co/ct/cb/ca choose ours/theirs/base/all, ]x/[x next/prev conflict.
      { '<leader>gx', '<cmd>DiffviewOpen<cr>', desc = '[G]it resolve conflicts ([x])' },
    },
  },
}
