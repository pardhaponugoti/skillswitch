#!/bin/bash
# Packages build/SkillSwitch.app into a drag-to-Applications DMG.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/SkillSwitch.app"
[ -d "$APP" ] || { echo "No $APP — run ./build-app.sh first" >&2; exit 1; }

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f build/SkillSwitch.dmg
hdiutil create -volname "SkillSwitch" -srcfolder "$STAGE" -ov -format UDZO build/SkillSwitch.dmg >/dev/null
echo "Built: build/SkillSwitch.dmg"
