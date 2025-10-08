"""Utilities for injecting common ESLint violations into TypeScript files.

The script lets the test workflow seed deterministic lint errors before
running the parity harness. Each supported violation is generated inside an
IIFE to keep the injected symbols scoped and avoid interfering with existing
code.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from textwrap import dedent


ERROR_CHOICES = (
    "unused-vars",
    "explicit-any",
    "prefer-const",
    "no-console",
    "eqeqeq",
)

BLOCK_BEGIN = "// ESLINT_ERROR_GENERATOR:BEGIN"
BLOCK_END = "// ESLINT_ERROR_GENERATOR:END"


def build_snippet(selected: list[str]) -> str:
    snippets: dict[str, str] = {
        "unused-vars": dedent(
            """\
            (() => {
              // ESLINT_ERROR unused-vars
              const ESLINT_ERROR_UNUSED = 42;
            })();
            """
        ).strip()
        + "\n",
        "explicit-any": dedent(
            """\
            (() => {
              // ESLINT_ERROR explicit-any
              const ESLINT_ERROR_EXPLICIT_ANY: any = {};

              if (typeof ESLINT_ERROR_EXPLICIT_ANY === "string") {
                throw new Error("ESLint explicit-any violation");
              }
            })();
            """
        ).strip()
        + "\n",
        "prefer-const": dedent(
            """\
            (() => {
              // ESLINT_ERROR prefer-const
              let ESLINT_ERROR_SHOULD_BE_CONST = "value";

              const useConst = () => ESLINT_ERROR_SHOULD_BE_CONST;
              useConst();
            })();
            """
        ).strip()
        + "\n",
        "no-console": dedent(
            """\
            (() => {
              // ESLINT_ERROR no-console
              console.log("ESLint no-console violation");
            })();
            """
        ).strip()
        + "\n",
        "eqeqeq": dedent(
            """\
            (() => {
              // ESLINT_ERROR eqeqeq
              if (Math.random() == 0) {
                throw new Error("ESLint eqeqeq violation");
              }
            })();
            """
        ).strip()
        + "\n",
    }

    return "".join(snippets[name] for name in selected)


def inject_errors(file_path: Path, selected: list[str]) -> None:
    if not file_path.exists():
        raise FileNotFoundError(f"Target file {file_path} does not exist")

    if file_path.suffix not in {".ts", ".tsx"}:
        raise ValueError("This helper only supports TypeScript source files")

    original = file_path.read_text()

    begin_idx = original.find(BLOCK_BEGIN)
    if begin_idx != -1:
        end_idx = original.find(BLOCK_END, begin_idx)
        if end_idx == -1:
            raise RuntimeError(
                "Found block begin marker without a matching end marker"
            )

        end_idx += len(BLOCK_END)
        if end_idx < len(original) and original[end_idx] == "\n":
            end_idx += 1
        original = original[:begin_idx] + original[end_idx:]

    snippet_body = build_snippet(selected)
    if not snippet_body:
        return

    if original and not original.endswith("\n"):
        original += "\n"

    block = [BLOCK_BEGIN, snippet_body.rstrip("\n"), BLOCK_END, ""]
    updated = original + "\n".join(block)

    file_path.write_text(updated)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Inject deterministic ESLint violations into a TypeScript file."
        )
    )
    parser.add_argument(
        "path",
        type=Path,
        help="Path to the TypeScript file that should receive the violations",
    )
    parser.add_argument(
        "--errors",
        choices=ERROR_CHOICES,
        nargs="+",
        default=list(ERROR_CHOICES),
        help=(
            "Subset of violations to generate. Defaults to seeding all supported"
            " error types."
        ),
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)

    inject_errors(args.path, list(dict.fromkeys(args.errors)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
