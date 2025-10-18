-- Simple test to check if diagnostics appear
vim.opt.runtimepath:prepend('/home/runner/work/nvim-eslint/nvim-eslint')

-- Enable debug logging
vim.lsp.set_log_level('debug')

print('=== Starting nvim-eslint test ===')
print('CWD: ' .. vim.fn.getcwd())

-- Setup the plugin
require('nvim-eslint').setup({})

print('Plugin setup complete')

-- Open the test file
local test_file = 'sub-dir/some-other-dir/file-to-lint.ts'
print('Opening file: ' .. test_file)
vim.cmd('edit ' .. test_file)

local bufnr = vim.api.nvim_get_current_buf()
print('Buffer: ' .. bufnr)

-- Ensure filetype is set
vim.bo[bufnr].filetype = 'typescript'
print('Filetype set to: ' .. vim.bo[bufnr].filetype)

-- Wait and check for LSP
vim.defer_fn(function()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  print('LSP clients count: ' .. #clients)
  
  if #clients > 0 then
    local client = clients[1]
    print('Client name: ' .. client.name)
    print('Root dir: ' .. tostring(client.config.root_dir))
    
    -- Wait for diagnostics
    vim.defer_fn(function()
      local diagnostics = vim.diagnostic.get(bufnr)
      print('Diagnostics count: ' .. #diagnostics)
      
      if #diagnostics > 0 then
        print('\n✓ SUCCESS: Diagnostics are working!')
        for i, diag in ipairs(diagnostics) do
          print(string.format('  %d. [%s] %s', i, diag.severity, diag.message))
        end
      else
        print('\n❌ FAILED: No diagnostics')
      end
      
      vim.cmd('qall!')
    end, 5000)
  else
    print('❌ No LSP clients attached')
    vim.cmd('qall!')
  end
end, 5000)
