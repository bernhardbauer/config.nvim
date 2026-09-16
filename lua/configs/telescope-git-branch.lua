local M = {}

local function git(args, cwd)
  table.insert(args, 1, 'git')
  return require('telescope.utils').get_os_command_output(args, cwd)[1]
end

local function merge_base(cwd)
  local main_branch = git({ '--no-pager', 'branch', '-l', 'main', 'master', '--format', '%(refname:short)' }, cwd)
  local current_branch = git({ 'branch', '--show-current' }, cwd)
  return git({ 'merge-base', current_branch, main_branch }, cwd)
end

local function branch_file_diff_previewer(opts)
  local previewers = require 'telescope.previewers'
  local putils = require 'telescope.previewers.utils'
  return previewers.new_buffer_previewer {
    title = 'Git Branch File Diff Preview',
    get_buffer_by_name = function(_, entry)
      return entry.value
    end,
    define_preview = function(self, entry)
      putils.job_maker({ 'git', '--no-pager', 'diff', merge_base(opts.cwd), '--', entry.value }, self.state.bufnr, {
        value = entry.value,
        bufname = self.state.bufname,
        cwd = opts.cwd,
        callback = function(bufnr)
          if vim.api.nvim_buf_is_valid(bufnr) then
            putils.regex_highlighter(bufnr, 'diff')
          end
        end,
      })
    end,
  }
end

---@param opts? table telescope picker options; `cwd` defaults to the repo root
function M.files(opts)
  opts = opts or { cwd = git { 'rev-parse', '--show-toplevel' } }

  -- Register untracked files as intent-to-add so they show up in the diff.
  git({ 'add', '--intent-to-add', '.' }, opts.cwd)

  local conf = require('telescope.config').values
  opts.entry_maker = opts.entry_maker or require('telescope.make_entry').gen_from_file(opts)
  opts.finder_command = opts.finder_command or { 'git', '--no-pager', 'diff', merge_base(opts.cwd), '--name-only' }

  require('telescope.pickers')
    .new(opts, {
      prompt_title = 'Git Branch Files',
      finder = require('telescope.finders').new_oneshot_job(opts.finder_command, opts),
      previewer = branch_file_diff_previewer(opts),
      sorter = conf.file_sorter(opts),
    })
    :find()
end

return M
