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

# The site's faceplate and footer etch the same "MOD." plate as the app, so
# stamp them with the shipping version. The pattern matches whatever was there
# last release, so re-stamping stays idempotent.
VERSION=$(sed -n 's:.*<key>CFBundleShortVersionString</key><string>\(.*\)</string>.*:\1:p' build-app.sh)
[ -n "$VERSION" ] || { echo "Could not read version from build-app.sh" >&2; exit 1; }
sed -E -i '' "s/MOD\. [A-Za-z0-9.-]+/MOD. $VERSION/g" docs/index.html

./build-app.sh
APP="build/SkillSwitch.app"

codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

ditto -c -k --keepParent "$APP" build/SkillSwitch-notarize.zip
xcrun notarytool submit build/SkillSwitch-notarize.zip --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
rm -f build/SkillSwitch-notarize.zip

./tools/make-dmg.sh
DMG="build/SkillSwitch.dmg"

# Notarize the DMG itself, not just the app inside it — a downloaded .dmg is
# what Gatekeeper checks first, so an un-notarized container throws a warning
# on every open even when the app within is stapled. Sign → notarize → staple
# the DMG so it opens clean for a nontechnical user with no right-click dance.
codesign --force --timestamp --sign "$IDENTITY" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
spctl -a -vv -t open --context context:primary-signature "$DMG"

echo "Ready to ship: $DMG (app + DMG signed, notarized, stapled)"
echo "docs/index.html stamped MOD. $VERSION — commit and push to update the site"
