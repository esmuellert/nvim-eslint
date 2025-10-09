#!/usr/bin/env python3
"""Convenience launcher for the repository's end-to-end test suites."""

from __future__ import annotations

import argparse
import os
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Dict, List

# --- Section: Constants ---

REPO_ROOT = Path(__file__).resolve().parents[1]
SUITES = {
    "parity": Path("tests/e2e/parity/run_eslint_parity_suite.py"),
    "config-reload": Path("tests/e2e/config-reload/run_config_reload.py"),
}
TURBO_REPO_URL = "https://github.com/vercel/turborepo.git"
FIXTURE_ENV_VAR = "NVIM_ESLINT_FIXTURE"
DEFAULT_FIXTURE_ROOT = Path(os.environ.get(FIXTURE_ENV_VAR, "/workspace/turborepo"))


# --- Section: Process helpers ---


def run_command(command: List[str], *, cwd: Path | None = None) -> None:
    """Execute a subprocess and raise on failure."""

    print("Command:", " ".join(shlex.quote(part) for part in command))
    result = subprocess.run(command, cwd=cwd)
    if result.returncode != 0:
        raise RuntimeError(
            f"Command {' '.join(shlex.quote(part) for part in command)} failed with exit code {result.returncode}"
        )


def ensure_fixture_root() -> Path:
    """Clone or reset the turborepo fixture and install dependencies."""

    fixture_root = DEFAULT_FIXTURE_ROOT.resolve()
    fixture_root.parent.mkdir(parents=True, exist_ok=True)

    if fixture_root.exists():
        print(f"Resetting existing Turborepo fixture at {fixture_root}")
        run_command(["git", "reset", "--hard", "HEAD"], cwd=fixture_root)
        run_command(["git", "clean", "-fd"], cwd=fixture_root)
    else:
        print(f"Cloning Turborepo fixture into {fixture_root}")
        run_command(["git", "clone", "--depth", "1", TURBO_REPO_URL, str(fixture_root)])

    print("Installing Turborepo dependencies via pnpm")
    run_command(["pnpm", "install", "--frozen-lockfile"], cwd=fixture_root)
    return fixture_root


def reset_fixture(fixture_root: Path) -> None:
    """Return the Turborepo workspace to a clean state."""

    if not fixture_root.exists():
        return
    run_command(["git", "reset", "--hard", "HEAD"], cwd=fixture_root)
    run_command(["git", "clean", "-fd"], cwd=fixture_root)


# --- Section: Argument parsing ---


def parse_args(argv: List[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run one or more end-to-end test suites. Defaults to executing every suite.",
    )
    parser.add_argument(
        "--suite",
        action="append",
        dest="suites",
        choices=sorted(SUITES.keys()),
        help="Subset of suites to run (default: all).",
    )
    parser.add_argument(
        "--suite-arg",
        action="append",
        dest="suite_args",
        metavar="SUITE=ARGS",
        help=(
            "Additional arguments forwarded to a specific suite. Repeat the flag for multiple suites or options, "
            "for example: --suite-arg parity='--skip-seed --timeout 10000'."
        ),
    )
    parser.add_argument(
        "--stop-on-failure",
        action="store_true",
        help="Abort remaining suites after the first failure.",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List available suites and exit.",
    )
    return parser.parse_args(argv)


# --- Section: Suite argument parsing ---


def parse_suite_args(raw: List[str] | None) -> Dict[str, List[str]]:
    parsed: Dict[str, List[str]] = {name: [] for name in SUITES}
    if not raw:
        return parsed

    for entry in raw:
        if "=" not in entry:
            raise SystemExit(f"Invalid --suite-arg value '{entry}'. Expected format 'suite=arguments'.")
        suite_name, _, value = entry.partition("=")
        suite_name = suite_name.strip()
        if suite_name not in SUITES:
            raise SystemExit(f"Unknown suite '{suite_name}' supplied via --suite-arg.")
        value = value.strip()
        if not value:
            continue
        parsed[suite_name].extend(shlex.split(value))
    return parsed


# --- Section: Suite execution ---


def run_suite(suite: str, extra_args: List[str], *, env: Dict[str, str]) -> int:
    script_path = REPO_ROOT / SUITES[suite]
    command = [sys.executable, str(script_path)] + extra_args
    print("==============================")
    print(f"Suite: {suite}")
    print("Python:", " ".join(shlex.quote(part) for part in command))
    print("==============================")
    result = subprocess.run(command, cwd=REPO_ROOT, env=env)
    return result.returncode


# --- Section: Entry point ---


def main(argv: List[str] | None = None) -> int:
    args = parse_args(argv)

    if args.list:
        print("Available suites:")
        for name in sorted(SUITES):
            print(f" - {name}: {SUITES[name]}")
        return 0

    suite_args = parse_suite_args(args.suite_args)

    selected = args.suites or sorted(SUITES.keys())
    failures: List[str] = []

    try:
        fixture_root = ensure_fixture_root()
    except RuntimeError as exc:
        print(exc, file=sys.stderr)
        return 1

    env = os.environ.copy()
    env.setdefault(FIXTURE_ENV_VAR, str(fixture_root))

    for suite in selected:
        reset_fixture(fixture_root)
        status = run_suite(suite, suite_args[suite], env=env)
        reset_fixture(fixture_root)
        if status != 0:
            print(f"Suite '{suite}' failed with exit code {status}", file=sys.stderr)
            failures.append(suite)
            if args.stop_on_failure:
                break

    if failures:
        print("", file=sys.stderr)
        print("Failed suites:", file=sys.stderr)
        for name in failures:
            print(f" - {name}", file=sys.stderr)
        return 1

    print("All suites completed successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
