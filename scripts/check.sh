#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
cd "$ROOT_DIR"

swift build -j 1
for strings_file in Resources/*.lproj/*.strings; do
  plutil -lint "$strings_file" >/dev/null
done
xcrun swiftc \
  -swift-version 5 \
  -module-name SeguraMinhasNotasChecks \
  "Sources/SeguraMinhasNotas/Services/Localization.swift" \
  "Sources/SeguraMinhasNotas/Models/Note.swift" \
  "Sources/SeguraMinhasNotas/Services/ChecklistSyntax.swift" \
  "Tests/SeguraMinhasNotasChecks/main.swift" \
  -o ".build/SeguraMinhasNotasChecks"
".build/SeguraMinhasNotasChecks"
