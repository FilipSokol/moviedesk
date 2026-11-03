#!/usr/bin/env bash
# Czyści stare rejestracje widgetów MovieDesk. macOS pamięta rozszerzenie z każdej kopii
# aplikacji, jaką kiedykolwiek uruchomiłeś (buildy z Xcode, stary identyfikator) i potrafi
# pokazywać w galerii starą wersję zamiast nowej. Zostawia tylko /Applications/MovieDesk.app.
set -uo pipefail

KEEP="/Applications/MovieDesk.app"

list() {
  pluginkit -m -v -p com.apple.widgetkit-extension 2>/dev/null | grep -i moviedesk
}

echo "Zarejestrowane widgety MovieDesk:"
list | sed 's/^/  /' || true
[[ -n "$(list)" ]] || echo "  (brak)"

list | awk -F'\t' '{print $NF}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  if [[ "$path" != "$KEEP"* ]]; then
    echo "→ Wyrejestrowuję starą kopię: $path"
    pluginkit -r "$path" 2>/dev/null || true
  fi
done

# Kopie z buildów Xcode (Debug) — to one najczęściej „wygrywają” z wersją z /Applications.
rm -rf "$HOME"/Library/Developer/Xcode/DerivedData/MovieDesk-* 2>/dev/null || true

if [[ -d "$KEEP/Contents/PlugIns/MovieDeskWidget.appex" ]]; then
  pluginkit -a "$KEEP/Contents/PlugIns/MovieDeskWidget.appex" 2>/dev/null || true
fi

# Inne kopie aplikacji na dysku (do ręcznego usunięcia, jeśli są).
others=$(mdfind 'kMDItemFSName == "MovieDesk.app"' 2>/dev/null | grep -v "^$KEEP$" | grep -v "/build/Build/Products/" || true)
if [[ -n "$others" ]]; then
  echo "Znalazłem inne kopie MovieDesk.app — usuń je, jeśli nie są potrzebne:"
  echo "$others" | sed 's/^/  /'
fi

# Przeładowanie usług widgetów.
killall chronod 2>/dev/null || true
killall NotificationCenter 2>/dev/null || true

echo "✓ Gotowe. Usuń stare widgety z pulpitu i dodaj nowe: prawy klik → Edytuj widżety… → MovieDesk."
