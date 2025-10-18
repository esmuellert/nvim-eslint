-- Test script to verify if diagnostics appear with .git present
-- This tests the actual user's scenario now that .git is properly initialized

-- Add the plugin to runtimepath
vim.opt.runtimepath:prepend('/home/runner/work/nvim-eslint/nvim-eslint')

-- Minimal Neovim LSP setup
require('nvim-eslint').setup({
  -- Use default settings
})

-- Track results
local results = {
  root_dir = nil,
  workspace_folder = nil,
  diagnostics_count = 0,
  diagnostics = {},
  lsp_attached = false,
  timeout = false
}

-- Open the problematic file
local test_file = vim.fn.getcwd() .. '/sub-dir/some-other-dir/file-to-lint.ts'
vim.cmd('edit ' .. test_file)

-- Get the buffer number
local bufnr = vim.api.nvim_get_current_buf()

-- Wait for LSP to attach
local max_wait = 10000 -- 10 seconds
local start_time = vim.loop.now()

local function check_lsp()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  
  if #clients > 0 then
    results.lsp_attached = true
    local client = clients[1]
    
    -- Capture root_dir and workspace folder
    results.root_dir = client.config.root_dir
    if client.config.workspace_folders and #client.config.workspace_folders > 0 then
      results.workspace_folder = client.config.workspace_folders[1]
    end
    
    -- Wait a bit more for diagnostics to be published
    vim.defer_fn(function()
      local diagnostics = vim.diagnostic.get(bufnr)
      results.diagnostics_count = #diagnostics
      results.diagnostics = diagnostics
      
      -- Write results
      write_results()
    end, 3000)
    
    return true
  end
  
  -- Check timeout
  if vim.loop.now() - start_time > max_wait then
    results.timeout = true
    write_results()
    return true
  end
  
  return false
end

function write_results()
  local output_file = '/tmp/test-diagnostics-results.txt'
  local f = io.open(output_file, 'w')
  
  if f then
    f:write('=== nvim-eslint Diagnostics Test Results ===\n')
    f:write('Test file: ' .. test_file .. '\n')
    f:write('Current working directory: ' .. vim.fn.getcwd() .. '\n')
    f:write('\n')
    
    if results.timeout then
      f:write('❌ TIMEOUT: LSP did not attach within ' .. (max_wait/1000) .. ' seconds\n')
    elseif not results.lsp_attached then
      f:write('❌ FAILED: LSP client did not attach\n')
    else
      f:write('✓ LSP client attached successfully\n')
      f:write('\n')
      f:write('Root directory: ' .. tostring(results.root_dir) .. '\n')
      
      if results.workspace_folder then
        f:write('Workspace folder:\n')
        f:write('  name: ' .. tostring(results.workspace_folder.name) .. '\n')
        f:write('  uri: ' .. tostring(results.workspace_folder.uri) .. '\n')
      end
      
      f:write('\n')
      f:write('Diagnostics count: ' .. results.diagnostics_count .. '\n')
      
      if results.diagnostics_count > 0 then
        f:write('\n✓ SUCCESS: Diagnostics are appearing!\n')
        f:write('\nDiagnostics details:\n')
        for i, diag in ipairs(results.diagnostics) do
          f:write(string.format('  %d. [%s] %s (line %d)\n', 
            i, diag.severity, diag.message, diag.lnum + 1))
        end
      else
        f:write('\n❌ FAILED: No diagnostics received\n')
        f:write('This indicates the issue still exists even with .git present\n')
      end
    end
    
    f:write('\n')
    f:write('=== Test Complete ===\n')
    f:close()
    
    print('Results written to: ' .. output_file)
  end
  
  -- Quit Neovim
  vim.cmd('qall!')
end

-- Start checking for LSP attachment
local timer = vim.loop.new_timer()
timer:start(500, 500, vim.schedule_wrap(function()
  if check_lsp() then
    timer:stop()
    timer:close()
  end
end))
