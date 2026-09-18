-- GitLab merge requests inside Neovim: review the MR diff (diffview) with the
-- discussion threads next to it, comment, approve, merge, watch the pipeline.
--
-- Token: the helper authenticates with GitLab's PRIVATE-TOKEN header, which only
-- accepts personal access tokens (glpat-...), not the OAuth tokens `glab auth
-- login` stores by default. Looked up in this order:
--   1. $GITLAB_TOKEN
--   2. macOS keychain, glab's own entry (glab:<host>:token) if it is a PAT
--      (`glab auth login --token <pat>` puts one there; then glab and this
--      plugin share a single secret)
--   3. macOS keychain, entry "gitlab.nvim":
--      security add-generic-password -s gitlab.nvim -a "$USER" -w '<pat>'
--   4. ~/.config/gitlab-nvim/token (chmod 600)
local function gitlab_host()
  return (os.getenv 'GITLAB_URL' or 'https://gitlab.com'):gsub('^https?://', ''):gsub('/$', '')
end

local function keychain(service)
  if vim.fn.has 'mac' ~= 1 or vim.fn.executable 'security' ~= 1 then
    return nil
  end
  local result = vim.system({ 'security', 'find-generic-password', '-s', service, '-w' }, { text = true }):wait()
  local token = result.code == 0 and vim.trim(result.stdout or '') or ''
  return token ~= '' and token or nil
end

local function token_file()
  local f = io.open(vim.fs.normalize(vim.fn.stdpath 'config' .. '/../gitlab-nvim/token'), 'r')
  if not f then
    return nil
  end
  local token = vim.trim(f:read '*a' or '')
  f:close()
  return token ~= '' and token or nil
end

local function is_pat(token)
  return token ~= nil and token:match '^glpat%-' ~= nil
end

local function find_token()
  local env = os.getenv 'GITLAB_TOKEN'
  if env and env ~= '' then
    return env
  end
  local glab = keychain('glab:' .. gitlab_host() .. ':token')
  if is_pat(glab) then
    return glab
  end
  return keychain 'gitlab.nvim' or token_file()
end

local function gl(fn, ...)
  local args = { ... }
  return function()
    return require('gitlab')[fn](unpack(args))
  end
end

-- The Go helper resolves "the MR" once, from the branch checked out when it
-- started, and keeps that MR id for every later request. After switching
-- branches (lazygit, git) a plain review() therefore still shows the old MR.
-- Restart the helper first when the branch no longer matches the loaded MR.
local function review_current_branch()
  local gitlab = require 'gitlab'
  local state = require 'gitlab.state'
  local branch = vim.trim(vim.fn.system 'git branch --show-current')
  local loaded = state.INFO and state.INFO.source_branch
  if loaded and loaded ~= branch then
    state.chosen_mr_iid = 0
    require('gitlab.server').restart(gitlab.review)
  else
    gitlab.review()
  end
end

-- Source patches applied to the Go helper before compiling. Re-applied on
-- every update by the build hook; each is a no-op if upstream changed or
-- fixed the code.
--  * Fine-grained GitLab tokens have no permission for award emoji yet, and
--    the helper aborts the whole discussion listing when fetching them fails.
--  * gitlab.com's GraphQL currently errors on `mergeabilityChecks` ("Cannot
--    return null for non-nullable element") and nulls the merge request; the
--    helper passes that null through and the Lua summary crashes on it.
local helper_patches = {
  {
    file = 'cmd/app/list_discussions.go',
    from = 'if err != nil {\n\t\thandleError%(w, err, "Could not fetch emojis", http%.StatusInternalServerError%)\n\t\treturn\n\t}',
    to = 'if err != nil {\n\t\temojis = map[int64][]*gitlab.AwardEmoji{} // patched by nvim config: emoji fetch is non-fatal\n\t}',
  },
  {
    file = 'cmd/app/mergeability_checks.go',
    from = 'return response%.Data%.Project%.MergeRequest%.MergeabilityChecks, nil',
    to = 'checks := response.Data.Project.MergeRequest.MergeabilityChecks // patched by nvim config: never null\n\tif checks == nil {\n\t\tchecks = []*MergeabilityCheck{}\n\t}\n\treturn checks, nil',
  },
}

local function patch_helper(plugin_dir)
  for _, patch in ipairs(helper_patches) do
    local path = plugin_dir .. '/' .. patch.file
    local f = io.open(path, 'r')
    if f then
      local src = f:read '*a'
      f:close()
      local patched, n = src:gsub(patch.from, patch.to)
      if n > 0 then
        f = assert(io.open(path, 'w'))
        f:write(patched)
        f:close()
      end
    end
  end
end

