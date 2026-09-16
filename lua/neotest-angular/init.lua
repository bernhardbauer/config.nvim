---@diagnostic disable: undefined-field
local async = require 'neotest.async'
local lib = require 'neotest.lib'
local logger = require 'neotest.logging'
local vitest_util = require 'neotest-vitest.util'

---@class neotest.AngularOptions
---@field angularCommand? string|fun(path: string): string|string[] `ng` command for angular.json workspaces
---@field nxCommand? string|fun(path: string): string|string[] `nx` command for nx.json workspaces
---@field filter_dir? fun(name: string, rel_path: string, root: string): boolean

---@class neotest.Adapter
local adapter = { name = 'neotest-angular' }

local test_query = [[
  ; -- Namespaces --
  ((call_expression
    function: (identifier) @func_name (#eq? @func_name "describe")
    arguments: (arguments (string (string_fragment) @namespace.name) (arrow_function))
  )) @namespace.definition
  ((call_expression
    function: (member_expression
      object: (identifier) @func_name (#any-of? @func_name "describe")
    )
    arguments: (arguments (string (string_fragment) @namespace.name) (arrow_function))
  )) @namespace.definition
  ((call_expression
    function: (call_expression
      function: (member_expression
        object: (identifier) @func_name (#any-of? @func_name "describe")
      )
    )
    arguments: (arguments (string (string_fragment) @namespace.name) (arrow_function))
  )) @namespace.definition

  ; -- Tests --
  ((call_expression
    function: (identifier) @func_name (#any-of? @func_name "it" "test")
    arguments: (arguments (string (string_fragment) @test.name) (arrow_function))
  )) @test.definition
  ((call_expression
    function: (member_expression
      object: (identifier) @func_name (#any-of? @func_name "test" "it")
    )
    arguments: (arguments (string (string_fragment) @test.name) (arrow_function))
  )) @test.definition
  ((call_expression
    function: (call_expression
      function: (member_expression
        object: (identifier) @func_name (#any-of? @func_name "it" "test")
      )
    )
    arguments: (arguments (string (string_fragment) @test.name) (arrow_function))
  )) @test.definition
]]

test_query = test_query .. string.gsub(test_query, 'arrow_function', 'function_expression')

local default_filter_dir = function(name)
  return name ~= 'node_modules'
    and name ~= 'dist'
    and name ~= 'build'
    and name ~= '.angular'
    and name ~= '.cache'
    and name ~= '.git'
    and name ~= '.vs'
    and name ~= 'coverage'
    and name ~= 'out'
    and name ~= 'out-tsc'
end

local options = {
  filter_dir = default_filter_dir,
}

local function path_join(...)
  return table.concat(vim.iter({ ... }):flatten():totable(), '/')
end

local function normalize(path)
  return vim.fs.normalize(path)
end

local function read_json(path)
  local ok, content = pcall(lib.files.read, path)
  if not ok then
    return nil
  end

  local decoded_ok, decoded = pcall(vim.json.decode, content)
  if not decoded_ok then
    logger.error('Failed to parse json file ', path)
    return nil
  end

  return decoded
end

local function is_descendant(root, path)
  root = normalize(root)
  path = normalize(path)
  return path == root or vim.startswith(path, root .. '/')
end

local function relative_to(root, path)
  root = normalize(root)
  path = normalize(path)
  if path == root then
    return '.'
  end
  return path:sub(#root + 2)
end

-- Workspace root: an Angular CLI workspace (angular.json) or an Nx workspace
-- (nx.json). Both run tests through the `@angular/build:unit-test` builder;
-- they differ in where projects are declared and in what `--include` paths are
-- relative to.
local function workspace_root(path)
  return vitest_util.search_ancestors(path, function(dir)
    return vitest_util.path.is_file(path_join(dir, 'angular.json')) or vitest_util.path.is_file(path_join(dir, 'nx.json'))
  end)
end

local function get_project_targets(project)
  return project.architect or project.targets or {}
end

local function get_test_target(project)
  return get_project_targets(project).test
end

local function get_project_root(workspace_root, project)
  local project_root = project.root or ''
  if project_root == '' then
    return normalize(workspace_root)
  end
  return normalize(path_join(workspace_root, project_root))
end

local function supports_vitest(project)
  local test_target = get_test_target(project)
  if not test_target then
    return false
  end

  local builder = test_target.builder or test_target.executor
  if builder ~= '@angular/build:unit-test' then
    return false
  end

  local runner = (test_target.options or {}).runner or 'vitest'
  return runner == 'vitest'
end

local function get_workspace(path)
  local root = workspace_root(path)
  if not root then
    return nil
  end
  root = normalize(root)

  if vitest_util.path.is_file(path_join(root, 'angular.json')) then
    local workspace = read_json(path_join(root, 'angular.json'))
    if not workspace then
      return nil
    end
    return { kind = 'angular', root = root, config = workspace }
  end

  return { kind = 'nx', root = root }
end

-- Angular CLI: projects are listed in angular.json; pick the deepest one
-- containing `path`.
local function get_angular_project_for_path(workspace, path)
  local best_name, best_project, best_root

  for name, project in pairs(workspace.config.projects or {}) do
    if supports_vitest(project) then
      local project_root = get_project_root(workspace.root, project)
      if is_descendant(project_root, path) then
        if not best_root or #project_root > #best_root then
          best_name, best_project, best_root = name, project, project_root
        end
      end
    end
  end

  if not best_project then
    return nil
  end

  return {
    kind = 'angular',
    workspace_root = workspace.root,
    name = best_name,
    project_root = best_root,
    test_target = get_test_target(best_project),
  }
end

-- Nx: the project is the nearest ancestor directory (within the workspace)
-- holding a project.json. Cached per directory; project.json rarely changes.
local nx_project_cache = {}

local function get_nx_project_for_path(workspace, path)
  local dir = vim.fn.isdirectory(path) == 1 and path or vim.fn.fnamemodify(path, ':h')
  dir = normalize(dir)

  while is_descendant(workspace.root, dir) do
    local cached = nx_project_cache[dir]
    if cached ~= nil then
      return cached or nil
    end

    local project_file = path_join(dir, 'project.json')
    if vitest_util.path.is_file(project_file) then
      local project = read_json(project_file) or {}
      local result = false
      if supports_vitest(project) then
        result = {
          kind = 'nx',
          workspace_root = workspace.root,
          name = project.name or vim.fn.fnamemodify(dir, ':t'),
          project_root = dir,
          test_target = get_test_target(project),
        }
      end
      nx_project_cache[dir] = result
      return result or nil
    end

    if dir == workspace.root then
      break
    end
    dir = vim.fn.fnamemodify(dir, ':h')
  end

  return nil
end

local function get_project_for_path(path)
  local workspace = get_workspace(path)
  if not workspace then
    return nil
  end

  if workspace.kind == 'angular' then
    return get_angular_project_for_path(workspace, path)
  end
  return get_nx_project_for_path(workspace, path)
end

local function is_spec_file(file_path)
  return file_path:match '%.spec%.ts$' or file_path:match '%.test%.ts$'
end

local function escape_test_pattern(s)
  return (
    s:gsub('%(', '\\(')
      :gsub('%)', '\\)')
      :gsub('%]', '\\]')
      :gsub('%[', '\\[')
      :gsub('%.', '\\.')
      :gsub('%*', '\\*')
      :gsub('%+', '\\+')
      :gsub('%-', '\\-')
      :gsub('%?', '\\?')
      :gsub(' ', '\\s')
      :gsub('%$', '\\$')
      :gsub('%^', '\\^')
      :gsub('%/', '\\/')
  )
end

local function get_name_pattern(tree)
  local position_type = tree:data().type
  local names = {}
  while tree and tree:data().type ~= 'file' and tree:data().type ~= 'dir' do
    table.insert(names, 1, tree:data().name)
    tree = tree:parent()
  end

  local pattern = table.concat(names, ' ')
  if pattern == '' then
    return nil
  end

  if position_type == 'test' then
    return '^\\s?' .. escape_test_pattern(pattern) .. '$'
  end

  return '^\\s?' .. escape_test_pattern(pattern)
end

local function resolve_command(project, path)
  local bin = project.kind == 'nx' and 'nx' or 'ng'
  local override = project.kind == 'nx' and options.nxCommand or options.angularCommand
  if type(override) == 'function' then
    return override(path)
  end
  if type(override) == 'string' then
    return override
  end

  local local_bin = path_join(project.workspace_root, 'node_modules', '.bin', bin)
  if vitest_util.path.exists(local_bin) then
    return local_bin
  end

  local package_json = read_json(path_join(project.workspace_root, 'package.json')) or {}
  if type(package_json.packageManager) == 'string' and package_json.packageManager:match '^bun' then
    return { 'bun', bin }
  end

  return { 'npx', bin }
end

adapter.root = function(dir)
  return workspace_root(dir)
end

function adapter.filter_dir(name, rel_path, root)
  return options.filter_dir(name, rel_path, root)
end

function adapter.is_test_file(file_path)
  if file_path == nil or not is_spec_file(file_path) then
    return false
  end

  return get_project_for_path(file_path) ~= nil
end

function adapter.discover_positions(file_path)
  return lib.treesitter.parse_positions(file_path, test_query, { nested_tests = true })
end

function adapter.build_spec(args)
  local tree = args.tree
  if not tree then
    return nil
  end

  local pos = tree:data()
  local project = get_project_for_path(pos.path)
  if not project then
    return nil
  end

  local include_path = pos.path
  if pos.type == 'test' then
    local file_node = tree
    while file_node and file_node:data().type ~= 'file' do
      file_node = file_node:parent()
    end
    if not file_node then
      return nil
    end
    include_path = file_node:data().path
  end

  -- `--include` is documented as relative to the project root, which holds
  -- for `ng`; when the builder runs under `nx` it resolves against the
  -- workspace root instead.
  local include_root = project.kind == 'nx' and project.workspace_root or project.project_root
  local relative_include = relative_to(include_root, include_path)
  local results_path = async.fn.tempname() .. '.json'
  local command = resolve_command(project, pos.path)
  if type(command) == 'string' then
    command = vim.split(command, '%s+')
  end

  command = vim.deepcopy(command)
  vim.list_extend(command, {
    'test',
    project.name,
    '--watch=false',
    -- `--output-file` applies to the first reporter only; the default
    -- reporter keeps readable failures in the process output that neotest
    -- shows in its output panel.
    '--reporters=json',
    '--reporters=default',
    '--output-file=' .. results_path,
    '--include=' .. relative_include,
  })

  local pattern = get_name_pattern(tree)
  if pattern then
    table.insert(command, '--filter=' .. pattern)
  end

  if project.kind == 'nx' then
    -- The results file is not a declared nx output, so a cache hit would
    -- replay the run without writing it.
    table.insert(command, '--skip-nx-cache')
  end

  vim.list_extend(command, args.extra_args or {})

  local env = { NX_TUI = 'false' }
  local strategy
  if args.strategy == 'dap' then
    -- The builder's --debug runs vitest in a single, non-isolated fork with
    -- the inspector; js-debug attaches to it through child-process
    -- auto-attach when nx itself is launched under the debugger.
    table.insert(command, '--debug')
    -- Keep the nx daemon and plugin worker processes out of the debugged
    -- process tree; js-debug would attach a session to each of them.
    env.NX_DAEMON = 'false'
    env.NX_ISOLATE_PLUGINS = 'false'
    strategy = {
      name = 'Debug ' .. project.name .. ' tests',
      type = 'pwa-node',
      request = 'launch',
      cwd = project.workspace_root,
      runtimeExecutable = command[1],
      args = { unpack(command, 2) },
      console = 'integratedTerminal',
      internalConsoleOptions = 'neverOpen',
      autoAttachChildProcesses = true,
      sourceMaps = true,
      resolveSourceMapLocations = { project.workspace_root .. '/**', '!**/node_modules/**' },
      skipFiles = { '<node_internals>/**', '**/node_modules/**' },
    }
  end

  return {
    command = command,
    cwd = project.workspace_root,
    -- neotest runs in a pty; nx would otherwise show its interactive TUI and
    -- linger on its exit countdown.
    env = env,
    strategy = strategy,
    context = {
      results_path = results_path,
      file = include_path,
    },
  }
end

function adapter.results(spec, result, tree)
  local success, data = pcall(lib.files.read, spec.context.results_path)
  if not success then
    logger.error('No Angular test output file found ', spec.context.results_path)
    return {}
  end

  local ok, parsed = pcall(vim.json.decode, data, { luanil = { object = true } })
  if not ok then
    logger.error('Failed to parse Angular test output json ', spec.context.results_path)
    return {}
  end

  return vitest_util.parsed_json_to_results(parsed, spec.context.results_path, result.output)
end

return function(opts)
  if opts then
    options = vim.tbl_deep_extend('force', options, opts)
  end

  return adapter
end
