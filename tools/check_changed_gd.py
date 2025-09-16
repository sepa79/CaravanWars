#!/usr/bin/env python3
"""Run `godot --check` on new and modified GDScript files.

This script inspects the Git working tree for `.gd` files that are new or
modified and runs Godot's `--check` command on each of them. It is meant to be
invoked from the repository root (directly or via the check scripts) so the
`--path` flag can point to the Godot project directory.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from typing import List, Sequence, Set


def is_git_repository(repo_root: str) -> bool:
    """Return True if *repo_root* is inside a Git working tree."""
    try:
        result = subprocess.run(
            ["git", "-C", repo_root, "rev-parse", "--is-inside-work-tree"],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except FileNotFoundError:
        return False
    return result.returncode == 0 and result.stdout.strip() == "true"


def collect_changed_gd(repo_root: str, project_dir: str) -> List[str]:
    """Collect new or modified `.gd` files under *project_dir*.

    The function inspects the working tree status so it captures both staged and
    unstaged files, including untracked ones.
    """
    if not is_git_repository(repo_root):
        return []

    abs_project = os.path.abspath(os.path.join(repo_root, project_dir))
    try:
        relative_project = os.path.relpath(abs_project, repo_root)
    except ValueError:
        relative_project = project_dir

    if relative_project.startswith(".."):
        normalized_project = "."
    else:
        normalized_project = relative_project.replace("\\", "/")

    pathspec = normalized_project if normalized_project not in {"", "."} else "."

    try:
        result = subprocess.run(
            [
                "git",
                "-C",
                repo_root,
                "status",
                "--porcelain=v1",
                "-z",
                "--",
                pathspec,
            ],
            check=True,
            stdout=subprocess.PIPE,
        )
    except subprocess.CalledProcessError as exc:  # pragma: no cover - defensive
        print(
            "[check] Warning: unable to inspect Git status; skipping per-script checks.",
            file=sys.stderr,
        )
        if exc.stderr:
            sys.stderr.write(exc.stderr)
        return []

    entries = result.stdout.split(b"\0")
    files: List[str] = []
    seen: Set[str] = set()
    index = 0

    while index < len(entries):
        entry = entries[index]
        index += 1
        if not entry:
            continue

        status_bytes = entry[:2]
        status = status_bytes.decode("utf-8", errors="ignore")
        path_fragment = entry[3:].decode("utf-8", errors="ignore")

        # For renames/copies Git emits: entry -> new_path
        if status.startswith("R") or status.startswith("C"):
            if index < len(entries):
                new_path = entries[index].decode("utf-8", errors="ignore")
                index += 1
                path_fragment = new_path

        include = False
        if status == "??":
            include = True
        else:
            index_status = status[0]
            worktree_status = status[1] if len(status) > 1 else ""
            include = any(flag in {"A", "M", "R", "C"} for flag in (index_status, worktree_status))

        if not include:
            continue

        normalized = path_fragment.replace("\\", "/")
        if not normalized.endswith(".gd"):
            continue

        if normalized not in seen:
            seen.add(normalized)
            files.append(normalized)

    files.sort()
    return files


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
            print("[check] No new or modified GDScript files detected.")
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
            completed = subprocess.run(command, check=False, env=env)
        except FileNotFoundError:
            print(
                f"[check] Error: unable to execute Godot binary at {godot}",
                file=sys.stderr,
            )
            return 1

        if completed.returncode != 0:
            print(
                f"[check] Error: Godot reported issues for {relative_path} (exit {completed.returncode}).",
                file=sys.stderr,
            )
            return completed.returncode

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

    changed_scripts = collect_changed_gd(repo_root, args.project_dir)

    if args.list:
        for script in changed_scripts:
            print(script)
        return 0

    if not changed_scripts:
        if not args.quiet:
            print("[check] No new or modified GDScript files detected.")
        return 0

    try:
        godot_binary = resolve_godot_binary(args.godot)
    except RuntimeError as error:
        print(f"[check] Error: {error}", file=sys.stderr)
        return 1

    return run_checks(godot_binary, project_dir, repo_root, changed_scripts, quiet=args.quiet)


if __name__ == "__main__":  # pragma: no cover - entry point
    sys.exit(main())
