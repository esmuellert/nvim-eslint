local fs = require('nvim-eslint.fs')
local settings = require('nvim-eslint.settings')
local watchers = require('nvim-eslint.watchers')

local M = {}

local user_config = {}
local pending_restarts = {}
local start_client_for_buffer

M.user_config = user_config

local function err_message(...)
  vim.notify(table.concat(vim.iter({ ... }):flatten():totable()), vim.log.levels.ERROR)
  vim.api.nvim_command('redraw')
end

local function schedule_client_restart(client)
  if pending_restarts[client.id] then
    return
  end

  local bufnrs = {}
  for bufnr in pairs(client.attached_buffers or {}) do
    bufnrs[#bufnrs + 1] = bufnr
  end

  pending_restarts[client.id] = true

  client:stop(true)

  vim.defer_fn(function()
    pending_restarts[client.id] = nil
    for _, bufnr in ipairs(bufnrs) do
      if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == '' then
        start_client_for_buffer(bufnr)
      end
    end
  end, 100)
end

local function handle_config_change(client, path)
  if not fs.normalize(path) then
    return
  end

  schedule_client_restart(client)
end

M.handle_config_change = handle_config_change

local function ensure_watches(client, bufnr)
  if client.name ~= 'eslint' then
    return
  end

  watchers.ensure(client, settings.gather_watch_paths(bufnr), handle_config_change)
end

local function configuration_handler(_, result, ctx)
  local function lookup_section(tbl, section)
    local keys = vim.split(section, '.', { plain = true }) ---@type string[]
    return vim.tbl_get(tbl, unpack(keys))
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

  local bufnr = vim.uri_to_bufnr(result.items[1].scopeUri)
  local new_settings = M.make_settings(bufnr)
  client.settings = new_settings

  local response = {}
  for _, item in ipairs(result.items) do
    if item.section then
      local value = lookup_section(client.settings, item.section)
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

start_client_for_buffer = function(bufnr)
  local user_on_attach = user_config.on_attach
  local user_on_exit = user_config.on_exit

  local root_dir = user_config.root_dir and user_config.root_dir(bufnr) or settings.resolve_git_dir(bufnr)
  if not root_dir then
    root_dir = settings.resolve_package_json_dir(bufnr)
  end
  if not root_dir then
    root_dir = settings.resolve_eslint_config_dir(bufnr)
  end
  if not root_dir then
    root_dir = vim.fn.getcwd()
  end

  vim.lsp.start({
    name = 'eslint',
    cmd = user_config.cmd or settings.create_cmd(user_config),
    root_dir = root_dir,
    settings = M.make_settings(bufnr),
    capabilities = user_config.capabilities or M.make_client_capabilities(),
    on_attach = function(client, buffer)
      ensure_watches(client, buffer)
      if user_on_attach then
        pcall(user_on_attach, client, buffer)
      end
    end,
    on_exit = function(code, signal, client_id)
      watchers.unregister(client_id)
      if user_on_exit then
        pcall(user_on_exit, code, signal, client_id)
      end
    end,
    handlers = vim.tbl_deep_extend('keep', user_config.handlers or {}, {
      ["workspace/configuration"] = configuration_handler,
      -- Handle server-to-client requests that require a response to prevent
      -- MethodNotFound errors triggering infinite retry loops.
      ["eslint/noLibrary"] = function() return {} end,
      ["eslint/noConfig"] = function() return {} end,
      ["eslint/openDoc"] = function() return {} end,
      ["eslint/probeFailed"] = function() return {} end,
    }),
  })
end

M.start_client_for_buffer = start_client_for_buffer

function M.make_settings(bufnr)
  return settings.make_settings(bufnr, user_config)
end

function M.make_client_capabilities()
  return settings.make_client_capabilities()
end

function M.create_cmd()
  if user_config.cmd then
    return user_config.cmd
  end
  return settings.create_cmd(user_config)
end

function M.resolve_git_dir(bufnr)
  return settings.resolve_git_dir(bufnr)
end

function M.resolve_package_json_dir(bufnr)
  return settings.resolve_package_json_dir(bufnr)
end

function M.resolve_eslint_config_dir(bufnr)
  return settings.resolve_eslint_config_dir(bufnr)
end

function M.use_flat_config(bufnr)
  return settings.use_flat_config(bufnr)
end

function M.resolve_node_path()
  return settings.resolve_node_path()
end

function M.setup_lsp_start()
  vim.api.nvim_create_autocmd('FileType', {
    pattern = vim.tbl_extend(
      'force',
      {
        'javascript',
        'javascriptreact',
        'javascript.jsx',
        'typescript',
        'typescriptreact',
        'typescript.tsx',
        'vue',
        'svelte',
        'astro',
      },
      user_config.filetypes or {}
    ),
    callback = function(args)
      start_client_for_buffer(args.buf)
    end,
  })
end

function M.setup(config)
  if config then
    user_config = config
  else
    user_config = {}
  end
  M.user_config = user_config
  M.setup_lsp_start()
end

return M
