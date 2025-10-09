#!/usr/bin/env python3
"""Exercise the ESLint configuration hot reload path via headless Neovim."""

from __future__ import annotations

import argparse
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List

# --- Section: Constants ---

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
DEFAULT_INIT = SCRIPT_DIR.parent / "parity" / "headless_init.lua"
DEFAULT_RUNNER = SCRIPT_DIR / "headless_config_reload.lua"


# --- Section: Process helpers ---


def run_command(command: List[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, text=True, capture_output=True)


# --- Section: Output parsing ---


def parse_json_lines(stream: str) -> List[Dict[str, Any]]:
    entries: List[Dict[str, Any]] = []
    for line in stream.splitlines():
        text = line.strip()
        if not text:
            continue
        if not text.startswith("{"):
            continue
        try:
            entries.append(json.loads(text))
        except json.JSONDecodeError as exc:  # noqa: PERF203 - keep informative error message
            raise ValueError(f"Failed to parse JSON line: {text}\n{exc}") from exc
    return entries


# --- Section: Neovim command construction ---


def build_runner_expression(opts: Dict[str, Any], runner_path: Path) -> str:
    payload = json.dumps(opts)
    return (
        "lua local runner = dofile(%r); "
        "local opts = vim.fn.json_decode(%r); "
        "assert(runner.run(opts), 'config reload runner failed')"
    ) % (str(runner_path), payload)


# --- Section: Diagnostic helpers ---


def count_messages(snapshot: Dict[str, Any]) -> int:
    diagnostics = snapshot.get("diagnostics")
    if not isinstance(diagnostics, list) or not diagnostics:
        return 0
    first = diagnostics[0]
    if not isinstance(first, dict):
        return 0
    messages = first.get("messages")
    if not isinstance(messages, list):
        return 0
    return len(messages)


# --- Section: Entry point ---


def main(argv: List[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Trigger an ESLint config change and ensure diagnostics refresh after the plugin restart.",
    )
    parser.add_argument(
        "--fixture-root",
        default=os.environ.get("NVIM_ESLINT_FIXTURE", "/workspace/turborepo"),
        help="Path to the sample repository used for the hot reload check.",
    )
    parser.add_argument(
        "--config-path",
        default="packages/create-turbo/.eslintrc.js",
        help="Relative path (from fixture root) to the ESLint configuration file to rewrite during the test.",
    )
    parser.add_argument(
        "--target",
        default="packages/create-turbo/src/__eslint_reload_target__.ts",
        help="Relative path (from fixture root) to the TypeScript file opened inside Neovim.",
    )
    parser.add_argument(
        "--expected-before",
        type=int,
        default=1,
        help="Expected diagnostic count before applying the relaxed configuration.",
    )
    parser.add_argument(
        "--expected-after",
        type=int,
        default=0,
        help="Expected diagnostic count after the relaxed configuration is written.",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=20000,
        help="Timeout (ms) to wait for diagnostics before or after the restart to settle.",
    )
    parser.add_argument(
        "--nvim-cmd",
        default=os.environ.get("NVIM_COMMAND", "nvim"),
        help="Neovim executable to invoke in headless mode.",
    )
    parser.add_argument(
        "--init",
        default=str(DEFAULT_INIT),
        help="Neovim init file that loads this plugin for headless execution.",
    )
    parser.add_argument(
        "--runner",
        default=str(DEFAULT_RUNNER),
        help="Lua runner that performs the headless diagnostic assertions.",
    )
    args = parser.parse_args(argv)

    fixture_root = Path(args.fixture_root).resolve()
    if not fixture_root.exists():
        print(f"Fixture repository {fixture_root} does not exist", file=sys.stderr)
        return 2

    config_path = fixture_root / args.config_path
    target_path = fixture_root / args.target

    if not config_path.parent.exists():
        print(f"Configuration directory {config_path.parent} does not exist", file=sys.stderr)
        return 2

    init_path = Path(args.init).resolve()
    if not init_path.exists():
        print(f"Neovim init file {init_path} does not exist", file=sys.stderr)
        return 2

    runner_path = Path(args.runner).resolve()
    if not runner_path.exists():
        print(f"Runner script {runner_path} does not exist", file=sys.stderr)
        return 2

    runner_opts = {
        "fixture_root": str(fixture_root),
        "config_path": str(config_path),
        "target_path": str(target_path),
        "expected_before": args.expected_before,
        "expected_after": args.expected_after,
        "timeout": args.timeout,
    }
    runner_expr = build_runner_expression(runner_opts, runner_path)

    headless_cmd = (
        shlex.split(args.nvim_cmd)
        + [
            "--headless",
            "-u",
            str(init_path),
            str(target_path),
            f"+{runner_expr}",
            "+qa",
        ]
    )

    result = run_command(headless_cmd, cwd=REPO_ROOT)
    if result.returncode != 0:
        print("Headless Neovim run failed:", file=sys.stderr)
        sys.stderr.write(result.stdout)
        sys.stderr.write(result.stderr)
        return result.returncode

    output = result.stdout or result.stderr
    try:
        events = parse_json_lines(output)
    except ValueError as exc:
        print(exc, file=sys.stderr)
        sys.stderr.write(output)
        return 1

    before = next((event for event in events if event.get("phase") == "before"), None)
    after = next((event for event in events if event.get("phase") == "after"), None)

    if before is None or after is None:
        print("Missing before/after diagnostic snapshots in headless output", file=sys.stderr)
        print(output, file=sys.stderr)
        return 1

    print("=== Headless ESLint diagnostics (before) ===")
    print(json.dumps(before, indent=2))
    print("=== Headless ESLint diagnostics (after) ===")
    print(json.dumps(after, indent=2))

    before_count = count_messages(before)
    after_count = count_messages(after)

    if before_count != args.expected_before:
        print(
            f"Expected {args.expected_before} diagnostics before reload but observed {before_count}",
            file=sys.stderr,
        )
        return 1

    if after_count != args.expected_after:
        print(
            f"Expected {args.expected_after} diagnostics after reload but observed {after_count}",
            file=sys.stderr,
        )
        return 1

    print("Config reload diagnostics matched expectations.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
