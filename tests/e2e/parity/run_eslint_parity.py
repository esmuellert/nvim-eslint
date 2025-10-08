#!/usr/bin/env python3
"""Compare ESLint CLI diagnostics with headless Neovim output."""

from __future__ import annotations

import argparse
import json
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
DEFAULT_INIT = SCRIPT_DIR / "headless_init.lua"
DEFAULT_COLLECTOR = SCRIPT_DIR / "headless_collect.lua"


def run_command(command: List[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, text=True, capture_output=True)


def load_json(output: str, *, label: str) -> Any:
    text = output.strip()
    if not text:
        raise ValueError(f"{label} produced no JSON output")
    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Failed to parse {label} JSON: {exc}\nRaw output:\n{text}") from exc


def canonicalize(results: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    canonical: List[Dict[str, Any]] = []
    for entry in results:
        messages = []
        for message in entry.get("messages", []):
            messages.append(
                {
                    "ruleId": message.get("ruleId"),
                    "severity": message.get("severity"),
                    "message": message.get("message"),
                    "line": message.get("line"),
                    "column": message.get("column"),
                    "endLine": message.get("endLine"),
                    "endColumn": message.get("endColumn"),
                }
            )
        messages.sort(key=lambda item: (item.get("line"), item.get("column"), item.get("ruleId"), item.get("message")))
        error_count = sum(1 for msg in messages if msg.get("severity") == 2)
        warning_count = sum(1 for msg in messages if msg.get("severity") != 2)
        canonical.append(
            {
                "filePath": entry.get("filePath"),
                "messages": messages,
                "errorCount": entry.get("errorCount", error_count),
                "warningCount": entry.get("warningCount", warning_count),
            }
        )
    canonical.sort(key=lambda item: item.get("filePath"))
    return canonical


def resolve_repo_path(value: str | Path) -> Path:
    path = Path(value)
    if path.is_absolute():
        return path
    return (REPO_ROOT / path).resolve()


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare ESLint CLI output with headless Neovim diagnostics")
    parser.add_argument("--fixture-root", default="/workspace/turborepo", help="Path to the sample repository to lint")
    parser.add_argument("--target", default="packages/create-turbo/src/cli.ts", help="Relative path to the file to lint")
    parser.add_argument("--eslint-cmd", default="pnpm exec eslint", help="Command used to invoke the ESLint CLI")
    parser.add_argument("--nvim-cmd", default="nvim", help="Neovim executable to run in headless mode")
    parser.add_argument("--init", default=str(DEFAULT_INIT), help="Neovim init file that loads the plugin")
    parser.add_argument("--collector", default=str(DEFAULT_COLLECTOR), help="Collector script to execute inside Neovim")
    parser.add_argument("--timeout", type=int, default=20000, help="Timeout (ms) for the collector to wait for diagnostics")
    args = parser.parse_args()

    repo_root = REPO_ROOT
    fixture_root = Path(args.fixture_root).resolve()
    target_path = fixture_root / args.target

    if not target_path.exists():
        print(f"Target file {target_path} does not exist", file=sys.stderr)
        return 2

    eslint_cmd = shlex.split(args.eslint_cmd) + [args.target, "--format", "json"]
    eslint_result = run_command(eslint_cmd, cwd=fixture_root)
    if eslint_result.returncode not in (0, 1):
        print("ESLint CLI failed:", file=sys.stderr)
        sys.stderr.write(eslint_result.stdout)
        sys.stderr.write(eslint_result.stderr)
        return eslint_result.returncode

    init_path = resolve_repo_path(args.init)
    collector_path = resolve_repo_path(args.collector)

    collector_expr = (
        "lua local collector = dofile(%r); collector.collect({ timeout = %d })"
        % (str(collector_path), args.timeout)
    )

    headless_cmd = (
        shlex.split(args.nvim_cmd)
        + [
            "--headless",
            "-u",
            str(init_path),
            str(target_path),
            f"+{collector_expr}",
            "+qa",
        ]
    )
    headless_result = run_command(headless_cmd, cwd=repo_root)
    if headless_result.returncode != 0:
        print("Headless Neovim run failed:", file=sys.stderr)
        sys.stderr.write(headless_result.stdout)
        sys.stderr.write(headless_result.stderr)
        return headless_result.returncode

    try:
        eslint_json = load_json(eslint_result.stdout, label="ESLint CLI")
    except ValueError as exc:
        print(exc, file=sys.stderr)
        return 1

    headless_output = headless_result.stdout if headless_result.stdout.strip() else headless_result.stderr
    try:
        headless_json = load_json(headless_output, label="headless collector")
    except ValueError as exc:
        print(exc, file=sys.stderr)
        return 1

    canonical_cli = canonicalize(eslint_json)
    canonical_headless = canonicalize(headless_json)

    print("=== ESLint CLI JSON ===")
    print(json.dumps(eslint_json, indent=2, ensure_ascii=False))
    print("=== Headless Neovim JSON ===")
    print(json.dumps(headless_json, indent=2, ensure_ascii=False))
    print("=== Canonical comparison ===")
    print(json.dumps({"cli": canonical_cli, "headless": canonical_headless}, indent=2, ensure_ascii=False))

    if canonical_cli == canonical_headless:
        print("SUCCESS: headless Neovim diagnostics match ESLint CLI output")
        return 0

    print("FAILURE: headless Neovim diagnostics differ from ESLint CLI output", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
