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
"$SCRIPT_DIR/check_version.sh"

if [[ -n "${GODOT_BIN:-}" ]]; then
  GODOT="$GODOT_BIN"
else
  GODOT="$(command -v godot || true)"
fi

if [[ -z "$GODOT" ]]; then
  echo "[check] Error: Godot binary not found. Set GODOT_BIN or add 'godot' to PATH." >&2
  exit 1
fi

echo "[check] Using Godot: $GODOT"
echo "[check] Project: $PROJECT_DIR"

run_check_only() {
  echo "[check] Running --check-only"
  CI_AUTO_QUIT=1 "$GODOT" --headless --check-only --path "$PROJECT_DIR"
}

run_game() {
  echo "[check] Running game with CI auto quit"
  CI_AUTO_QUIT=1 "$GODOT" --headless --path "$PROJECT_DIR"
}

case "$MODE" in
  check) run_check_only ;;
  both) run_check_only; run_game ;;
  game) run_check_only; run_game ;;
  *) echo "[check] Unknown mode: $MODE (use: both|game|check)" >&2; exit 2 ;;
esac

echo "[check] OK"

