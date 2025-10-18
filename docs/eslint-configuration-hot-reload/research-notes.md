# ESLint Configuration Hot Reload Research

This document consolidates the study and verification work around automatically reacting to ESLint configuration changes inside `nvim-eslint`.

## Environment

- Neovim v0.12.0-dev (nightly `nvim-linux-x86_64` build).
- Node.js v22.19.0.
- PNPM v10.13.1 for installing the JavaScript fixture dependencies.

## Fixture preparation

The end-to-end helper reuses the Turborepo workspace rather than checking in a bespoke Node project. Clone the repository and install its dependencies before running the headless experiment:

```bash
export NVIM_ESLINT_FIXTURE=/tmp/turbo
rm -rf "$NVIM_ESLINT_FIXTURE"
git clone --depth 1 https://github.com/vercel/turborepo.git "$NVIM_ESLINT_FIXTURE"
(cd "$NVIM_ESLINT_FIXTURE" && pnpm install --frozen-lockfile)
```

The helper script (`tests/e2e/config-reload/headless_config_reload.lua`) writes an ESLint config into `packages/create-turbo/.eslintrc.js` that flags `console.log` as an error, seeds a reproducible target file, and then rewrites the config to disable the rule. The script restores both files when it finishes so the Turborepo checkout remains clean.【F:tests/e2e/config-reload/headless_config_reload.lua†L1-L178】

## Headless reproduction

Run Neovim in headless mode with the parity harness to collect diagnostics before and after the config change:

```bash
/workspace/nvim-linux-x86_64/bin/nvim --headless \
  -u tests/e2e/parity/headless_init.lua \
  "$NVIM_ESLINT_FIXTURE/packages/create-turbo/src/__eslint_reload_target__.ts" \
  +"lua local runner = dofile([[tests/e2e/config-reload/headless_config_reload.lua]]); runner.run({ fixture_root = [[${NVIM_ESLINT_FIXTURE}]], expected_before = 1, expected_after = 0 })" \
  +qa
```

The captured log shows that the initial diagnostic (`no-console`) disappears immediately after `headless_config_reload.lua` rewrites `.eslintrc.js`.【F:docs/research/turborepo-config-reload.log†L1-L4】 The helper emits a `before` snapshot with one error and an `after` snapshot with zero errors, confirming that the restart logic refreshes the server state.

## Hot reload vs. restart

To validate whether notification-based hot reload was sufficient, the plugin temporarily dropped the restart call from `handle_config_change()` so it only sent `workspace/didChangeWatchedFiles`, `workspace/didChangeConfiguration`, and two diagnostic refresh requests. Rerunning the headless scenario with that configuration showed that ESLint kept reporting the `no-console` error until the client restarted, meaning the upstream server did not re-read the config even after the notifications. Restoring `schedule_client_restart()` immediately cleared the diagnostics on the same run, proving the restart is what pulls in the new rules.【F:docs/eslint-configuration-hot-reload/refactor-compatibility-analysis.md†L24-L26】

## Implementation notes

- `make_client_capabilities()` advertises `workspace.didChangeWatchedFiles.dynamicRegistration` so the ESLint server can request dynamic watchers when necessary.【F:lua/nvim-eslint/settings.lua†L131-L135】
- The watcher layer tracks every config and package file it sees through `ensure_watches()` and starts a file-system watcher per directory. When any watched file changes, `handle_config_change()` now delegates directly to `schedule_client_restart()`, guaranteeing that diagnostics match the latest rules without manual intervention.【F:lua/nvim-eslint/watchers.lua†L10-L154】【F:lua/nvim-eslint/client.lua†L47-L103】

## Conclusion

`nvim-eslint` reacts to edits in `.eslintrc.*`, `eslint.config.*`, and `package.json` by restarting the ESLint language server and reattaching every previously connected buffer. Upstream ESLint does not fully hot reload the configuration based solely on notifications, so keeping the restart in place is required to maintain accurate diagnostics after configuration changes.
