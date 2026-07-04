#!/bin/bash
# Builds SkillSwitch.app from the SPM executable.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

[ -f Assets/AppIcon.icns ] || ./tools/make-icns.sh

APP="build/SkillSwitch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/SkillSwitch "$APP/Contents/MacOS/SkillSwitch"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>SkillSwitch</string>
  <key>CFBundleDisplayName</key><string>SkillSwitch</string>
  <key>CFBundleIdentifier</key><string>cc.skillswitch.SkillSwitch</string>
  <key>CFBundleExecutable</key><string>SkillSwitch</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.3.0</string>
  <key>CFBundleVersion</key><string>3</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHumanReadableCopyright</key><string>© 2026 Pardha Ponugoti</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "Built: $APP"
