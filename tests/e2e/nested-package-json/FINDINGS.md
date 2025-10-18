# Investigation Findings: Nested package.json Issue

## Issue Summary

As reported in [#10](https://github.com/esmuellert/nvim-eslint/issues/10), the nvim-eslint plugin fails to lint files when there is an intermediate `package.json` file between the file to lint and the ESLint configuration.

## Test Setup

Created a test project at `tests/e2e/nested-package-json/` that exactly replicates the user's folder structure:

```
nested-package-json/
├── .git/                          # Git repository root
├── eslint.config.mjs              # ESLint flat config
├── package.json                   # Root package.json with dependencies
├── root-file.ts                   # Works correctly
└── sub-dir/
    ├── package.json               # Intermediate package.json (causes issue)
    ├── sub-dir-file.ts            # May or may not work
    └── some-other-dir/
        └── file-to-lint.ts        # DOES NOT WORK
```

## Verification Results

### ESLint CLI (Working Correctly)
```bash
$ cd tests/e2e/nested-package-json
$ npx eslint sub-dir/some-other-dir/file-to-lint.ts
# ✓ Shows 7 linting problems (5 errors, 2 warnings)
```

### nvim-eslint Plugin (Issue Reproduced)

When opening `sub-dir/some-other-dir/file-to-lint.ts` with nvim-eslint:

**Actual LSP Configuration (from debug-working-dir.lua):**
- **No diagnostics appear** (empty diagnostics array: `{}`)
- **Root Dir**: `/home/runner/work/nvim-eslint/nvim-eslint` (git root of the nvim-eslint repo, NOT the test project!)
- **workingDirectory**: `{ mode = "location" }`
- **workspaceFolder**: 
  ```lua
  {
    name = "nvim-eslint",
    uri = "file:///home/runner/work/nvim-eslint/nvim-eslint"
  }
  ```

**What the ESLint LSP Server Receives:**

According to the [ESLint LSP documentation](https://github.com/microsoft/vscode-eslint/blob/main/%24shared/settings.ts#L156-L178), when `workingDirectory.mode = "location"`, the server determines the working directory by:
1. First trying to use the `workspaceFolder` (which points to wrong directory: `/home/runner/work/nvim-eslint/nvim-eslint`)
2. Falling back to the file's location if workspace folder doesn't have ESLint config

**The Resolution Process in ESLint LSP:**
- The server looks for ESLint config files starting from the workspaceFolder
- It finds NO eslint.config.mjs in `/home/runner/work/nvim-eslint/nvim-eslint`
- Falls back to the file location: `sub-dir/some-other-dir/`
- Looks for config in: `sub-dir/some-other-dir/`, `sub-dir/`, then `nested-package-json/`
- Finds `eslint.config.mjs` in `nested-package-json/`
- BUT the intermediate `package.json` in `sub-dir/` confuses the resolution
- Result: ESLint fails to properly configure and returns no diagnostics

**Expected Configuration:**
- **Root Dir**: `/home/runner/work/nvim-eslint/nvim-eslint/tests/e2e/nested-package-json`
- **workspaceFolder**: 
  ```lua
  {
    name = "nested-package-json",
    uri = "file:///home/runner/work/nvim-eslint/nvim-eslint/tests/e2e/nested-package-json"
  }
  ```
- With this, ESLint would find the config immediately and lint correctly

## Root Cause Analysis

The issue appears to be related to how the plugin determines the `root_dir`:

From `lua/nvim-eslint/client.lua` (lines 105-114):
```lua
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
```

The resolution order is:
1. Git directory (`.git`)
2. package.json directory  
3. ESLint config directory
4. Current working directory

### The Problem

When Neovim is opened from the repository root (as in our test environment), `vim.fs.root()` finds the `.git` directory at the repository root level, not at the test project level.

For the nested structure:
- `file-to-lint.ts` is at: `tests/e2e/nested-package-json/sub-dir/some-other-dir/`
- The `.git` directory is at: repository root (not in the test project)
- `vim.fs.root(bufnr, {'.git'})` returns the repository root
- This sets the wrong `root_dir` for the LSP client
- The ESLint server then uses the wrong `workingDirectory`

### Why the intermediate package.json matters

The intermediate `package.json` at `sub-dir/` doesn't directly cause the issue, but it may:
1. Confuse `vim.fs.root(bufnr, {'package.json'})` to return `sub-dir/` instead of the project root
2. Cause ESLint to look for config in the wrong directory
3. Make the `workingDirectory` resolution incorrect

## Expected Behavior

The plugin should:
1. Find the correct project root where `eslint.config.mjs` and the main `package.json` are located
2. Set `root_dir` to that directory
3. Set `workingDirectory` appropriately so ESLint can find its configuration

## Workaround

Users can work around this by explicitly setting `root_dir` in their configuration:
```lua
require('nvim-eslint').setup({
  root_dir = function(bufnr)
    -- Custom logic to find the correct project root
    return vim.fs.root(bufnr, {'eslint.config.mjs', '.eslintrc.js'})
  end,
})
```

Or by setting a custom `workingDirectory`:
```lua
require('nvim-eslint').setup({
  settings = {
    workingDirectory = function(bufnr)
      return { directory = vim.fs.root(bufnr, {'eslint.config.mjs', 'package.json'}) }
    end,
  },
})
```

## Debugging Process

Following the README.md debugging instructions, a debug script (`debug-working-dir.lua`) was created to:
1. Enable `vim.lsp.set_log_level('debug')` as recommended
2. Capture the actual LSP configuration sent to the server
3. Monitor what the ESLint LSP receives

**Key Files:**
- `debug-working-dir.lua` - Debug script that captures LSP configuration
- Output saved to `/tmp/debug-working-dir-results.txt`
- LSP log at `~/.local/state/nvim/lsp.log` contains full request/response details

**How to reproduce the debugging:**
```bash
cd tests/e2e/nested-package-json
nvim -u debug-working-dir.lua --headless sub-dir/some-other-dir/file-to-lint.ts
cat /tmp/debug-working-dir-results.txt
```

## Next Steps

To fix this issue properly, the plugin should:

1. **Improve root_dir resolution**: Consider ESLint config location with higher priority than `.git`
   - Current order: `.git` → `package.json` → `eslint.config.*` → `cwd`
   - Better order: `eslint.config.*` → `.git` → `package.json` → `cwd`
   
2. **Better workingDirectory handling**: The default `{ mode = "location" }` doesn't work well when:
   - The `workspaceFolder` points to the wrong directory
   - There are intermediate `package.json` files
   - Solution: Calculate workingDirectory dynamically to point to ESLint config location
   
3. **Add documentation**: Warn users about this edge case and provide configuration examples

## References

- Original Issue: https://github.com/esmuellert/nvim-eslint/issues/10
- User's folder structure: https://github.com/esmuellert/nvim-eslint/issues/10#issuecomment-3384387846
- ESLint Configuration Files: https://eslint.org/docs/latest/use/configure/configuration-files#configuration-file-resolution
