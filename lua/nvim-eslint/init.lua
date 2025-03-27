local M = {}

--- Writes to error buffer.
---@param ... string Will be concatenated before being written
local function err_message(...)
  vim.notify(table.concat(vim.iter({ ... }):flatten():totable()), vim.log.levels.ERROR)
  vim.api.nvim_command('redraw')
end

function M.get_plugin_root()
    local str = debug.getinfo(1, "S").source:sub(2)
    return vim.fn.fnamemodify(str, ":p:h:h:h")
end

function M.resolve_git_dir(bufnr)
  local markers = { '.git' }
  local git_dir = vim.fs.root(bufnr, markers);
  return git_dir
end

function M.resolve_package_json_dir(bufnr)
  local markers = { 'package.json' }
  local package_json_dir = vim.fs.root(bufnr, markers);
  return package_json_dir
end

function M.resolve_eslint_config_dir(bufnr)
  local markers = { 'eslint.config.js', 'eslint.config.mjs', 'eslint.config.cjs', 'eslint.config.ts', 'eslint.config.mts', 'eslint.config.cts' }
  local eslint_config_dir = vim.fs.root(bufnr, markers);
  return eslint_config_dir
end

function M.make_settings(buffer)
  local settings_with_function = vim.tbl_deep_extend('keep', M.user_config.settings or {}, {
    validate = 'on',
    -- packageManager = 'pnpm',
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
    nodePath = function(bufnr)
      return M.resolve_node_path()
    end,
    workingDirectory = { mode = 'location' },
    workspaceFolder = function(bufnr)
      local git_dir = M.resolve_git_dir(bufnr)
      local package_json_dir = M.resolve_package_json_dir(bufnr)
      local eslint_config_dir = M.resolve_eslint_config_dir(bufnr)
      local workspace_dir = git_dir or package_json_dir or eslint_config_dir
      
      if not workspace_dir then
        vim.notify("ESLint: Could not find git, package.json, or eslint config directory. Using current directory as fallback.", vim.log.levels.WARN)
        workspace_dir = vim.fn.getcwd()
      end
      
      return {
        uri = vim.uri_from_fname(workspace_dir),
        name = vim.fn.fnamemodify(workspace_dir, ':t'),
      }
    end,

  })

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
  return default_capabilities
end

function M.use_flat_config(bufnr)
  local root_dir = M.resolve_package_json_dir(bufnr)
  if
      vim.fn.filereadable(root_dir .. '/eslint.config.js') == 1
      or vim.fn.filereadable(root_dir .. '/eslint.config.mjs') == 1
      or vim.fn.filereadable(root_dir .. '/eslint.config.cjs') == 1
      or vim.fn.filereadable(root_dir .. '/eslint.config.ts') == 1
      or vim.fn.filereadable(root_dir .. '/eslint.config.mts') == 1
      or vim.fn.filereadable(root_dir .. '/eslint.config.cts') == 1
  then
    return true
  end
  return false
end

function M.resolve_node_path()
  local is_windows = vim.loop.os_uname().sysname == "Windows_NT"
  local command = is_windows and 'where.exe node' or 'which node'

  -- Run the appropriate command to get the Node.js path
  local result = vim.fn.system(command)

  -- Trim trailing newline character(s)
  result = result:gsub("\r\n$", ""):gsub("\n$", "")

  -- Handle errors if the command fails
  if vim.v.shell_error ~= 0 then
    print("Error: Could not find Node.js path. ESlint server will use default path.")
    return nil
  end

  return result
end

function M.create_cmd()
  local debug = false
  if M.user_config and M.user_config.debug then
    debug = true
  end
  if debug then
    return { 'node', '--inspect-brk', M.get_plugin_root() ..
    '/vscode-eslint/server/out/eslintServer.js', '--stdio' }
  end
  return { 'node', M.get_plugin_root() .. '/vscode-eslint/server/out/eslintServer.js', '--stdio' }
end

function M.setup_lsp_start()
  vim.api.nvim_create_autocmd('FileType', {
    pattern = vim.tbl_extend('force',
      { 'javascript', 'javascriptreact', 'javascript.jsx', 'typescript', 'typescriptreact', 'typescript.tsx', 'vue',
        'svelte', 'astro', }, M.user_config.filetypes or {}),
    callback = function(args)
      vim.lsp.start({
        name = 'eslint',
        cmd = M.user_config.cmd or M.create_cmd(),
        root_dir = M.user_config.root_dir and M.user_config.root_dir(args.buf) or M.resolve_git_dir(args.buf),
        settings = M.make_settings(args.buf),
        capabilities = M.user_config.capabilities or M.make_client_capabilities(),
        on_attach = M.user_config.on_attach,
        handlers = vim.tbl_deep_extend('keep', M.user_config.handlers or {}, {
          ["workspace/configuration"] = function(_, result, ctx)
            local function lookup_section(table, section)
              local keys = vim.split(section, '.', { plain = true }) --- @type string[]
              return vim.tbl_get(table, unpack(keys))
            end

            local client_id = ctx.client_id
            local client = vim.lsp.get_client_by_id(client_id)
            if not client then
              err_message(
                'LSP[',
                client_id,
                '] client has shut down after sending a workspace/configuration request'
              )
              return
            end
            if not result.items then
              return {}
            end

            --- Insert custom logic to update client settings
            local bufnr = vim.uri_to_bufnr(result.items[1].scopeUri)
            local new_settings = M.make_settings(bufnr)
            client.settings = new_settings
            --- end custom logic

            local response = {}
            for _, item in ipairs(result.items) do
              if item.section then
                local value = lookup_section(client.settings, item.section)
                -- For empty sections with no explicit '' key, return settings as is
                if value == nil and item.section == '' then
                  value = client.settings
                end
                if value == nil then
                  value = vim.NIL
                end
                table.insert(response, value)
              end
            end
            return response
          end
        })
      })
    end
  })
end

function M.setup(user_config)
  if user_config then
    M.user_config = user_config
  end
  M.setup_lsp_start()
end

return M
