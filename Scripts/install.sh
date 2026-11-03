#!/usr/bin/env bash
# Buduje MovieDesk (Release) i instaluje w /Applications. Uruchamiasz raz po każdym
# „git pull” — na co dzień aplikacja startuje sama przy logowaniu i nic nie budujesz.
#
#   ./Scripts/install.sh            # zbuduj i zainstaluj
#   ./Scripts/install.sh --pull     # najpierw pobierz najnowszy kod (git pull)
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "${1:-}" == "--pull" ]]; then
  git pull --ff-only
fi

command -v xcodegen >/dev/null || { echo "Brak XcodeGen — zainstaluj: brew install xcodegen"; exit 1; }
command -v xcodebuild >/dev/null || { echo "Brak Xcode — zainstaluj z App Store i uruchom raz."; exit 1; }
[[ -f Config/Local.xcconfig ]] || {
  echo "Brak Config/Local.xcconfig — skopiuj Config/Local.xcconfig.example i wpisz swój Team ID."
  exit 1
}

echo "→ Generuję projekt…"
xcodegen generate --quiet

echo "→ Buduję (Release)… to chwilę potrwa"
xcodebuild \
  -project MovieDesk.xcodeproj \
  -scheme MovieDesk \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build \
  -allowProvisioningUpdates \
  -quiet \
  build

APP="build/Build/Products/Release/MovieDesk.app"
[[ -d "$APP" ]] || { echo "Nie znalazłem zbudowanej aplikacji ($APP)."; exit 1; }

echo "→ Instaluję w /Applications…"
osascript -e 'tell application id "'"$(defaults read "$PWD/$APP/Contents/Info" CFBundleIdentifier)"'" to quit' >/dev/null 2>&1 || true
pkill -x MovieDesk 2>/dev/null || true
sleep 1
rm -rf /Applications/MovieDesk.app
cp -R "$APP" /Applications/

echo "→ Odświeżam widgety…"
Scripts/reset-widgets.sh

open /Applications/MovieDesk.app

echo "✓ Gotowe. W ustawieniach MovieDesk włącz „Uruchamiaj przy logowaniu” (wystarczy raz)."
