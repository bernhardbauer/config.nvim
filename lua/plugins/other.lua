return {
  {
    'rgroli/other.nvim',
    config = function()
      require('other-nvim').setup {
        mappings = {
          'angular',
          -- TypeScript: source ↔ test
          { pattern = '(.*)/(.*)%.ts$', target = '%1/%2.spec.ts' },
          { pattern = '(.*)/(.*)%.spec%.ts$', target = '%1/%2.ts' },
          -- JavaScript: source ↔ test
          { pattern = '(.*)/(.*)%.js$', target = '%1/%2.spec.js' },
          { pattern = '(.*)/(.*)%.spec%.js$', target = '%1/%2.js' },
        },
        rememberBuffers = false,
        hooks = {
          onFindOtherFiles = function(matches)
            local function push_tagstack()
              local pos = vim.fn.getpos '.'
              pos[1] = vim.api.nvim_get_current_buf()
              vim.fn.settagstack(vim.fn.win_getid(), { items = { { tagname = vim.fn.expand '<cword>', from = pos } } }, 't')
            end

            local current = vim.fn.expand '%:p'
            local dir = vim.fn.expand '%:p:h'
            local name = vim.fn.expand '%:t'

            local seen = {}
            for _, m in ipairs(matches) do
              seen[vim.fn.fnamemodify(m.filename, ':p')] = true
            end
            seen[current] = true

            -- Strip extensions progressively to find sibling files:
            -- app.component.html → glob app.component.* → glob app.*
            local stem = name
            while true do
              local shorter = stem:match '(.+)%.[^.]+$'
              if not shorter then
                break
              end
              stem = shorter
              for _, path in ipairs(vim.fn.glob(dir .. '/' .. stem .. '.*', false, true)) do
                local abs = vim.fn.fnamemodify(path, ':p')
                if not seen[abs] and vim.fn.isdirectory(abs) == 0 then
                  table.insert(matches, { filename = abs, exists = true })
                  seen[abs] = true
                end
              end
              if not stem:find '%.' then
                break
              end
            end

            if #matches <= 1 then
              if #matches == 1 then
                push_tagstack()
              end
              return matches
            end
            vim.ui.select(matches, {
              prompt = 'Other Files',
              format_item = function(item)
                local label = vim.fn.fnamemodify(item.filename, ':t')
                return item.exists and label or label .. ' (new)'
              end,
            }, function(item)
              if item then
                push_tagstack()
                local d = vim.fn.fnamemodify(item.filename, ':h')
                if vim.fn.isdirectory(d) == 0 then
                  vim.fn.mkdir(d, 'p')
                end
                vim.cmd('edit ' .. vim.fn.fnameescape(item.filename))
              end
            end)
            return {}
          end,
        },
      }
    end,
    keys = {
      {
        '<leader>fa',
        function()
          -- Suppress the "No 'other' file found." notification
          local orig_notify = vim.notify
          vim.notify = function(msg, ...)
            if msg ~= "No 'other' file found." then
              orig_notify(msg, ...)
            end
          end
          vim.cmd 'Other'
          vim.notify = orig_notify
        end,
        desc = '[F]ind [A]lternative',
      },
    },
  },
}
