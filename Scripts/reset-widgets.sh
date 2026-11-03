#!/usr/bin/env bash
# Usuwa z systemu stare wersje widgetów MovieDesk, żeby w galerii była tylko aktualna.
#
# macOS pamięta rozszerzenie z każdej kopii aplikacji, jaką kiedykolwiek uruchomiłeś
# (buildy z Xcode, starszy identyfikator aplikacji), i potrafi w galerii pokazywać starą
# wersję — nawet gdy leży pod tą samą ścieżką co nowa. Skrypt:
#  1. wyrejestrowuje i blokuje każdy widget MovieDesk o innym identyfikatorze niż aktualny,
#  2. usuwa kopie z buildów Xcode,
#  3. na nowo rejestruje aktualną aplikację i restartuje usługi widgetów.
set -uo pipefail

APP="/Applications/MovieDesk.app"
APPEX="$APP/Contents/PlugIns/MovieDeskWidget.appex"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

current=""
if [[ -d "$APPEX" ]]; then
  current=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APPEX/Contents/Info.plist" 2>/dev/null || true)
fi
echo "Aktualny widget: ${current:-(brak — najpierw zainstaluj aplikację: ./Scripts/install.sh)}"

registrations() {
  pluginkit -m -A -v -p com.apple.widgetkit-extension 2>/dev/null | grep -i moviedesk || true
}

echo "Zarejestrowane widgety MovieDesk (przed):"
registrations | sed 's/^/  /'

# Każda linia: "  <id>(<wersja>)<TAB><uuid><TAB><data><TAB><ścieżka>"
registrations | while IFS= read -r line; do
  # Linia może zaczynać się od „+”, „-” itp. — identyfikator to pierwsze „coś(wersja)”.
  id=$(echo "$line" | grep -oE '[A-Za-z0-9._-]+\([^)]*\)' | head -1 | sed 's/(.*//')
  path=$(echo "$line" | awk -F'\t' '{print $NF}' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  if [[ "$id" != "$current" || "$path" != "$APPEX" ]]; then
    echo "→ Usuwam starą wersję: $id  ($path)"
    [[ -n "$path" ]] && pluginkit -r "$path" 2>/dev/null
    [[ "$id" != "$current" && -n "$id" ]] && pluginkit -e ignore -i "$id" 2>/dev/null
    if [[ -n "$path" && "$path" != "$APPEX" ]]; then
      "$LSREGISTER" -u "${path%/Contents/PlugIns/*}" 2>/dev/null
    fi
  fi
done

# Kopie z buildów Xcode (Debug).
rm -rf "$HOME"/Library/Developer/Xcode/DerivedData/MovieDesk-* 2>/dev/null || true

# Aktualna wersja: rejestracja od nowa.
if [[ -n "$current" ]]; then
  "$LSREGISTER" -f -R "$APP" 2>/dev/null
  pluginkit -a "$APPEX" 2>/dev/null
  pluginkit -e use -i "$current" 2>/dev/null
fi

# Inne kopie aplikacji na dysku (do ręcznego usunięcia).
others=$(mdfind 'kMDItemFSName == "MovieDesk.app"' 2>/dev/null | grep -v "^$APP$" | grep -v "/build/Build/Products/" || true)
if [[ -n "$others" ]]; then
  echo "Inne kopie MovieDesk.app na dysku — usuń je, żeby nie wracały:"
  echo "$others" | sed 's/^/  /'
fi

# Restart usług widgetów (galeria i pulpit wczytają widgety od nowa).
killall chronod 2>/dev/null || true
killall NotificationCenter 2>/dev/null || true
killall WidgetKitExtensionHost 2>/dev/null || true

# Jeśli nowy widget się wywraca przy starcie, system pokazuje w galerii stare podglądy.
crashes=$(ls -t "$HOME/Library/Logs/DiagnosticReports" 2>/dev/null | grep -i "MovieDeskWidget" | head -3 || true)
if [[ -n "$crashes" ]]; then
  echo "⚠︎ Raporty awarii widgetu (najnowsze) — wklej pierwszy z nich, jeśli widget dalej nie działa:"
  echo "$crashes" | sed "s|^|  $HOME/Library/Logs/DiagnosticReports/|"
fi

echo "Zarejestrowane widgety MovieDesk (po):"
registrations | sed 's/^/  /'
echo "✓ Gotowe. Usuń stare widgety z pulpitu i dodaj nowe: prawy klik → Edytuj widżety… → MovieDesk."
echo "  Nowe nazywają się: „Jeden na dziś”, „Na dziś”, „Wieczór”, „Skróty”."
