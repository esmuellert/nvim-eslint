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

function M.collect(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local timeout = opts.timeout or 10000

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
    vim.api.nvim_err_writeln("eslint LSP did not attach within timeout")
    return false
  end

  wait_for(function()
    local diags = vim.diagnostic.get(bufnr)
    return #diags > 0
  end, timeout, 100)

  local diagnostics = vim.diagnostic.get(bufnr)
  if #diagnostics == 0 then
    vim.api.nvim_err_writeln("No diagnostics collected")
  else
    local eslint_like = to_eslint_json(bufnr, diagnostics)
    vim.api.nvim_out_write(vim.fn.json_encode(eslint_like) .. "\n")
  end

  return true
end

return M
