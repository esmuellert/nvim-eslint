-- Debug configuration for ESLint with monkey-patched server
-- This uses the debug wrapper to capture actual workingDirectory resolution

vim.lsp.set_log_level('debug')

local nvim_lsp = require('lspconfig')
local util = require('lspconfig.util')

-- Use the monkey-patch debug wrapper instead of the normal server
local debug_server_path = vim.fn.getcwd() .. '/debug-server-monkey-patch.js'

nvim_lsp.eslint.setup({
  cmd = { 'node', debug_server_path },
  root_dir = function(fname)
    local root = util.root_pattern('.git', 'package.json', 'eslint.config.mjs')(fname)
    print('Root dir for ' .. fname .. ': ' .. (root or 'nil'))
    return root
  end,
  settings = {
    workingDirectory = { mode = 'location' },
    useFlatConfig = true,
  },
  on_attach = function(client, bufnr)
    print('ESLint LSP attached to buffer ' .. bufnr)
    
    -- Give the server time to initialize
    vim.defer_fn(function()
      -- Request diagnostics
      vim.lsp.buf_request(bufnr, 'textDocument/diagnostic', {
        textDocument = vim.lsp.util.make_text_document_params(bufnr)
      }, function(err, result)
        if err then
          print('Error requesting diagnostics: ' .. vim.inspect(err))
        else
          print('Diagnostics result: ' .. vim.inspect(result))
        end
        
        -- Output the results and quit
        local output_file = '/tmp/debug-monkey-patch-results.txt'
        local f = io.open(output_file, 'w')
        if f then
          f:write('=== Debug Results with Monkey Patch ===\n')
          f:write('Check /tmp/eslint-server-monkey-patch.log for detailed server logs\n')
          f:write('This log should contain the actual CWD used by ESLint\n')
          f:close()
        end
        
        print('Results written to ' .. output_file)
        print('Server log: /tmp/eslint-server-monkey-patch.log')
        
        vim.cmd('qall!')
    end)
  end, 3000)
  end,
})

-- Open the file and wait
vim.cmd('edit sub-dir/some-other-dir/file-to-lint.ts')

-- Wait for LSP to start
vim.wait(5000)
