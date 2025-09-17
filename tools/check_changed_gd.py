#!/usr/bin/env python3
"""Run `godot --check` on every GDScript file in the project.

The script walks the Godot project directory and executes Godot's `--check`
command for each `.gd` file that it finds. It is meant to be invoked from the
repository root (directly or via the check scripts) so the `--path` flag can
point to the Godot project directory.
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from typing import List, Sequence


WARNING_PATTERN = re.compile(r"^\s*(?:WARNING|ERROR|SCRIPT ERROR):", re.MULTILINE)


def contains_warning_or_error(text: str) -> bool:
    """Return True if *text* includes Godot warnings or errors."""

    return bool(WARNING_PATTERN.search(text))


def collect_gd_scripts(repo_root: str, project_dir: str) -> List[str]:
    """Collect every `.gd` file under *project_dir* relative to *repo_root*."""
    abs_project = os.path.abspath(os.path.join(repo_root, project_dir))
    if not os.path.isdir(abs_project):
        return []

    scripts: List[str] = []
    for root_dir, _, filenames in os.walk(abs_project):
        for name in filenames:
            if not name.endswith(".gd"):
                continue
            absolute_path = os.path.join(root_dir, name)
            relative_path = os.path.relpath(absolute_path, repo_root)
            scripts.append(relative_path.replace(os.sep, "/"))

    scripts.sort()
    return scripts


def resolve_godot_binary(user_provided: str | None) -> str:
    """Resolve the path to the Godot binary."""
    candidates: Sequence[str | None] = (
        user_provided,
        os.environ.get("GODOT_BIN"),
        os.environ.get("GODOT_EXE"),
        shutil.which("godot"),
        shutil.which("godot4"),
    )
    for candidate in candidates:
        if candidate:
            return candidate
    raise RuntimeError(
        "Godot binary not found. Set GODOT_BIN/GODOT_EXE or pass --godot explicitly."
    )


def run_checks(
    godot: str,
    project_dir: str,
    repo_root: str,
    files: Sequence[str],
    quiet: bool = False,
) -> int:
    """Run `godot --check` for each script in *files*.

    Returns the first non-zero exit code produced by Godot or zero if all checks
    pass.
    """
    if not files:
        if not quiet:
            print("[check] No GDScript files detected.")
        return 0

    abs_project_dir = os.path.abspath(project_dir)
    env = os.environ.copy()
    env.setdefault("CI_AUTO_QUIT", "1")

    for relative_path in files:
        absolute_script = os.path.abspath(os.path.join(repo_root, relative_path))
        if not os.path.exists(absolute_script):
            print(f"[check] Skipping missing script: {relative_path}")
            continue

        rel_to_project = os.path.relpath(absolute_script, abs_project_dir)
        res_path = f"res://{rel_to_project.replace(os.sep, '/')}"
        print(f"[check] Running --check for {res_path}")
        command = [
            godot,
            "--headless",
            "--path",
            abs_project_dir,
            "--check",
            absolute_script,
        ]
        try:
            completed = subprocess.run(
                command,
                check=False,
                env=env,
                capture_output=True,
                text=True,
            )
        except FileNotFoundError:
            print(
                f"[check] Error: unable to execute Godot binary at {godot}",
                file=sys.stderr,
            )
            return 1

        if completed.stdout:
            print(completed.stdout, end="")
        if completed.stderr:
            sys.stderr.write(completed.stderr)
        if completed.returncode != 0:
            print(
                f"[check] Error: Godot reported issues for {relative_path} (exit {completed.returncode}).",
                file=sys.stderr,
            )
            return completed.returncode

        combined_output = (completed.stdout or "") + (completed.stderr or "")
        if contains_warning_or_error(combined_output):
            print(
                f"[check] Error: Godot produced warnings/errors for {relative_path}.",
                file=sys.stderr,
            )
            return 1

    return 0


def parse_arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project-dir",
        default="game",
        help="Path to the Godot project directory (default: game).",
    )
    parser.add_argument(
        "--repo-root",
        default=os.path.join(os.path.dirname(__file__), os.pardir),
        help="Repository root that contains the Godot project (default: script parent).",
    )
    parser.add_argument(
        "--godot",
        default=None,
        help="Path to the Godot executable. Falls back to GODOT_BIN/GODOT_EXE or PATH lookup.",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Do not print messages when no scripts require checking.",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="Print the detected script paths and exit without running Godot.",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_arguments(sys.argv[1:] if argv is None else argv)
    repo_root = os.path.abspath(args.repo_root)
    project_dir = os.path.abspath(os.path.join(repo_root, args.project_dir))

    scripts = collect_gd_scripts(repo_root, args.project_dir)

    if args.list:
        for script in scripts:
            print(script)
        return 0

    if not scripts:
        if not args.quiet:
            print("[check] No GDScript files detected.")
        return 0

    try:
        godot_binary = resolve_godot_binary(args.godot)
    except RuntimeError as error:
        print(f"[check] Error: {error}", file=sys.stderr)
        return 1

    return run_checks(godot_binary, project_dir, repo_root, scripts, quiet=args.quiet)


if __name__ == "__main__":  # pragma: no cover - entry point
    sys.exit(main())

