#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
SIGN_IDENTITY="${SMN_CODESIGN_IDENTITY:--}"
APP_DIR="$ROOT_DIR/.build/SeguraMinhasNotas.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
ICONSET_DIR="$ROOT_DIR/.build/AppIcon.iconset"

cd "$ROOT_DIR"
swift build -c release -debug-info-format none

rm -rf "$APP_DIR" "$ICONSET_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR" "$ICONSET_DIR"
cp ".build/release/SeguraMinhasNotas" "$MACOS_DIR/SeguraMinhasNotas"
cp "Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
ditto "Resources" "$RESOURCES_DIR"
/usr/bin/strip -S "$MACOS_DIR/SeguraMinhasNotas"

SPARKLE_FRAMEWORK="$(find "$ROOT_DIR/.build/artifacts" -name Sparkle.framework -type d -print -quit)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
  echo "Sparkle.framework não foi encontrado nos artefatos do SwiftPM." >&2
  exit 1
fi
ditto "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/Sparkle.framework"

if sips -s format png "Assets/AppIcon.svg" --out "$ROOT_DIR/.build/AppIcon-1024.png" >/dev/null 2>&1; then
  for spec in "16:icon_16x16.png" "32:icon_16x16@2x.png" "32:icon_32x32.png" "64:icon_32x32@2x.png" "128:icon_128x128.png" "256:icon_128x128@2x.png" "256:icon_256x256.png" "512:icon_256x256@2x.png" "512:icon_512x512.png" "1024:icon_512x512@2x.png"; do
    size="${spec%%:*}"
    name="${spec#*:}"
    sips -z "$size" "$size" "$ROOT_DIR/.build/AppIcon-1024.png" --out "$ICONSET_DIR/$name" >/dev/null
  done
  iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
fi

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$APP_DIR"
else
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
fi

if LC_ALL=C grep -R -a -q -F "$ROOT_DIR" "$APP_DIR"; then
  echo "O bundle contém o caminho local do diretório de build; publicação interrompida." >&2
  exit 1
fi
echo "$APP_DIR"
