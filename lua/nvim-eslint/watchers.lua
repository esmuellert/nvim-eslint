local fs = require('nvim-eslint.fs')

local uv = vim.uv or vim.loop

local watched_directories = {}
local clients_by_watch = {}

local M = {}

local function ensure_directory_watcher(dir)
  dir = fs.normalize(dir)
  if not dir then
    return nil, 'missing directory'
  end

  local entry = watched_directories[dir]
  if entry then
    return entry
  end

  local handle = uv.new_fs_event()
  if not handle then
    return nil, 'failed to create fs event handle'
  end

  local ok, err = handle:start(dir, {}, function(err0, filename)
    if err0 then
      return
    end

    if not filename or filename == '' then
      return
    end

    vim.schedule(function()
      local current = watched_directories[dir]
      if not current then
        return
      end

      local interested = current.files[filename]
      if not interested then
        return
      end

      for client_id, callback in pairs(interested) do
        local client = vim.lsp.get_client_by_id(client_id)
        if client then
          local full_path = fs.joinpath(dir, filename)
          if full_path and type(callback) == 'function' then
            callback(client, full_path)
          end
        else
          interested[client_id] = nil
        end
      end
    end)
  end)

  if not ok then
    handle:stop()
    handle:close()
    return nil, err or 'failed to start fs watcher'
  end

  entry = {
    handle = handle,
    files = {},
  }
  watched_directories[dir] = entry
  return entry
end

local function track_client_watch(client_id, dir, filename)
  local by_client = clients_by_watch[client_id]
  if not by_client then
    by_client = {}
    clients_by_watch[client_id] = by_client
  end

  local files = by_client[dir]
  if not files then
    files = {}
    by_client[dir] = files
  end

  if files[filename] then
    return false
  end

  files[filename] = true
  return true
end

function M.register(client, path, on_change)
  local dir, filename = fs.split(path)
  if not dir or filename == '' then
    return
  end

  local entry, err = ensure_directory_watcher(dir)
  if not entry then
    vim.notify(
      ('ESLint: unable to watch %s (%s)'):format(path, err or 'unknown error'),
      vim.log.levels.WARN
    )
    return
  end

  local clients = entry.files[filename]
  if not clients then
    clients = {}
    entry.files[filename] = clients
  end

  clients[client.id] = on_change
  track_client_watch(client.id, dir, filename)
end

function M.ensure(client, paths, on_change)
  for _, path in ipairs(paths) do
    M.register(client, path, on_change)
  end
end

function M.unregister(client_id)
  local registrations = clients_by_watch[client_id]
  if not registrations then
    return
  end

  for dir, files in pairs(registrations) do
    local entry = watched_directories[dir]
    if entry then
      for filename in pairs(files) do
        local watchers = entry.files[filename]
        if watchers then
          watchers[client_id] = nil
          if vim.tbl_isempty(watchers) then
            entry.files[filename] = nil
          end
        end
      end

      if vim.tbl_isempty(entry.files) then
        entry.handle:stop()
        entry.handle:close()
        watched_directories[dir] = nil
      end
    end
  end

  clients_by_watch[client_id] = nil
end

return M
