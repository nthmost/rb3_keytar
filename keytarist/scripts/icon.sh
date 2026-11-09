#!/usr/bin/env bash
# Generate Resources/AppIcon.icns from a square PNG (1024x1024 recommended).
# Uses ImageIO via scripts/make-icns.swift — `sips -s format icns` is unreliable
# and `iconutil` needs full Xcode, so neither is used here.
# Usage: scripts/icon.sh [path/to/icon-1024.png]
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="${1:-icon-1024.png}"
[[ -f "$SRC" ]] || { echo "error: no such file: $SRC"; exit 1; }

swift scripts/make-icns.swift "$SRC" Resources/AppIcon.icns
echo "    Rebuild the app to embed it (scripts/build.sh)."
