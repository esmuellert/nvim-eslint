#!/bin/bash
# Test script to reproduce the nested package.json issue

set -e

echo "=== Nested Package.json Issue Reproduction Test ==="
echo ""

# Change to the test project directory
cd "$(dirname "$0")"

echo "Test project location: $(pwd)"
echo "Folder structure:"
tree -L 3 -I node_modules

echo ""
echo "=== Step 1: Verify ESLint CLI works ==="
echo "Testing: sub-dir/some-other-dir/file-to-lint.ts"
npx eslint sub-dir/some-other-dir/file-to-lint.ts && echo "✓ ESLint CLI works" || echo "✗ ESLint CLI found errors (expected)"

echo ""
echo "=== Step 2: Manual Neovim Test Instructions ==="
echo "To manually test with Neovim:"
echo "  1. cd $(pwd)"
echo "  2. nvim sub-dir/some-other-dir/file-to-lint.ts"
echo "  3. Wait for LSP to attach"
echo "  4. Run :LspInfo to check:"
echo "     - root_dir should be: $(pwd)"
echo "     - workingDirectory.mode should be: location"
echo "  5. Check if diagnostics appear with :lua vim.diagnostic.get(0)"
echo ""
echo "Expected: Diagnostics should appear for the file"
echo "Actual (bug): No diagnostics appear because:"
echo "  - ESLint server receives incorrect workingDirectory"
echo "  - The intermediate package.json in sub-dir/ confuses path resolution"
echo ""

echo "=== Step 3: Test with different starting directories ==="
echo ""
echo "Testing from repository root (outside test project):"
echo "This simulates the issue where nvim is started from a parent directory"
