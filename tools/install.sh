#!/usr/bin/env bash
# Install DockPin.app into /Applications and register it with Launch Services.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="$(pwd)/DockPin.app"
DEST="/Applications/DockPin.app"

if [[ ! -d "$SRC" ]]; then
    echo "DockPin.app not built yet. Running build.sh first."
    ./build.sh
fi

# Quit any running copy (old path or new) before replacing.
pkill -f "DockPin.app/Contents/MacOS/DockPin" || true
sleep 1

# Replace (admin users can write /Applications without sudo).
rm -rf "$DEST"
cp -R "$SRC" "$DEST"

# Refresh signature in place (paranoia: ensures Gatekeeper sees the new location cleanly).
codesign --force --sign - --timestamp=none --options runtime "$DEST"

# Force Launch Services to register the bundle so Spotlight + Launchpad find it.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
"$LSREGISTER" -f "$DEST"

# Ad-hoc signatures change with every rebuild, which invalidates the existing
# TCC Accessibility grant. Reset it so the app reliably re-prompts on launch
# instead of silently failing.
tccutil reset Accessibility com.meti.dockpin >/dev/null 2>&1 || true

# Launch from the new location.
open "$DEST"

cat <<EOF

Installed: $DEST
Shows up in Launchpad, Spotlight, and Cmd-Tab.

⚠  Accessibility permission was reset (the rebuild changed the signature).
    macOS should prompt you on launch — click "Open System Settings",
    then toggle DockPin on. Until you do, the menu bar icon will show
    a slashed pin and the Dock will keep following your cursor.
EOF
