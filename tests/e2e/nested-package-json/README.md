# Nested package.json Test Project

This test project replicates the issue described in [#10](https://github.com/esmuellert/nvim-eslint/issues/10) where the plugin fails to lint files when there is a `package.json` file in a subdirectory between the file to lint and the ESLint config.

## Folder Structure

```
tests/e2e/nested-package-json/
├── .git/                          # Git repository root
├── eslint.config.mjs              # ESLint flat config at root
├── package.json                   # Root package.json
├── root-file.ts                   # Test file at root level
└── sub-dir/                       
    ├── package.json               # Intermediate package.json (causes the issue)
    ├── sub-dir-file.ts            # Test file at sub-dir level
    └── some-other-dir/
        └── file-to-lint.ts        # Test file at deepest level (problematic)
```

## Purpose

This structure tests whether the plugin can correctly lint files in nested directories when there's an intermediate `package.json` file that is not a real package, but just a descriptive metadata file.

### Expected Behavior

ESLint CLI should be able to lint all TypeScript files in this structure:
- `root-file.ts`
- `sub-dir/sub-dir-file.ts`
- `sub-dir/some-other-dir/file-to-lint.ts`

### Actual Behavior (Issue)

When opening `sub-dir/some-other-dir/file-to-lint.ts` in Neovim with nvim-eslint:
- The server sends an `eslint/noConfig` request
- No linting occurs for this file
- Deleting `sub-dir/package.json` makes it work again

## Setup

**IMPORTANT**: This test project requires its own `.git` repository to accurately replicate the user's environment. The `.git` directory cannot be committed to the parent repository, so you must initialize it manually.

To prepare this test project:

```bash
cd tests/e2e/nested-package-json

# Initialize the .git repository (REQUIRED)
./setup-git.sh

# Install dependencies (if not already installed)
npm install
```

## Testing with ESLint CLI

Verify that ESLint CLI works correctly:

```bash
# From the nested-package-json directory
npx eslint sub-dir/some-other-dir/file-to-lint.ts
npx eslint sub-dir/sub-dir-file.ts  
npx eslint root-file.ts
```

All files should show linting errors as defined in `eslint.config.mjs`.

## Testing with nvim-eslint

1. Open Neovim from the nested-package-json directory
2. Open any of the TypeScript files
3. Check if diagnostics appear
4. Use `:LspInfo` to check `workingDirectory` and `workspaceFolder`

## Sample Lint Errors

Each TypeScript file contains intentional ESLint violations:
- `@typescript-eslint/no-unused-vars` - Unused variables
- `prefer-const` - Variables that should be const
- `no-console` - Console.log statements
- `eqeqeq` - Use of `==` instead of `===`
- `@typescript-eslint/no-explicit-any` - Use of `any` type

## References

- Issue: https://github.com/esmuellert/nvim-eslint/issues/10
- User's last comment with folder structure: https://github.com/esmuellert/nvim-eslint/issues/10#issuecomment-3384387846
