local M = {}

function M.normalize(path)
  if not path or path == '' then
    return nil
  end
  return vim.fs.normalize(path)
end

function M.joinpath(dir, filename)
  if not dir then
    return nil
  end
  return M.normalize(vim.fs.joinpath(dir, filename))
end

function M.split(path)
  local dir = M.normalize(vim.fn.fnamemodify(path, ':p:h'))
  local name = vim.fn.fnamemodify(path, ':t')
  return dir, name
end

function M.collect_existing_paths(dir, filenames)
  local paths = {}
  if not dir then
    return paths
  end

  for _, name in ipairs(filenames) do
    local candidate = M.joinpath(dir, name)
    if candidate and vim.fn.filereadable(candidate) == 1 then
      table.insert(paths, candidate)
    end
  end

  return paths
end

return M