return {
  {
    'harrisoncramer/gitlab.nvim',
    dependencies = {
      'MunifTanjim/nui.nvim',
      'dlyongemallo/diffview-plus.nvim',
      'nvim-tree/nvim-web-devicons',
    },
    build = function(plugin)
      patch_helper(plugin.dir)
      require('gitlab.server').build(true)
    end,
    opts = {
      auth_provider = function()
        local token = find_token()
        if not token then
          return nil,
            nil,
            'No GitLab personal access token found: export GITLAB_TOKEN, run `glab auth login --token <pat>`, '
              .. 'add a "gitlab.nvim" keychain item, or create ~/.config/gitlab-nvim/token'
        end
        return token, os.getenv 'GITLAB_URL' or 'https://gitlab.com', nil
      end,
      discussion_tree = {
        -- Open with the review but keep the cursor in the diff.
        focus_on_open = false,
      },
      keymaps = {
        -- Everything lives under <leader>gm (see `keys` below); no second `gl…` scheme.
        global = { disable_all = true },
        popup = {
          perform_action = '<C-s>', -- send (also mapped in insert mode below)
          discard_changes = '<Esc>', -- close without sending
        },
        -- <CR> on a commented line in the diff opens its thread; <CR> in the
        -- tree expands/collapses; `o` in the tree jumps back to the code.
        reviewer = { move_to_discussion_tree = '<CR>' },
        discussion_tree = { toggle_node = '<CR>' },
      },
    },
    config = function(_, opts)
      require('gitlab').setup(opts)

      -- Show unresolved threads expanded whenever the tree is (re)built, instead
      -- of a list of collapsed one-liners that each need `t`.
      local discussions = require 'gitlab.actions.discussions'
      local rebuild = discussions.rebuild_discussion_tree
      discussions.rebuild_discussion_tree = function(...)
        rebuild(...)
        local tree = discussions.discussion_tree
        if tree then
          local tree_utils = require 'gitlab.actions.discussions.tree'
          for _, node in ipairs(tree:get_nodes()) do
            tree_utils.expand_recursively(tree, node, false)
          end
          tree:render()
        end
      end

      local group = vim.api.nvim_create_augroup('gitlab_nvim_ux', { clear = true })

      -- Comment / summary popups: <C-s> sends from insert mode too.
      vim.api.nvim_create_autocmd('BufWinEnter', {
        group = group,
        callback = function(ev)
          local send = vim.fn.maparg('<C-s>', 'n', false, true)
          if send.buffer == 1 and send.desc == 'Perform action' then
            vim.keymap.set('i', '<C-s>', '<Esc><C-s>', { buffer = ev.buf, remap = true, desc = 'Send' })
          end
        end,
      })

      -- Discussion tree and other plugin panels: <Esc> closes them.
      vim.api.nvim_create_autocmd('FileType', {
        group = group,
        pattern = 'gitlab',
        callback = function(ev)
          vim.keymap.set('n', '<Esc>', function()
            require('gitlab').toggle_discussions()
          end, { buffer = ev.buf, desc = 'Close discussions' })
        end,
      })
    end,
    keys = {
      -- review
      { '<leader>gmc', gl 'choose_merge_request', desc = '[C]hoose MR to review' },
      { '<leader>gmr', review_current_branch, desc = '[R]eview current branch MR' },
      { '<leader>gmR', gl 'reload_review', desc = '[R]eload review' },
      { '<leader>gms', gl 'summary', desc = 'MR [S]ummary' },
      { '<leader>gmd', gl 'toggle_discussions', desc = 'Toggle [D]iscussions' },
      { '<leader>gmo', gl 'open_in_browser', desc = '[O]pen MR in browser' },
      { '<leader>gmu', gl 'copy_mr_url', desc = 'Copy MR [U]RL' },
      -- comments
      { '<leader>gmn', gl 'create_comment', desc = '[N]ew comment on line', mode = 'n' },
      { '<leader>gmn', gl 'create_multiline_comment', desc = '[N]ew comment on range', mode = 'v' },
      { '<leader>gmN', gl 'create_note', desc = '[N]ew MR-level note' },
      { '<leader>gmD', gl 'toggle_draft_mode', desc = 'Toggle [D]raft mode' },
      { '<leader>gmP', gl 'publish_all_drafts', desc = '[P]ublish all drafts' },
      -- decisions
      { '<leader>gma', gl 'approve', desc = '[A]pprove MR' },
      { '<leader>gmA', gl 'revoke', desc = 'Revoke [A]pproval' },
      { '<leader>gmm', gl 'merge', desc = '[M]erge MR' },
      { '<leader>gmM', gl 'set_auto_merge', desc = 'Auto-[M]erge when pipeline succeeds' },
      { '<leader>gmb', gl 'rebase', desc = 'Re[b]ase MR' },
      -- ci
      { '<leader>gmp', gl 'pipeline', desc = '[P]ipeline status' },
      -- people & labels
      { '<leader>gmC', gl 'create_mr', desc = '[C]reate MR from branch' },
      { '<leader>gmv', gl 'add_reviewer', desc = 'Add re[v]iewer' },
      { '<leader>gmV', gl 'delete_reviewer', desc = 'Remove re[v]iewer' },
      { '<leader>gme', gl 'add_assignee', desc = 'Add assign[e]e' },
      { '<leader>gmE', gl 'delete_assignee', desc = 'Remove assign[e]e' },
      { '<leader>gml', gl 'add_label', desc = 'Add [l]abel' },
      { '<leader>gmL', gl 'delete_label', desc = 'Remove [l]abel' },
    },
  },
}
