# Command-Line Debugging Tools for ESLint Language Server

This document explains various command-line tools and techniques that can be used to debug the ESLint language server and capture the actual resolved `workingDirectory` path.

## Available Tools

### 1. Node.js Inspector Protocol (Built-in)

Node.js has a built-in debugging protocol that can be used without VSCode:

**Start server with inspector:**
```bash
node --inspect=9229 vscode-eslint/server/out/eslintServer.js
```

**Connect using Chrome DevTools:**
1. Open `chrome://inspect` in Chrome/Chromium
2. Click "Configure" and add `localhost:9229`
3. Click "inspect" under the remote target
4. Set breakpoints in the Sources tab
5. Look for workingDirectory resolution code

**Connect using node-inspect (CLI debugger):**
```bash
npm install -g node-inspect
node-inspect vscode-eslint/server/out/eslintServer.js
```

Then use debugger commands:
- `setBreakpoint()` - set breakpoint at current line
- `cont` or `c` - continue execution
- `next` or `n` - step over
- `step` or `s` - step into
- `exec <expression>` - evaluate expression
- `repl` - enter REPL mode to inspect variables

### 2. Monkey-Patching Approach (Custom Script)

I've created `debug-server-monkey-patch.js` that intercepts ESLint constructor calls:

```bash
cd tests/e2e/nested-package-json
node debug-server-monkey-patch.js
```

This script:
- Monkey-patches `Module.prototype.require` to intercept ESLint module loading
- Wraps ESLint/CLIEngine constructors to log their options
- Intercepts `process.chdir` calls
- Logs all findings to `/tmp/eslint-server-monkey-patch.log`

**To use with Neovim:**
Update your LSP config to use this wrapper:
```lua
cmd = { 'node', '/path/to/debug-server-monkey-patch.js' }
```

### 3. Console Log Injection

Directly add logging to the server code:

```bash
# Make a backup first
cp vscode-eslint/server/out/eslintServer.js vscode-eslint/server/out/eslintServer.js.bak

# Add console.error logging (goes to stderr, won't interfere with LSP protocol)
# Find the workingDirectory resolution code and add:
# console.error('WORKING_DIR:', resolvedWorkingDirectory);
```

Search for patterns like:
- `workingDirectory`
- `getWorkingDirectory`  
- `options.cwd`
- `ESLint constructor`

### 4. strace/ltrace (System Call Tracing)

On Linux, use `strace` to see all system calls including `chdir`:

```bash
strace -e chdir -f node vscode-eslint/server/out/eslintServer.js 2>&1 | grep chdir
```

This shows all directory changes made by the process.

### 5. Node.js --trace Flags

Node.js has built-in tracing:

```bash
# Trace all module loads
node --trace-warnings --trace-deprecation vscode-eslint/server/out/eslintServer.js

# Enable V8 tracing
node --trace-opt --trace-deopt vscode-eslint/server/out/eslintServer.js
```

### 6. Environment Variable Debugging

Set ESLint debug variables:

```bash
DEBUG=eslint:* node vscode-eslint/server/out/eslintServer.js
```

Or for the language server:

```bash
VSCODE_ESLINT_DEBUG=true node vscode-eslint/server/out/eslintServer.js
```

## Recommended Approach for This Case

For capturing the actual `workingDirectory` path, I recommend:

### Option A: Monkey-Patch Script (Easiest)

Use the provided `debug-server-monkey-patch.js`:

1. Start Neovim with a config that uses the debug wrapper
2. Check `/tmp/eslint-server-monkey-patch.log` for the actual CWD passed to ESLint

### Option B: Direct Code Injection (Most Accurate)

1. Add logging directly to `eslintServer.js`:
   ```javascript
   // Search for where workingDirectory is used, around line 923 mentioned in README
   // Add before ESLint instantiation:
   console.error('DEBUG_WD:', JSON.stringify({
     workingDirectory: workingDirectory,
     cwd: options.cwd,
     process_cwd: process.cwd()
   }));
   ```

2. Run Neovim and check stderr output

### Option C: Chrome DevTools (Most Interactive)

1. Start server with `--inspect-brk`:
   ```bash
   node --inspect-brk=9229 vscode-eslint/server/out/eslintServer.js
   ```

2. Open `chrome://inspect` in Chrome

3. Set breakpoint at line ~923 in eslintServer.js (or search for "workingDirectory")

4. Continue execution and inspect variables when breakpoint hits

## Test Scripts Provided

I've created the following debugging tools in `tests/e2e/nested-package-json/`:

1. **`debug-server-monkey-patch.js`** - Main debugging wrapper
2. **`debug-server-inspector.js`** - Alternative using inspector API
3. **`debug-server.js`** - Simple message interceptor
4. **`debug-with-monkey-patch.lua`** - Neovim config to use the wrapper

## Expected Output

When the debugging captures the workingDirectory, you should see something like:

```
!!! ESLint constructor called with options:
{
  "cwd": "/actual/resolved/path",
  "fix": true,
  ...
}
!!! FOUND CWD in ESLint options: /actual/resolved/path
```

This will tell us the exact path ESLint uses, which is the critical missing piece for understanding why nested package.json structures fail.

## Next Steps After Capturing workingDirectory

Once we have the actual path:

1. Compare it to the expected path
2. Determine if it's resolving to `sub-dir/` or the parent repo root
3. Understand why the intermediate `package.json` causes issues
4. Implement the fix to change root_dir priority order
