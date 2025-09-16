#!/usr/bin/env bash
set -euo pipefail

# Godot headless check for Linux/macOS.
# Usage: tools/check.sh [project_dir] [mode]
# If project_dir is omitted, pass mode as the first argument.
# mode: game (default) | both | check

PROJECT_DIR="${1:-game}"
MODE="${2:-game}"
if [[ $# -eq 1 && ( "$PROJECT_DIR" == "both" || "$PROJECT_DIR" == "game" || "$PROJECT_DIR" == "check" ) ]]; then
  MODE="$PROJECT_DIR"
  PROJECT_DIR="game"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
"$SCRIPT_DIR/check_version.sh"

if [[ -n "${GODOT_BIN:-}" ]]; then
  GODOT="$GODOT_BIN"
else
  if command -v godot >/dev/null 2>&1; then
    GODOT="$(command -v godot)"
  elif command -v godot4 >/dev/null 2>&1; then
    GODOT="$(command -v godot4)"
  else
    GODOT=""
  fi
fi

if [[ -z "$GODOT" ]]; then
  echo "[check] Error: Godot binary not found. Set GODOT_BIN or add 'godot' to PATH." >&2
  exit 1
fi

echo "[check] Using Godot: $GODOT"
echo "[check] Project: $PROJECT_DIR"

run_changed_script_checks() {
  local python_bin="${PYTHON_BIN:-}"
  if [[ -z "$python_bin" ]]; then
    if command -v python3 >/dev/null 2>&1; then
      python_bin="$(command -v python3)"
    elif command -v python >/dev/null 2>&1; then
      python_bin="$(command -v python)"
    else
      echo "[check] Warning: Python interpreter not found; skipping per-script Godot checks." >&2
      return 0
    fi
  fi

  local helper="$SCRIPT_DIR/check_changed_gd.py"
  if [[ ! -f "$helper" ]]; then
    echo "[check] Warning: Missing helper script check_changed_gd.py; skipping per-script checks." >&2
    return 0
  fi

  "$python_bin" "$helper" --project-dir "$PROJECT_DIR" --repo-root "$REPO_ROOT" --godot "$GODOT"
}

run_logged_command() {
  local description="$1"
  shift
  echo "[check] $description"
  local log_file
  log_file="$(mktemp)"
  set +e
  "$@" 2>&1 | tee "$log_file"
  local exit_code=${PIPESTATUS[0]}
  set -e
  if [[ $exit_code -ne 0 ]]; then
    echo "[check] Error: Command failed during $description (exit $exit_code)." >&2
    rm -f "$log_file"
    return $exit_code
  fi
  if grep -E '^[[:space:]]*(WARNING|ERROR|SCRIPT ERROR):' "$log_file" >/dev/null; then
    echo "[check] Error: Godot reported warnings/errors during $description." >&2
    rm -f "$log_file"
    return 1
  fi
  rm -f "$log_file"
}

run_check_only() {
  run_logged_command "Running --check-only" env CI_AUTO_QUIT=1 "$GODOT" --headless --check-only --path "$PROJECT_DIR"
}

run_game() {
  run_logged_command "Running game with CI auto quit" env CI_AUTO_QUIT=1 "$GODOT" --headless --path "$PROJECT_DIR"
  run_logged_command "Running map smoke test" env MAP_SMOKE_TEST=1 "$GODOT" --headless --path "$PROJECT_DIR"
}

run_changed_script_checks

case "$MODE" in
  check) run_check_only ;;
  both) run_check_only; run_game ;;
  game) run_check_only; run_game ;;
  *) echo "[check] Unknown mode: $MODE (use: both|game|check)" >&2; exit 2 ;;
esac

echo "[check] OK"

