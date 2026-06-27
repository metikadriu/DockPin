#!/usr/bin/env bash
# Generate AppIcon.icns from make_icon.swift (1024px master → all iconset sizes → icns).
set -euo pipefail
cd "$(dirname "$0")/.."

ICONSET=build/AppIcon.iconset
ICNS=resources/AppIcon.icns
MASTER=build/icon_1024.png

rm -rf build
mkdir -p "$ICONSET"

swift tools/make_icon.swift "$MASTER"

# All sizes iconutil expects
declare -a SPECS=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

for spec in "${SPECS[@]}"; do
    px="${spec%%:*}"
    name="${spec##*:}"
    sips -z "$px" "$px" "$MASTER" --out "$ICONSET/$name" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$ICNS"
echo "Built $ICNS"
