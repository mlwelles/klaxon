#!/bin/bash
#
# Builds and launches a local copy of Klaxon for development.
#
# Two things need overriding for this to work outside the maintainer's machine:
# the project pins a DEVELOPMENT_TEAM that other people have no certificate for,
# and the bundle id is shared with the released app, so an unmodified local build
# would take over the release's calendar permission.
#

set -euo pipefail

cd "$(dirname "$0")/.."

CONFIGURATION="${CONFIGURATION:-Debug}"
BUNDLE_ID="${BUNDLE_ID:-nyc.welles.Klaxon.dev}"
BUNDLE_NAME="${BUNDLE_NAME:-Klaxon Dev}"
DERIVED_DATA="${DERIVED_DATA:-build}"

# Sign with whatever Apple Development identity is in the keychain, rather than
# the team the project is pinned to. Ad-hoc signing also runs locally.
SIGN_IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning \
    | sed -n 's/.*"\(Apple Development: .*\)"/\1/p' | head -1)}"

if [ -n "$SIGN_IDENTITY" ]; then
    TEAM_ID=$(security find-certificate -c "$SIGN_IDENTITY" -p \
        | openssl x509 -noout -subject | sed -n 's/.*OU=\([A-Z0-9]*\).*/\1/p')
else
    echo "No Apple Development identity in the keychain, signing ad-hoc"
    SIGN_IDENTITY="-"
    TEAM_ID=""
fi

echo "Building $CONFIGURATION as $BUNDLE_ID, signed by: $SIGN_IDENTITY"

xcodebuild -project Klaxon.xcodeproj -scheme Klaxon -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -quiet \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    PROVISIONING_PROFILE_SPECIFIER="" \
    build

APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/Klaxon.app"

# Sources/Info.plist hardcodes CFBundleIdentifier, so PRODUCT_BUNDLE_IDENTIFIER
# on the xcodebuild line is ignored and the id has to be rewritten here. The
# separate id gives this build its own calendar permission and preferences,
# leaving an installed release alone.
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $BUNDLE_NAME" "$APP/Contents/Info.plist"
codesign --force --sign "$SIGN_IDENTITY" --entitlements Sources/Klaxon.entitlements "$APP"

# Replace an earlier local run, leaving any installed release running.
pkill -f "$PWD/.*Klaxon.app/Contents/MacOS/Klaxon" || true

open "$APP"

echo
echo "Klaxon is running in the menu bar (no dock icon). Click the bell icon"
echo "for Preferences. Expect a calendar access prompt on first launch."
