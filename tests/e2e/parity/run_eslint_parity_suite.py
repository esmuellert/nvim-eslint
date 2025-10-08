#!/usr/bin/env python3
"""Seed ESLint violations and verify Neovim parity across multiple files."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path
from typing import List

SCRIPT_DIR = Path(__file__).resolve().parent
SEED_SCRIPT = SCRIPT_DIR / "seed_eslint_errors.py"
PARITY_SCRIPT = SCRIPT_DIR / "run_eslint_parity.py"

DEFAULT_TARGETS = [
    "packages/create-turbo/src/cli.ts",
    "packages/turbo-workspaces/src/cli.ts",
    "packages/turbo-telemetry/src/cli.ts",
    "packages/turbo-codemod/src/cli.ts",
    "packages/turbo-gen/src/cli.ts",
]


def run_command(command: List[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, text=True, capture_output=True)


def parse_args(argv: List[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Inject ESLint violations into multiple files and compare CLI output with headless Neovim diagnostics.",
    )
    parser.add_argument(
        "--fixture-root",
        default=os.environ.get("NVIM_ESLINT_FIXTURE", "/workspace/turborepo"),
        help="Path to the sample repository to lint.",
    )
    parser.add_argument(
        "--targets",
        nargs="+",
        default=DEFAULT_TARGETS,
        help="Relative paths (from fixture root) of the files to seed and lint.",
    )
    parser.add_argument(
        "--errors",
        nargs="+",
        help="Subset of ESLint violations to inject before linting.",
    )
    parser.add_argument(
        "--eslint-cmd",
        default="pnpm exec eslint",
        help="Command used to invoke the ESLint CLI.",
    )
    parser.add_argument(
        "--nvim-cmd",
        default="nvim",
        help="Neovim executable to run in headless mode.",
    )
    parser.add_argument(
        "--init",
        default=str(SCRIPT_DIR / "headless_init.lua"),
        help="Neovim init file that loads the plugin.",
    )
    parser.add_argument(
        "--collector",
        default=str(SCRIPT_DIR / "headless_collect.lua"),
        help="Collector script executed inside Neovim to emit diagnostics.",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=20000,
        help="Timeout (ms) for the collector to wait for diagnostics.",
    )
    parser.add_argument(
        "--skip-seed",
        action="store_true",
        help="Skip injecting ESLint violations before running the parity checks.",
    )
    return parser.parse_args(argv)


def seed_errors(fixture_root: Path, target: str, errors: List[str] | None) -> None:
    target_path = fixture_root / target
    if not target_path.exists():
        raise FileNotFoundError(f"Target file {target_path} does not exist")

    command = [sys.executable, str(SEED_SCRIPT), str(target_path)]
    if errors:
        command.extend(["--errors", *errors])

    result = run_command(command)
    if result.returncode != 0:
        raise RuntimeError(
            f"Failed to seed ESLint violations for {target}:\n{result.stdout}{result.stderr}"
        )


def run_parity(fixture_root: Path, args: argparse.Namespace, target: str) -> int:
    command = [
        sys.executable,
        str(PARITY_SCRIPT),
        "--fixture-root",
        str(fixture_root),
        "--target",
        target,
        "--eslint-cmd",
        args.eslint_cmd,
        "--nvim-cmd",
        args.nvim_cmd,
        "--init",
        args.init,
        "--collector",
        args.collector,
        "--timeout",
        str(args.timeout),
    ]
    result = run_command(command)
    if result.stdout:
        sys.stdout.write(result.stdout)
    if result.stderr:
        sys.stderr.write(result.stderr)
    return result.returncode


def main(argv: List[str] | None = None) -> int:
    args = parse_args(argv)
    fixture_root = Path(args.fixture_root).resolve()

    if not fixture_root.exists():
        print(f"Fixture repository {fixture_root} does not exist", file=sys.stderr)
        return 2

    failures: list[str] = []
    for target in args.targets:
        print("==============================")
        print(f"Target: {target}")
        print("==============================")

        try:
            if not args.skip_seed:
                seed_errors(fixture_root, target, args.errors)
        except Exception as exc:  # noqa: BLE001
            print(f"Seeding failed for {target}: {exc}", file=sys.stderr)
            failures.append(target)
            continue

        status = run_parity(fixture_root, args, target)
        if status != 0:
            print(f"Parity check failed for {target}", file=sys.stderr)
            failures.append(target)

    if failures:
        print("", file=sys.stderr)
        print("Failed targets:", file=sys.stderr)
        for entry in failures:
            print(f" - {entry}", file=sys.stderr)
        return 1

    print("All targets matched ESLint CLI output.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
