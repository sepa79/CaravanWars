#!/usr/bin/env bash
set -euo pipefail

VERSION_FILE="$(cat VERSION)"
PROJECT_VERSION="$(grep '^config/version' game/project.godot | cut -d'=' -f2 | tr -d '"')"

if [[ "$VERSION_FILE" != "$PROJECT_VERSION" ]]; then
    echo "[version] Error: VERSION ($VERSION_FILE) does not match game/project.godot ($PROJECT_VERSION)" >&2
    exit 1
fi

echo "[version] OK: $VERSION_FILE"
