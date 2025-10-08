# End-to-End ESLint parity verification

This guide documents the end-to-end test suite that compares diagnostics from `nvim-eslint` against the official ESLint CLI. The harness reproduces the complete toolchain: it opens a real TypeScript workspace, seeds deterministic lint violations, gathers headless Neovim output, and asserts that the collected diagnostics match the CLI results.

## Overview
- **Test type:** End-to-end validation that exercises Neovim, the ESLint language server, and the target repository together.
- **Location:** `tests/e2e/parity/`
- **Primary scripts:**
  - `seed_eslint_errors.py` injects reproducible ESLint violations into TypeScript files.
  - `run_eslint_parity.py` runs the ESLint CLI, executes Neovim headlessly, and normalizes both JSON payloads.
  - `run_eslint_parity_suite.py` orchestrates multi-file parity checks for CI.

## Prerequisites
- Neovim 0.11 or newer so `vim.fs.root` and ESLint integration behave identically to CI.
- Node.js LTS (the workflow requests `lts/*`) and the latest PNPM release. The GitHub Actions workflow mirrors the [pnpm/action-setup](https://github.com/pnpm/action-setup) example: install PNPM via the action first, then initialize Node.js with `actions/setup-node` to enable caching.
- Python 3.10+ for the helper scripts.
- Network access to clone the `turborepo` fixture unless you supply `NVIM_ESLINT_FIXTURE` yourself.

## Prepare the fixture repository
```bash
export NVIM_ESLINT_FIXTURE=/workspace/turborepo
rm -rf "$NVIM_ESLINT_FIXTURE"
git clone --depth 1 https://github.com/vercel/turborepo.git "$NVIM_ESLINT_FIXTURE"
cd "$NVIM_ESLINT_FIXTURE"
pnpm install --frozen-lockfile
```

## Seed deterministic ESLint violations
Use the helper to append violations to any TypeScript source file inside the fixture. The injected block is wrapped in an IIFE so the new symbols stay scoped.
```bash
python tests/e2e/parity/seed_eslint_errors.py "$NVIM_ESLINT_FIXTURE/packages/create-turbo/src/cli.ts"
```
Pass `--errors` to focus on a subset of rules (supported values: `unused-vars`, `explicit-any`, `prefer-const`, `no-console`, `eqeqeq`). Running the helper again removes the previous block before re-injecting fresh snippets.

## Compare ESLint CLI and headless Neovim output
Invoke the parity script to ensure the normalized ESLint CLI JSON matches the collector output.
```bash
python tests/e2e/parity/run_eslint_parity.py \
  --fixture-root "$NVIM_ESLINT_FIXTURE" \
  --target packages/create-turbo/src/cli.ts
```
The script prints:
1. Raw ESLint CLI JSON (`--format json`).
2. Headless collector JSON emitted from Neovim.
3. A canonicalized diff-friendly structure that ignores ordering differences.

The command exits with status `0` when both results align, or `1` with a summary when they differ.

## Run the full end-to-end suite
Execute the orchestrator to seed and lint five representative entry points. The helper runs `run_eslint_parity.py` for each target and fails fast if any comparison diverges.
```bash
python tests/e2e/parity/run_eslint_parity_suite.py \
  --fixture-root "$NVIM_ESLINT_FIXTURE" \
  --nvim-cmd /path/to/nvim
```
Environment variables:
- `NVIM_ESLINT_FIXTURE` overrides `--fixture-root` when the flag is omitted.

Useful flags:
- `--errors` limits the seeded rules for every file.
- `--skip-seed` reuses existing violations (helpful for debugging).
- `--timeout` adjusts the milliseconds the collector waits for diagnostics (default: `20000`).

## Continuous integration
The GitHub Actions workflow `.github/workflows/eslint-parity.yml` provisions Neovim, PNPM, and Node.js, checks out the turborepo fixture, installs dependencies, and runs `python tests/e2e/parity/run_eslint_parity_suite.py` on every push and pull request targeting `main`. It follows pnpm's recommended order (`pnpm/action-setup@v4` with the latest PNPM channel before `actions/setup-node@v4`) so the package manager and cache are configured consistently. The job installs Neovim from the `neovim-ppa/unstable` channel to pick up the newest 0.11 builds and pins Node.js to the LTS train. A scheduled run executes twice per week (Tuesdays at 06:00 UTC and Fridays at 18:00 UTC) to guard against upstream regressions.
