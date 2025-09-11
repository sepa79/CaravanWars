#!/usr/bin/env bash
set -euo pipefail

# Godot headless check for Linux/macOS.
# Usage: tools/check.sh [project_dir] [mode]
# If project_dir is omitted, pass mode as the first argument.
# mode: game (default) | both
# check and quick modes have been deprecated in favor of the CI auto-quit game run

PROJECT_DIR="${1:-game}"
MODE="${2:-game}"
if [[ "$PROJECT_DIR" == "both" || "$PROJECT_DIR" == "game" ]]; then
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

#run_check_only() {
#  echo "[check] Running --check-only"
#  "$GODOT" --headless --check-only --path "$PROJECT_DIR"
#}

#run_quick_boot() {
#  echo "[check] Running quick boot (1 frame)"
#  "$GODOT" --headless --quit-after 1 --path "$PROJECT_DIR"
#}

run_game() {
  echo "[check] Running game with CI auto quit"
  CI_AUTO_QUIT=1 "$GODOT" --headless --path "$PROJECT_DIR"
}

case "$MODE" in
#  check) run_check_only ;;
#  quick) run_quick_boot ;;
  both) run_game ;;
  game) run_game ;;
  *) echo "[check] Unknown mode: $MODE (use: both|game)" >&2; exit 2 ;;
esac

echo "[check] OK"

