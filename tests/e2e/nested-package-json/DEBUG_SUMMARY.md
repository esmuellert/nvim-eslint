# Debugging Summary: workingDirectory Investigation

## Investigation Request
Per user request, followed README.md debugging instructions to determine the actual workingDirectory being used by ESLint LSP for the problematic nested package.json structure.

## Methodology
1. Created `debug-working-dir.lua` script following README.md instructions
2. Enabled `vim.lsp.set_log_level('debug')` 
3. Captured LSP configuration sent to ESLint server
4. Analyzed LSP logs for `workspace/configuration` requests

## Key Findings

### 1. Root Directory Resolution Issue
**Problem**: `root_dir` resolves to the parent repository instead of the test project.

**Actual:**
```
Root Dir: /home/runner/work/nvim-eslint/nvim-eslint
```

**Expected:**
```
Root Dir: /home/runner/work/nvim-eslint/nvim-eslint/tests/e2e/nested-package-json
```

**Why**: The test project doesn't have its own `.git` directory, so `vim.fs.root(bufnr, {'.git'})` finds the parent repository's `.git`. This is the exact scenario users face!

### 2. workingDirectory Setting
**What's sent to ESLint LSP:**
```lua
workingDirectory = {
  mode = "location"
}
```

**What this means**: The ESLint LSP server decides the working directory using this algorithm:
1. Try to use `workspaceFolder` if it contains ESLint config
2. Fall back to file's directory
3. Search upward for ESLint config

### 3. workspaceFolder Configuration
**What's sent:**
```lua
workspaceFolder = {
  name = "nvim-eslint",
  uri = "file:///home/runner/work/nvim-eslint/nvim-eslint"
}
```

**Problem**: Points to the wrong directory! Should point to `nested-package-json/` directory.

### 4. The Resolution Cascade (Why It Fails)

Given the incorrect `workspaceFolder`, here's what happens:

```
1. ESLint LSP checks: /home/runner/work/nvim-eslint/nvim-eslint
   → No eslint.config.mjs found ✗

2. Falls back to file location: .../sub-dir/some-other-dir/
   → No config here ✗

3. Searches upward: .../sub-dir/
   → Finds package.json (intermediate one!)
   → Still no ESLint config ✗

4. Continues upward: .../nested-package-json/
   → Finds eslint.config.mjs ✓
   → BUT package.json in sub-dir/ already confused the resolution
   → ESLint gives up or fails to configure properly
```

### 5. Why ESLint CLI Works
```bash
$ cd nested-package-json/
$ npx eslint sub-dir/some-other-dir/file-to-lint.ts
```

When ESLint CLI runs from the project root:
- Working directory is already correct: `nested-package-json/`
- Finds `eslint.config.mjs` immediately
- No intermediate `package.json` confusion
- Lints successfully ✓

## The Core Problem

The issue has **two layers**:

1. **root_dir priority bug**: `.git` is prioritized over `eslint.config.*` files
   - This causes the wrong workspace to be used
   
2. **workingDirectory mode limitation**: `mode = "location"` relies on correct `workspaceFolder`
   - When workspace folder is wrong, the fallback mechanism gets confused by intermediate `package.json`

## Recommended Fix

**Change root_dir resolution order** in `lua/nvim-eslint/client.lua`:

**Current (lines 105-114):**
```lua
local root_dir = user_config.root_dir and user_config.root_dir(bufnr) or settings.resolve_git_dir(bufnr)
if not root_dir then
  root_dir = settings.resolve_package_json_dir(bufnr)
end
if not root_dir then
  root_dir = settings.resolve_eslint_config_dir(bufnr)
end
```

**Proposed:**
```lua
-- Try ESLint config first (highest priority for ESLint LSP)
local root_dir = user_config.root_dir and user_config.root_dir(bufnr) or settings.resolve_eslint_config_dir(bufnr)
-- Then try git (good for most projects)
if not root_dir then
  root_dir = settings.resolve_git_dir(bufnr)
end
-- Finally package.json (fallback for JS projects without ESLint config in git root)
if not root_dir then
  root_dir = settings.resolve_package_json_dir(bufnr)
end
```

**Why this fixes it:**
- ESLint config location is the most reliable indicator of where ESLint should run from
- This matches ESLint's own config resolution algorithm
- Prevents the `.git` in parent directories from causing issues
- Still uses `.git` for projects where config is at git root

## Alternative Workarounds

Users can work around this immediately by:

**Option 1: Override root_dir**
```lua
require('nvim-eslint').setup({
  root_dir = function(bufnr)
    return vim.fs.root(bufnr, {'eslint.config.mjs', '.eslintrc.js', '.eslintrc.json'})
  end,
})
```

**Option 2: Override workingDirectory**
```lua
require('nvim-eslint').setup({
  settings = {
    workingDirectory = function(bufnr)
      local eslint_root = vim.fs.root(bufnr, {'eslint.config.mjs', '.eslintrc.js'})
      return { directory = eslint_root }
    end,
  },
})
```

## Testing Verification

Run the debug script:
```bash
cd tests/e2e/nested-package-json
nvim -u debug-working-dir.lua --headless sub-dir/some-other-dir/file-to-lint.ts
cat /tmp/debug-working-dir-results.txt
```

Output shows:
- ✗ root_dir: `/home/runner/work/nvim-eslint/nvim-eslint` (wrong)
- ✗ workspaceFolder: points to nvim-eslint repo (wrong)
- ✗ Diagnostics: empty (expected, since config isn't found correctly)

## References
- README.md debugging section (lines 196-210)
- ESLint LSP settings: https://github.com/microsoft/vscode-eslint/blob/main/%24shared/settings.ts
- ESLint config resolution: https://eslint.org/docs/latest/use/configure/configuration-files#configuration-file-resolution
