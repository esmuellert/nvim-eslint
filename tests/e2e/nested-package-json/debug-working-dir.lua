-- Debug script to capture the actual workingDirectory used by ESLint LSP
-- Following the debugging instructions from README.md

-- Set up the plugin path
vim.opt.runtimepath:prepend('/home/runner/work/nvim-eslint/nvim-eslint')

-- Enable debug level logs as per README.md instructions
vim.lsp.set_log_level('debug')

-- Setup the plugin with default configuration
require('nvim-eslint').setup({})

-- Function to capture and log LSP configuration
local function capture_lsp_config()
  vim.defer_fn(function()
    local bufnr = vim.api.nvim_get_current_buf()
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    
    print("=== Debug Information for Buffer ===")
    print("Buffer: " .. bufname)
    print("Buffer number: " .. bufnr)
    print("CWD: " .. vim.fn.getcwd())
    print("")
    
    -- Get all LSP clients for this buffer
    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    
    if #clients == 0 then
      print("ERROR: No LSP clients attached to buffer!")
    else
      for _, client in ipairs(clients) do
        print("=== LSP Client: " .. client.name .. " ===")
        print("Client ID: " .. client.id)
        print("Root Dir: " .. tostring(client.root_dir or "nil"))
        print("")
        
        if client.config and client.config.settings then
          print("=== Settings Sent to LSP ===")
          print("workingDirectory: " .. vim.inspect(client.config.settings.workingDirectory))
          print("workspaceFolder: " .. vim.inspect(client.config.settings.workspaceFolder))
          print("useFlatConfig: " .. vim.inspect(client.config.settings.useFlatConfig))
          print("nodePath: " .. vim.inspect(client.config.settings.nodePath))
          print("")
        end
      end
    end
    
    -- Get diagnostics
    local diagnostics = vim.diagnostic.get(bufnr)
    print("=== Diagnostics ===")
    print("Count: " .. #diagnostics)
    if #diagnostics > 0 then
      for i, diag in ipairs(diagnostics) do
        print(string.format("%d. [%s] %s", i, diag.source or "unknown", diag.message))
      end
    else
      print("No diagnostics found!")
    end
    print("")
    
    print("=== Check LSP Log ===")
    print("LSP log location: " .. vim.lsp.get_log_path())
    print("Check the log file for detailed request/response including the actual workingDirectory")
    print("Look for 'workspace/configuration' request and response")
    print("")
    
    -- Write results to file
    local results = {
      bufname = bufname,
      bufnr = bufnr,
      cwd = vim.fn.getcwd(),
      clients = {},
      diagnostics = diagnostics,
      lsp_log_path = vim.lsp.get_log_path()
    }
    
    for _, client in ipairs(clients) do
      table.insert(results.clients, {
        name = client.name,
        id = client.id,
        root_dir = client.root_dir,
        settings = client.config and client.config.settings or {}
      })
    end
    
    local file = io.open('/tmp/debug-working-dir-results.txt', 'w')
    if file then
      file:write(vim.inspect(results))
      file:close()
      print("Results written to: /tmp/debug-working-dir-results.txt")
    end
    
    -- Exit after 2 more seconds to let LSP settle
    vim.defer_fn(function()
      vim.cmd('qall!')
    end, 2000)
  end, 3000) -- Wait 3 seconds for LSP to fully attach
end

-- Auto-run capture when buffer is ready
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == 'eslint' then
      print("ESLint LSP attached to buffer " .. args.buf)
      capture_lsp_config()
    end
  end,
})
