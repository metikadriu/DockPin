#!/usr/bin/env bash
# Build DockPin.app — a universal, ad-hoc-signed menu bar app.
set -euo pipefail
cd "$(dirname "$0")"

APP="DockPin.app"
MACOS_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"
BIN="$MACOS_DIR/DockPin"
SRC=(src/main.swift src/AppDelegate.swift src/DisplayUtils.swift src/DockPinner.swift)
TARGET_MIN="13.0"

rm -rf "$APP" build
mkdir -p "$MACOS_DIR" "$RES_DIR" build

cp resources/Info.plist "$APP/Contents/Info.plist"

# Regenerate icon if missing, then copy it in.
if [[ ! -f resources/AppIcon.icns ]]; then
    ./tools/make_icon.sh
fi
cp resources/AppIcon.icns "$RES_DIR/AppIcon.icns"

# Universal binary so it keeps working if you ever move it to an Intel Mac.
swiftc -O -target "arm64-apple-macos${TARGET_MIN}" \
    "${SRC[@]}" \
    -framework AppKit -framework ServiceManagement -framework ApplicationServices \
    -o build/DockPin-arm64

swiftc -O -target "x86_64-apple-macos${TARGET_MIN}" \
    "${SRC[@]}" \
    -framework AppKit -framework ServiceManagement -framework ApplicationServices \
    -o build/DockPin-x86_64

lipo -create build/DockPin-arm64 build/DockPin-x86_64 -output "$BIN"
chmod +x "$BIN"

# Ad-hoc sign so Accessibility / SMAppService grants persist across launches.
codesign --force --sign - --timestamp=none --options runtime "$APP"

rm -rf build

echo
echo "Built: $(pwd)/$APP"
echo "Open with:  open '$(pwd)/$APP'"
echo "Or drag DockPin.app into /Applications if you want it there."
