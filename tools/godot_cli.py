#!/usr/bin/env python
"""
Lightweight Godot CLI wrapper for this repo.

Goal:
- Provide a simple, scriptable interface to run/check the Godot project from
  the command line, so the agent can see real Godot output without requiring
  Node/MCP on the host.

Usage examples (from repo root):
- python tools/godot_cli.py check game
- python tools/godot_cli.py quick game
- python tools/godot_cli.py run game
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from typing import List, Dict


# Repository-local default Godot path for this machine.
# Override with the GODOT_EXE env var if needed.
DEFAULT_GODOT_PATH = (
    r"C:\Users\Sepa\Downloads\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe"
)


def _find_godot_executable() -> str:
    env_path = os.environ.get("GODOT_EXE")
    if env_path and os.path.isfile(env_path):
        return env_path

    if DEFAULT_GODOT_PATH and os.path.isfile(DEFAULT_GODOT_PATH):
        return DEFAULT_GODOT_PATH

    candidate_names = [
        "Godot_v4.4.1-stable_win64.exe",
        "godot4.exe",
        "Godot.exe",
        "godot.exe",
    ]
    for name in candidate_names:
        for path_dir in os.environ.get("PATH", "").split(os.pathsep):
            exe_path = os.path.join(path_dir, name)
            if os.path.isfile(exe_path):
                return exe_path

    raise SystemExit(
        "[godot_cli] Godot executable not found. "
        "Set GODOT_EXE or add godot4.exe/Godot.exe to PATH."
    )


def _run_godot(
    godot_exe: str,
    args: List[str],
    extra_env: Dict[str, str] | None = None,
) -> int:
    cmd = [godot_exe] + args
    print(f"[godot_cli] Running: {' '.join(cmd)}", flush=True)
    env = os.environ.copy()
    if extra_env:
        env.update(extra_env)
    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        env=env,
    )
    assert process.stdout is not None
    for line in process.stdout:
        sys.stdout.write(line)
    return process.wait()


def cmd_check(project_path: str) -> int:
    godot_exe = _find_godot_executable()
    return _run_godot(
        godot_exe,
        ["--headless", "--check-only", "--path", project_path],
    )


def cmd_quick(project_path: str, frames: int = 1) -> int:
    godot_exe = _find_godot_executable()
    return _run_godot(
        godot_exe,
        ["--headless", "--quit-after", str(frames), "--path", project_path],
    )


def cmd_run(project_path: str) -> int:
    godot_exe = _find_godot_executable()
    return _run_godot(
        godot_exe,
        ["--path", project_path],
    )


def cmd_ci_single(project_path: str) -> int:
    """
    Drive the CI singleplayer flow headless:
    StartMenu -> SinglePlayer -> MapSetup -> Game -> quit.
    """
    godot_exe = _find_godot_executable()
    extra_env = {
        "CI_AUTO_SINGLEPLAYER": "1",
        "CI_AUTO_QUIT": "1",
    }
    # Limit runtime so the command does not hang indefinitely.
    return _run_godot(
        godot_exe,
        ["--headless", "--quit-after", "5", "--path", project_path],
        extra_env=extra_env,
    )


def main(argv: List[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Simple Godot CLI helper.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    p_check = subparsers.add_parser("check", help="Run Godot --check-only")
    p_check.add_argument("project", help="Project directory (e.g. game)")

    p_quick = subparsers.add_parser("quick", help="Run project briefly headless")
    p_quick.add_argument("project", help="Project directory (e.g. game)")
    p_quick.add_argument(
        "--frames",
        type=int,
        default=1,
        help="Approximate number of frames/seconds before quit (default: 1)",
    )

    p_run = subparsers.add_parser("run", help="Run project normally")
    p_run.add_argument("project", help="Project directory (e.g. game)")

    p_ci = subparsers.add_parser(
        "ci-single",
        help="Run CI singleplayer flow headless (auto SinglePlayer -> MapSetup -> Game).",
    )
    p_ci.add_argument("project", help="Project directory (e.g. game)")

    args = parser.parse_args(argv)

    if args.command == "check":
        return cmd_check(args.project)
    if args.command == "quick":
        return cmd_quick(args.project, frames=args.frames)
    if args.command == "run":
        return cmd_run(args.project)
    if args.command == "ci-single":
        return cmd_ci_single(args.project)

    parser.error(f"Unknown command: {args.command}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
