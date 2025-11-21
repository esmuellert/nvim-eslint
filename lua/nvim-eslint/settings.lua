local constants = require('nvim-eslint.constants')
local fs = require('nvim-eslint.fs')

local M = {}

function M.get_plugin_root()
  local str = debug.getinfo(1, 'S').source:sub(2)
  return vim.fn.fnamemodify(str, ':p:h:h:h')
end

function M.resolve_git_dir(bufnr)
  local markers = { '.git' }
  local git_dir = vim.fs.root(bufnr, markers)
  return fs.normalize(git_dir)
end

function M.resolve_package_json_dir(bufnr)
  local markers = { 'package.json' }
  local package_json_dir = vim.fs.root(bufnr, markers)
  return fs.normalize(package_json_dir)
end

function M.resolve_eslint_config_dir(bufnr)
  local eslint_config_dir = vim.fs.root(bufnr, constants.WATCHED_CONFIG_FILENAMES)
  return fs.normalize(eslint_config_dir)
end

function M.use_flat_config(bufnr)
  local config_dir = vim.fs.root(bufnr, constants.FLAT_CONFIG_FILENAMES)
  if not config_dir then
    return false
  end

  for _, name in ipairs(constants.FLAT_CONFIG_FILENAMES) do
    local candidate = fs.joinpath(config_dir, name)
    if candidate and vim.fn.filereadable(candidate) == 1 then
      return true
    end
  end

  return false
end

function M.resolve_node_path()
  local result = vim.fn.exepath('node')

  if result == '' then
    print('Error: Could not find Node.js path. ESLint server will use default path.')
    return nil
  end

  return result
end

local function default_settings()
  return {
    validate = 'on',
    useESLintClass = true,
    useFlatConfig = function(bufnr)
      return M.use_flat_config(bufnr)
    end,
    experimental = {
      useFlatConfig = false,
    },
    codeAction = {
      disableRuleComment = {
        enable = true,
        location = 'separateLine',
      },
      showDocumentation = {
        enable = true,
      },
    },
    codeActionOnSave = {
      mode = 'all',
    },
    format = false,
    quiet = false,
    onIgnoredFiles = 'off',
    options = {},
    rulesCustomizations = {},
    run = 'onType',
    problems = {
      shortenToSingleLine = false,
    },
    nodePath = function()
      return M.resolve_node_path()
    end,
    workingDirectory = { mode = 'location' },
    workspaceFolder = function(bufnr)
      local git_dir = M.resolve_git_dir(bufnr)
      local package_json_dir = M.resolve_package_json_dir(bufnr)
      local eslint_config_dir = M.resolve_eslint_config_dir(bufnr)
      local workspace_dir = git_dir or package_json_dir or eslint_config_dir

      if not workspace_dir then
        vim.notify(
          'ESLint: Could not find git, package.json, or eslint config directory. Using current directory as fallback.',
          vim.log.levels.WARN
        )
        workspace_dir = vim.fn.getcwd()
      end

      return {
        uri = vim.uri_from_fname(workspace_dir),
        name = vim.fn.fnamemodify(workspace_dir, ':t'),
      }
    end,
  }
end

function M.make_settings(buffer, user_config)
  local config = user_config or {}
  local settings_with_function = vim.tbl_deep_extend('keep', config.settings or {}, default_settings())

  local flattened_settings = {}
  for k, v in pairs(settings_with_function) do
    if type(v) == 'function' then
      flattened_settings[k] = v(buffer)
    else
      flattened_settings[k] = v
    end
  end
  return flattened_settings
end

function M.make_client_capabilities()
  local default_capabilities = vim.lsp.protocol.make_client_capabilities()
  default_capabilities.workspace.didChangeConfiguration.dynamicRegistration = true
  default_capabilities.workspace.didChangeWatchedFiles = default_capabilities.workspace.didChangeWatchedFiles or {}
  default_capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = true
  return default_capabilities
end

function M.create_cmd(user_config)
  local debug_mode = false
  if user_config and user_config.debug then
    debug_mode = true
  end

  if debug_mode then
    return {
      'node',
      '--inspect-brk',
      M.get_plugin_root() .. '/vscode-eslint/server/out/eslintServer.js',
      '--stdio',
    }
  end

  return { 'node', M.get_plugin_root() .. '/vscode-eslint/server/out/eslintServer.js', '--stdio' }
end

function M.gather_watch_paths(bufnr)
  local seen = {}
  local paths = {}

  local config_dir = M.resolve_eslint_config_dir(bufnr)
  for _, path in ipairs(fs.collect_existing_paths(config_dir, constants.WATCHED_CONFIG_FILENAMES)) do
    if not seen[path] then
      table.insert(paths, path)
      seen[path] = true
    end
  end

  local package_dir = M.resolve_package_json_dir(bufnr)
  if package_dir then
    local package_json = fs.joinpath(package_dir, 'package.json')
    if package_json and vim.fn.filereadable(package_json) == 1 and not seen[package_json] then
      table.insert(paths, package_json)
      seen[package_json] = true
    end
  end

  return paths
end

return M
