-- lua/configs/auto-reload.lua

-- Reload buffers whose files were changed outside of Neovim (e.g. by claude or
-- opencode running in a terminal split). A reloaded buffer sends didChange to
-- its LSP clients, so diagnostics, hovers etc. no longer use the stale text.
--
-- 'autoread' alone only triggers on :checktime, which Neovim runs on focus
-- changes. Agents running in an embedded terminal never cause those, so every
-- directory containing a loaded file is watched and changes trigger :checktime.
-- Directories rather than files are watched because many tools write atomically
-- (write temp file + rename), which would orphan a per-file watcher.

local M = {}

local uv = vim.uv
local watchers = {} ---@type table<string, { handle: uv.uv_fs_event_t, bufs: table<integer, true> }>
local pending = {} ---@type table<integer, true>
local timer = assert(uv.new_timer())

local function checktime_pending()
  -- :checktime is not allowed in the command-line window or while typing a command.
  if vim.fn.getcmdwintype() ~= '' or vim.api.nvim_get_mode().mode:sub(1, 1) == 'c' then
    timer:start(200, 0, vim.schedule_wrap(checktime_pending))
    return
  end
  for buf in pairs(pending) do
    if vim.api.nvim_buf_is_loaded(buf) then
      pcall(vim.cmd.checktime, buf)
    end
  end
  pending = {}
end

local function file_dir(buf)
  if vim.bo[buf].buftype ~= '' then
    return nil
  end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == '' or name:match '^%w+://' then
    return nil
  end
  return vim.fs.dirname(name)
end

local function unwatch(buf)
  for dir, w in pairs(watchers) do
    if w.bufs[buf] then
      w.bufs[buf] = nil
      if next(w.bufs) == nil then
        w.handle:stop()
        w.handle:close()
        watchers[dir] = nil
      end
    end
  end
end

local function watch(buf)
  unwatch(buf)
  local dir = file_dir(buf)
  if not dir or vim.fn.isdirectory(dir) == 0 then
    return
  end
  local w = watchers[dir]
  if not w then
    local handle = uv.new_fs_event()
    if not handle then
      return
    end
    w = { handle = handle, bufs = {} }
    local ok = handle:start(dir, {}, function(err, filename)
      if err or not filename then
        return
      end
      local path = vim.fs.joinpath(dir, vim.fs.basename(filename))
      for b in pairs(w.bufs) do
        -- Buffer names are only safe to read on the main loop; compare there.
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_name(b) == path then
            pending[b] = true
            -- Debounce: agents often write a file several times in a row.
            timer:start(100, 0, vim.schedule_wrap(checktime_pending))
          end
        end)
      end
    end)
    if not ok then
      handle:close()
      return
    end
    watchers[dir] = w
  end
  w.bufs[buf] = true
end

function M.setup()
  vim.o.autoread = true

  local group = vim.api.nvim_create_augroup('auto-reload', { clear = true })

  vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufFilePost', 'BufWritePost' }, {
    group = group,
    callback = function(ev)
      watch(ev.buf)
    end,
  })
  vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout', 'BufUnload' }, {
    group = group,
    callback = function(ev)
      unwatch(ev.buf)
    end,
  })

  -- Fallback for changes the watcher can miss (e.g. network filesystems).
  vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'TermLeave' }, {
    group = group,
    callback = function()
      if vim.fn.getcmdwintype() == '' then
        pcall(vim.cmd.checktime)
      end
    end,
  })

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      watch(buf)
    end
  end
end

return M
