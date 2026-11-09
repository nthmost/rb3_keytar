#!/usr/bin/env bash
# Build, then launch the app.
set -euo pipefail
cd "$(dirname "$0")/.."
source app.env
scripts/build.sh "${1:-release}"
open "build/$APP_NAME.app"
echo "==> Launched $APP_NAME"
