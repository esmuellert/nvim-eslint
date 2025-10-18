# ESLint Refactor Compatibility Review

## Overview
The modular refactor keeps `require('nvim-eslint').setup()` as the only public entry point while moving implementation details into dedicated modules. The entry file simply returns the client module, so existing configuration snippets continue to work unchanged.

## Autostart triggers
`client.setup_lsp_start()` still registers a `FileType` autocommand for the same default filetypes and merges any user supplied list. The callback continues to hand the buffer number to the client launcher, ensuring the LSP starts automatically for supported JavaScript and TypeScript buffers just like before.

## Root directory resolution and client reuse
When a buffer needs a client, `start_client_for_buffer()` preserves the previous root detection order: user override, Git repository, nearest `package.json`, or an ESLint config directory, with a final fallback to the current working directory. Neovim's LSP core reuses a running client whenever the requested `root_dir` matches, so buffers inside the same project remain attached to a single ESLint server instance exactly as documented in the README.

## Settings flattening
`settings.make_settings()` still combines user overrides with the default table, calls function-valued entries with the target buffer number, and returns plain values to the language server. This keeps runtime-sensitive settings such as `workspaceFolder`, `workingDirectory`, `useFlatConfig`, and `nodePath` behaving exactly as before. The helper also copies the legacy warning that falls back to `vim.fn.getcwd()` if no project markers can be located, so monorepo and single-repo defaults remain intact.

## Command construction and capabilities
`settings.create_cmd()` continues to build either a standard `node .../eslintServer.js --stdio` command or the debug variant when `debug = true`. `client.make_client_capabilities()` now delegates to `settings.make_client_capabilities()`, which extends the default Neovim capabilities with dynamic configuration and watched file registration. These mirror the old `make_client_capabilities()` while exposing the additional capabilities required for hot reload.

## Handler behaviour
The rewritten `workspace/configuration` handler still refreshes cached settings with `M.make_settings(bufnr)` before responding, keeping dynamic options (for example, per-package `workspaceFolder`) aligned with the server request. No other handlers were added or removed in the latest cleanup, so configuration responses continue to mirror the previous behaviour.

## Watch management and hot reload integration
`watchers.ensure()` collects package manifests and ESLint config files for the active buffer, registers `uv` file watchers once per directory, and keeps track of each client subscription. When a watched file changes, `client.handle_config_change()` now immediately schedules a single client restart, which is the only action required to pick up the updated ESLint rules. The restart path re-attaches every buffer that was previously connected to the client, so diagnostics stay in sync without requiring manual buffer juggling.

## Restart requirement validation
To verify that a restart is still mandatory, the watcher experiment dropped the `schedule_client_restart()` call and re-ran the Turborepo headless scenario. ESLint kept reporting the strict `no-console` diagnostic until the client restarted, and the error disappeared immediately once the restart path was restored. This confirms that simply notifying the server about config changes does not reload the new rules.

## No regressions for existing workflows
- **Single server per project** – All buffers sharing a root directory still resolve to the same client because `vim.lsp.start()` sees identical `root_dir` values. The restart helper preserves the attachment list to maintain that invariant.
- **Custom user hooks** – `on_attach`, `on_exit`, `cmd`, `capabilities`, and `handlers` callbacks are invoked with the same timing and arguments because the client wrapper simply calls the user-provided functions after performing its own setup.
- **Default settings surface** – Callers continue to access helpers like `create_cmd`, `resolve_git_dir`, and `use_flat_config` via the exported client module, matching the previous API exposed from `init.lua`.

## Summary
The refactor primarily rearranges implementation files while preserving the external API, autostart rules, root inference, and default ESLint settings described in the README. The new watcher layer layers hot configuration reloads on top of those behaviours, avoiding breaking changes by reusing the existing lifecycle hooks and ensuring every buffer remains attached to a single, up-to-date ESLint language server.
