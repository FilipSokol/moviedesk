# MovieDesk — widget „Szybkie linki”

Minimalistyczny widget na pulpit macOS w stylu Liquid Glass. Każdy kafelek otwiera
stronę w domyślnej przeglądarce. Listę linków edytujesz w małej aplikacji w pasku menu.

- **Widget**: rozmiary mały (4 linki), średni (8), duży (16). W trybie pełnokolorowym
  kafelki mają delikatny tint i szklaną krawędź; w trybach przezroczystym i tintowanym
  macOS podkłada własne szkło, a inicjały przejmują kolor akcentu.
- **Pasek menu**: ikona ▶︎ otwiera panel z tymi samymi linkami (natywny `glassEffect`)
  oraz przycisk „Edytuj linki”.
- **Edytor**: nazwa, adres (`filmweb.pl` wystarczy, `https://` dopisze się samo), kolor,
  kolejność przeciąganiem. Zmiany trafiają do widgetu od razu.

## Wymagania

- macOS 26 (Tahoe) lub nowszy, Xcode 26+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Uruchomienie

1. Zainstaluj XcodeGen:

   ```bash
   brew install xcodegen
   ```

2. Wpisz swój Team ID (Xcode → Settings → Accounts; darmowe konto Apple ID też działa):

   ```bash
   cp Config/Local.xcconfig.example Config/Local.xcconfig
   ```

   i podmień `ABCDE12345` na swój identyfikator. Bez tego App Group nie zadziała
   i widget nie zobaczy Twoich linków.

3. Wygeneruj projekt i otwórz go:

   ```bash
   xcodegen && open MovieDesk.xcodeproj
   ```

4. Uruchom schemat **MovieDesk** (⌘R). W pasku menu pojawi się ikona aplikacji.
5. Dodaj widget: prawy klik na pulpicie → **Edytuj widżety…** → wyszukaj „MovieDesk”.

Po zmianie `project.yml` uruchom `xcodegen` ponownie. Plik `.xcodeproj`, `Info.plist`
i `.entitlements` są generowane i nie trafiają do repo.

## Jak to działa

```
Widget (WidgetKit)                    MovieDesk.app (pasek menu, bez ikony w Docku)
  czyta listę z App Group     ◀──────   zapisuje listę do App Group + reloadTimelines
  kafelek = Link(moviedesk://open?url=…)
                        └─────────────▶  AppDelegate (kAEGetURL) → NSWorkspace.open(url)
                                          → domyślna przeglądarka
```

- Widget nie ma dostępu do sieci i nie odświeża się sam (`policy: .never`) — przeładowuje
  go aplikacja po każdej zmianie listy.
- Kliknięcie idzie przez własny schemat `moviedesk://`, więc działa przewidywalnie
  niezależnie od tego, jak system obsługuje linki http(s) w widgetach. Gdy aplikacja nie
  jest uruchomiona, system ją wystartuje (bez otwierania okna) i przekaże adres.
- Otwierane są wyłącznie adresy `http`/`https`.

Wskazówka: dodaj MovieDesk do **Ustawienia systemowe → Ogólne → Rzeczy otwierane
podczas logowania**, żeby pierwsze kliknięcie w widget nie czekało na start aplikacji.

## Struktura

```
project.yml            definicja projektu (XcodeGen)
Config/                xcconfig: Team ID i App Group
Shared/                model linku, zapis w App Group, deep link, ikona-inicjał
Widget/                rozszerzenie WidgetKit
App/                   aplikacja w pasku menu + edytor
```
