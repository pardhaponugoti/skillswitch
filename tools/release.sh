#!/bin/bash
# Signs, notarizes, and packages SkillSwitch for direct distribution.
#
# One-time setup (needs an Apple Developer account):
#   1. In Xcode or developer.apple.com, create a "Developer ID Application"
#      certificate and install it in your keychain.
#   2. Store notarization credentials:
#        xcrun notarytool store-credentials skillswitch \
#          --apple-id you@example.com --team-id YOURTEAMID
#
# Then: ./tools/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${SKILLSWITCH_SIGN_IDENTITY:-Developer ID Application}"
PROFILE="${SKILLSWITCH_NOTARY_PROFILE:-skillswitch}"

if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo "No 'Developer ID Application' certificate in the keychain." >&2
    echo "Join the Apple Developer Program, create one, then re-run." >&2
    exit 1
fi

./build-app.sh
APP="build/SkillSwitch.app"

codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

ditto -c -k --keepParent "$APP" build/SkillSwitch-notarize.zip
xcrun notarytool submit build/SkillSwitch-notarize.zip --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
rm -f build/SkillSwitch-notarize.zip

./tools/make-dmg.sh
echo "Ready to ship: build/SkillSwitch.dmg (signed, notarized, stapled)"
