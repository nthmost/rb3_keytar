#!/usr/bin/env bash
# Sign + notarize for distribution to other Macs. STUB — fill in when needed.
#
# Prerequisites (one-time):
#   - Paid Apple Developer account
#   - A "Developer ID Application" certificate in your login keychain
#   - A notarytool keychain profile:
#       xcrun notarytool store-credentials MACAPP_NOTARY \
#         --apple-id you@example.com --team-id TEAMID --password APP_SPECIFIC_PW
#
# Then set DEV_ID below and run:  scripts/sign.sh
set -euo pipefail
cd "$(dirname "$0")/.."
source app.env

DEV_ID="${DEV_ID:-Developer ID Application: YOUR NAME (TEAMID)}"
APP="build/$APP_NAME.app"
[[ -d "$APP" ]] || { echo "build first: scripts/build.sh"; exit 1; }

echo "==> Deep-signing $APP with: $DEV_ID"
codesign --force --deep --options runtime --timestamp --sign "$DEV_ID" "$APP"

ZIP="build/$APP_NAME.zip"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Submitting for notarization"
xcrun notarytool submit "$ZIP" --keychain-profile "${NOTARY_PROFILE:-MACAPP_NOTARY}" --wait

echo "==> Stapling ticket"
xcrun stapler staple "$APP"
echo "==> Done. $APP is signed, notarized, and stapled."
