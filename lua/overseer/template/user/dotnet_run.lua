local overseer = require 'overseer'

---@type overseer.TemplateFileProvider
return {
  generator = function()
    local files = {}
    vim.list_extend(files, vim.fn.glob('*.csproj', false, true))
    vim.list_extend(files, vim.fn.glob('*/*.csproj', false, true))
    if #files == 0 then
      return 'No csproj files found!'
    end

    local ret = {}

    for _, file in ipairs(files) do
      local project_name = vim.fn.fnamemodify(file, ':t:r')
      table.insert(ret, {
        name = string.format('%s %s %s', 'dotnet', 'run', project_name),
        tags = { overseer.TAG.RUN },
        builder = function()
          return {
            cmd = { 'dotnet', 'run', '--project', file },
            -- cwd = workspace_path,
          }
        end,
      })
    end

    table.insert(ret, {
      name = 'dotnet test',
      tags = { overseer.TAG.TEST },
      builder = function()
        return {
          cmd = { 'dotnet', 'test' },
          -- cwd = workspace_path,
        }
      end,
    })

    for _, file in ipairs(files) do
      local project_name = vim.fn.fnamemodify(file, ':t:r')
      table.insert(ret, {
        name = string.format('%s %s %s', 'dotnet', 'build', project_name),
        builder = function()
          return {
            cmd = { 'dotnet', 'build', file, '-c', 'Debug' },
            -- cwd = workspace_path,
          }
        end,
      })
    end

    return ret
  end,
}
