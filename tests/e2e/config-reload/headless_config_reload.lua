local M = {}

local function wait_for(predicate, timeout_ms, interval_ms)
  local waited = 0
  interval_ms = interval_ms or 100

  while waited < timeout_ms do
    if predicate() then
      return true
    end

    vim.wait(interval_ms)
    waited = waited + interval_ms
  end

  return predicate()
end

local function to_eslint_json(bufnr, diagnostics)
  local severity_map = {
    [vim.diagnostic.severity.ERROR] = 2,
    [vim.diagnostic.severity.WARN] = 1,
    [vim.diagnostic.severity.INFO] = 1,
    [vim.diagnostic.severity.HINT] = 1,
  }

  local result = {
    filePath = vim.api.nvim_buf_get_name(bufnr),
    messages = {},
    suppressedMessages = {},
    errorCount = 0,
    fatalErrorCount = 0,
    warningCount = 0,
    fixableErrorCount = 0,
    fixableWarningCount = 0,
    usedDeprecatedRules = {},
  }

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  result.source = table.concat(lines, "\n")

  local function get_rule_id(diagnostic)
    if diagnostic.code and diagnostic.code ~= "" then
      return diagnostic.code
    end

    local lsp_data = diagnostic.user_data and diagnostic.user_data.lsp
    if lsp_data and lsp_data.code and lsp_data.code ~= "" then
      return lsp_data.code
    end

    return vim.NIL
  end

  local function to_message(diagnostic)
    local severity = severity_map[diagnostic.severity] or 1
    local message = {
      ruleId = get_rule_id(diagnostic),
      severity = severity,
      message = diagnostic.message or "",
      line = (diagnostic.lnum or 0) + 1,
      column = (diagnostic.col or 0) + 1,
      endLine = diagnostic.end_lnum and (diagnostic.end_lnum + 1) or vim.NIL,
      endColumn = diagnostic.end_col and (diagnostic.end_col + 1) or vim.NIL,
      nodeType = vim.NIL,
      messageId = vim.NIL,
      fix = vim.NIL,
      fatal = vim.NIL,
      suggestions = vim.NIL,
    }

    local lsp_data = diagnostic.user_data and diagnostic.user_data.lsp
    if lsp_data then
      if message.ruleId == vim.NIL and lsp_data.code and lsp_data.code ~= "" then
        message.ruleId = lsp_data.code
      end

      if lsp_data.message and lsp_data.message ~= "" then
        message.message = lsp_data.message
      end

      if lsp_data.severity then
        severity = severity_map[lsp_data.severity] or severity
        message.severity = severity
      end

      if lsp_data.data then
        message.nodeType = lsp_data.data.nodeType or message.nodeType
        message.messageId = lsp_data.data.messageId or message.messageId
        message.suggestions = lsp_data.data.suggestions or message.suggestions
      end
    end

    if severity == 2 then
      result.errorCount = result.errorCount + 1
    else
      result.warningCount = result.warningCount + 1
    end

    return message
  end

  for _, diagnostic in ipairs(diagnostics) do
    table.insert(result.messages, to_message(diagnostic))
  end

  return { result }
end

local function read_file(path)
  local fd, err = io.open(path, "r")
  if not fd then
    return nil, err
  end
  local content = fd:read("*a")
  fd:close()
  return content
end

local function write_file(path, content)
  local fd, err = io.open(path, "w")
  if not fd then
    return false, err
  end
  fd:write(content)
  fd:close()
  return true
end

local function ensure_parent(path)
  local dir = vim.fn.fnamemodify(path, ':p:h')
  if dir and dir ~= '' then
    vim.fn.mkdir(dir, 'p')
  end
end

local function unlink(path)
  if not path or path == '' then
    return
  end
  pcall(os.remove, path)
end

local function collect_once(bufnr)
  local diagnostics = vim.diagnostic.get(bufnr)
  return to_eslint_json(bufnr, diagnostics)
end

local DEFAULT_STRICT_CONFIG = [[
module.exports = {
  extends: ["@turbo/eslint-config/library"],
  rules: {
    "no-console": "error",
  },
};
]]

local DEFAULT_RELAXED_CONFIG = [[
module.exports = {
  extends: ["@turbo/eslint-config/library"],
  rules: {
    "no-console": "off",
  },
};
]]

local DEFAULT_TARGET_SOURCE = [[
export function reloadTarget(): void {
  console.log('headless reload smoke');
}
]]

function M.run(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local timeout = opts.timeout or 20000
  local expected_after = opts.expected_after or 0
  local expected_before = opts.expected_before or 1
  local fixture_root = opts.fixture_root or vim.env.NVIM_ESLINT_FIXTURE
  if not fixture_root then
    return false, "fixture_root is required; set opts.fixture_root or NVIM_ESLINT_FIXTURE"
  end

  fixture_root = vim.fs.normalize(fixture_root)
  local config_path = vim.fs.normalize(opts.config_path or vim.fs.joinpath(fixture_root, 'packages/create-turbo/.eslintrc.js'))
  local target_path = vim.fs.normalize(opts.target_path or vim.fs.joinpath(fixture_root,
    'packages/create-turbo/src/__eslint_reload_target__.ts'))
  local strict_config = opts.strict_config or DEFAULT_STRICT_CONFIG
  local relaxed_config = opts.relaxed_config or DEFAULT_RELAXED_CONFIG
  local target_source = opts.target_source or DEFAULT_TARGET_SOURCE

  ensure_parent(config_path)
  ensure_parent(target_path)

  local original_config = read_file(config_path)
  local original_target = read_file(target_path)
  local had_config = original_config ~= nil
  local had_target = original_target ~= nil

  local function restore()
    if had_config then
      write_file(config_path, original_config)
    else
      unlink(config_path)
    end

    if had_target then
      write_file(target_path, original_target)
    else
      unlink(target_path)
    end
  end

  local function run_inner()
    local ok, err = write_file(config_path, strict_config)
    if not ok then
      return false, "Failed to seed strict config: " .. (err or "unknown error")
    end

    ok, err = write_file(target_path, target_source)
    if not ok then
      return false, "Failed to seed target file: " .. (err or "unknown error")
    end

    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd('edit!')
    end)

    local attached = wait_for(function()
      local clients = vim.lsp.get_clients({ bufnr = bufnr })
      for _, client in ipairs(clients) do
        if client.name == "eslint" then
          return true
        end
      end
      return false
    end, timeout, 100)

    if not attached then
      return false, "eslint LSP did not attach within timeout"
    end

    local has_before = wait_for(function()
      local diags = vim.diagnostic.get(bufnr)
      return #diags >= expected_before
    end, timeout, 100)

    if not has_before then
      return false, "eslint diagnostics did not reach expected_before within timeout"
    end

    local initial = collect_once(bufnr)
    vim.api.nvim_out_write(vim.fn.json_encode({ phase = "before", diagnostics = initial }) .. "\n")

    ok, err = write_file(config_path, relaxed_config)
    if not ok then
      return false, "Failed to apply relaxed config: " .. (err or "unknown error")
    end

    local cleared = wait_for(function()
      local diags = vim.diagnostic.get(bufnr)
      return #diags == expected_after
    end, timeout, 200)

    if not cleared then
      return false, "eslint diagnostics did not match expected_after after config swap"
    end

    local final = collect_once(bufnr)
    vim.api.nvim_out_write(vim.fn.json_encode({ phase = "after", diagnostics = final }) .. "\n")

    return true
  end

  local ok, err = run_inner()
  restore()

  if not ok then
    if err then
      vim.api.nvim_err_writeln(err)
    end
    return false
  end

  return true
end

return M
