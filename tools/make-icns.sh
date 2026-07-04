#!/bin/bash
# Regenerates Assets/AppIcon.icns from tools/make-icon.swift.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET" Assets

swift tools/make-icon.swift "$TMP/icon-1024.png"

for size in 16 32 128 256 512; do
    sips -z $size $size "$TMP/icon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z $double $double "$TMP/icon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o Assets/AppIcon.icns
echo "Built: Assets/AppIcon.icns"
