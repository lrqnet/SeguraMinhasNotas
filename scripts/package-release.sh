#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
cd "$ROOT_DIR"

"$ROOT_DIR/scripts/build-app.sh"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Packaging/Info.plist)"
ARCHIVE="$ROOT_DIR/.build/SeguraMinhasNotas-$VERSION.zip"
rm -f "$ARCHIVE"
ditto -c -k --sequesterRsrc --keepParent "$ROOT_DIR/.build/SeguraMinhasNotas.app" "$ARCHIVE"
echo "$ARCHIVE"
