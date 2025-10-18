# Test Project Update: Git Repository Added

## What Changed

A `.git` repository has been initialized in the `tests/e2e/nested-package-json/` test project.

## Why This Matters

### Before (Without .git in test project):
- The plugin's `root_dir` resolution looked for `.git` directory
- Found the parent nvim-eslint repository's `.git` instead
- `root_dir` = `/home/runner/work/nvim-eslint/nvim-eslint` (WRONG)
- `workspaceFolder` pointed to wrong directory
- ESLint server couldn't find config properly

### After (With .git in test project):
- The plugin's `root_dir` resolution finds the test project's `.git`
- `root_dir` should be = `/home/runner/work/nvim-eslint/nvim-eslint/tests/e2e/nested-package-json` (CORRECT)
- `workspaceFolder` should point to correct directory
- ESLint server should find `eslint.config.mjs` in workspace

## Expected Outcome

With the `.git` directory present, this test project now matches the **exact folder structure** reported by the user in [issue #10, comment 3384387846](https://github.com/esmuellert/nvim-eslint/issues/10#issuecomment-3384387846):

```
project/
  .git/
  sub-dir/
    some-other-dir/
      file-to-lint.ts
    package.json
  eslint.config.mjs
  package.json
```

### Two Possible Outcomes:

1. **Diagnostics appear** - This means the issue was solely about `root_dir` resolution prioritizing a parent `.git` directory. The fix would be to adjust the `root_dir` priority order in `lua/nvim-eslint/client.lua` to check ESLint config files first, then `.git`.

2. **Diagnostics still don't appear** - This means the issue is deeper, likely in how the ESLint language server itself resolves configurations when it encounters intermediate `package.json` files, even with the correct `workspaceFolder`. This would require investigating the ESLint LSP server's config resolution algorithm.

## Testing Instructions

To verify the behavior with the new `.git` directory:

```bash
cd /home/runner/work/nvim-eslint/nvim-eslint/tests/e2e/nested-package-json

# Verify .git exists
ls -la .git/

# Test with nvim-eslint
nvim sub-dir/some-other-dir/file-to-lint.ts

# In Neovim:
:LspInfo    # Check root_dir and workspaceFolder
# Should see diagnostics if .git was the issue

# Compare with ESLint CLI (which works)
npx eslint sub-dir/some-other-dir/file-to-lint.ts
```

## Next Steps

1. Test with Neovim to verify the `root_dir` now resolves correctly
2. Check if diagnostics appear with the corrected `root_dir`
3. If diagnostics still don't appear, use the debugging tools (especially `debug-server-monkey-patch.js`) to capture the actual `workingDirectory` path used by the ESLint server
4. Determine whether the fix should be in the plugin's `root_dir` logic or if it requires deeper investigation of ESLint LSP server behavior

## Related Files

- `FINDINGS.md` - Updated with explanation of the change
- `README.md` - Already documented `.git/` in folder structure
- `DEBUG_SUMMARY.md` - Contains original analysis before .git was added
- `DEBUGGING_TOOLS.md` - Tools for investigating server-side behavior
