#!/usr/bin/env bash
# Compile the Swift package and assemble a launchable .app bundle.
# Works with Command Line Tools only (no full Xcode required).
set -euo pipefail
cd "$(dirname "$0")/.."          # -> app root
source app.env

CONFIG="${1:-release}"           # build.sh debug  for a faster dev build
echo "==> Building $APP_NAME ($BUNDLE_ID) [$CONFIG]"
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/App"
APP="build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"

if [[ "${MENUBAR_ONLY:-false}" == "true" ]]; then
    LSUI="<key>LSUIElement</key><true/>"
else
    LSUI=""
fi
sed -e "s|@APP_NAME@|$APP_NAME|g" \
    -e "s|@BUNDLE_ID@|$BUNDLE_ID|g" \
    -e "s|@VERSION@|${VERSION:-1.0}|g" \
    -e "s|@BUILD@|${BUILD:-1}|g" \
    -e "s|@LSUIELEMENT@|$LSUI|g" \
    Resources/Info.plist.in > "$APP/Contents/Info.plist"

[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature: required for the app to launch on Apple Silicon.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || \
    echo "warning: ad-hoc codesign failed (app may still run)"

echo "==> Built $APP"
