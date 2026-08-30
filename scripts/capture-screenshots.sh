#!/bin/zsh
set -euo pipefail

SMN_PROJECT_ROOT="${0:A:h:h}"
SMN_APP_PATH="$SMN_PROJECT_ROOT/.build/SeguraMinhasNotas.app"
SMN_OUTPUT_DIR="$SMN_PROJECT_ROOT/docs/images"

SMN_SCENARIOS=(
  onboarding
  deck
  deck-open
  editor
  all-notes
  settings-general
  settings-appearance
  settings-sync
  settings-privacy
  settings-about
  locked
)

SMN_FILES=(
  01-onboarding.png
  02-deck-resting.png
  03-deck-open.png
  04-editor-checklists.png
  05-all-notes.png
  06-settings-general.png
  07-settings-appearance.png
  08-settings-sync.png
  09-settings-privacy.png
  10-settings-about.png
  11-protected-notes.png
)

function smn_clear_launch_environment {
  launchctl unsetenv SMN_SCREENSHOT_SCENARIO 2>/dev/null || true
  launchctl unsetenv SMN_SCREENSHOT_OUTPUT 2>/dev/null || true
  launchctl unsetenv SMN_DECK_OPEN 2>/dev/null || true
}

trap smn_clear_launch_environment EXIT INT TERM

cd "$SMN_PROJECT_ROOT"
mkdir -p "$SMN_OUTPUT_DIR"
"$SMN_PROJECT_ROOT/scripts/build-app.sh"

for (( SMN_INDEX = 1; SMN_INDEX <= ${#SMN_SCENARIOS}; SMN_INDEX++ )); do
  SMN_SCENARIO="${SMN_SCENARIOS[$SMN_INDEX]}"
  SMN_FILE="${SMN_FILES[$SMN_INDEX]}"
  SMN_DESTINATION="$SMN_OUTPUT_DIR/$SMN_FILE"

  rm -f "$SMN_DESTINATION"
  launchctl setenv SMN_SCREENSHOT_SCENARIO "$SMN_SCENARIO"
  launchctl setenv SMN_SCREENSHOT_OUTPUT "$SMN_DESTINATION"

  if [[ "$SMN_SCENARIO" == "deck-open" ]]; then
    launchctl setenv SMN_DECK_OPEN 1
  else
    launchctl unsetenv SMN_DECK_OPEN 2>/dev/null || true
  fi

  open -n "$SMN_APP_PATH" --args -AppleLanguages '(pt-BR)' -AppleLocale pt_BR
  for _ in {1..80}; do
    [[ -f "$SMN_DESTINATION" ]] && break
    sleep 0.2
  done

  if [[ ! -f "$SMN_DESTINATION" ]]; then
    print -u2 "Falha ao capturar o cenário: $SMN_SCENARIO"
    exit 1
  fi
done

print "Screenshots atualizados em $SMN_OUTPUT_DIR"
