# MovieDesk

Widget na pulpit macOS w stylu Liquid Glass: trzy filmy lub seriale na dziś, dobrane do
Twojego gustu z Filmwebu i dostępne w Twoich serwisach VOD, do tego małe skróty do stron.

- **Widget** (średni i duży): trzy plakaty z oceną (Filmweb, IMDb albo TMDB), skróty
  i przycisk ↻. Przycisk pokazuje kolejną trójkę — plakaty przesuwają się z prawej
  z lekkim opóźnieniem między kolumnami, a strzałka robi pełny obrót. Kliknięcie plakatu
  otwiera tytuł w serwisie, w którym jest dostępny.
- **Pasek menu**: ikona ▶︎ otwiera panel z tymi samymi tytułami; po najechaniu na plakat
  pojawia się dymek z opisem. (Widgety macOS nie obsługują najechania kursorem, dlatego
  opis jest tylko w panelu.)
- **Ustawienia** (z panelu): zakładki „Rekomendacje” i „Linki”.

## Skąd biorą się propozycje

Codziennie o północy (albo zaraz po wybudzeniu Maca) aplikacja:

1. pobiera z Filmwebu Twoje oceny filmów i seriali oraz listę „Chcę zobaczyć”,
2. dopasowuje je do TMDB (po tytule oryginalnym i roku) razem z gatunkami,
3. buduje profil gustu: które gatunki oceniasz powyżej, a które poniżej swojej średniej,
4. zbiera trzy grupy kandydatów:
   - **nowe** — rekomendacje TMDB dla ulubionych tytułów (20 ostatnio ocenionych
     i 20 losowych); ranking łączy liczbę i wagę wskazań, dopasowanie gatunków do gustu
     i ogólną jakość; wszystko, co już oceniłeś, jest pomijane,
   - **z listy „Chcę zobaczyć”** — ułożone według dopasowania do gustu,
   - **do powtórki** — ulubione ocenione ponad 5 lat temu,
5. zostawia tylko tytuły dostępne w abonamencie serwisów, do których masz linki
   (TMDB `watch/providers`, region PL, dane JustWatch),
6. dokłada ocenę (Filmweb dla tytułów z Filmwebu, IMDb przez OMDb, jeśli podasz klucz,
   w pozostałych przypadkach TMDB) i plakat, po czym zapisuje pulę ~30 tytułów
   w kontenerze App Group, z którego czyta widget.

Pierwsza synchronizacja trwa kilka minut, kolejne pobierają tylko nowości. Pamięć
podręczna leży w kontenerze aplikacji (`Application Support/MovieDesk/library-v2.json`).

Filmweb nie ma publicznego API — aplikacja korzysta z API, którego używa strona
filmweb.pl, z ciasteczkiem Twojej zalogowanej sesji. Jeśli Filmweb coś zmieni,
synchronizacja pokaże błąd w ustawieniach.

## Wymagania

- macOS 26 (Tahoe) lub nowszy, Xcode 26+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- darmowy klucz API TMDB: themoviedb.org → Ustawienia → API
- opcjonalnie darmowy klucz OMDb (oceny IMDb): omdbapi.com → API Key

## Uruchomienie

1. Utwórz lokalną konfigurację i wpisz w niej swój Team ID:

   ```bash
   cp Config/Local.xcconfig.example Config/Local.xcconfig
   ```

2. Wygeneruj projekt i otwórz go w Xcode:

   ```bash
   xcodegen && open -a Xcode MovieDesk.xcodeproj
   ```

3. Uruchom schemat **MovieDesk** (⌘R). W pasku menu pojawi się ikona ▶︎.
4. Panel → **Ustawienia** → **Rekomendacje**: wklej ciasteczko Filmwebu i klucz TMDB
   (opcjonalnie OMDb), kliknij **Synchronizuj teraz**. Włącz **Uruchamiaj przy logowaniu**,
   żeby nocna synchronizacja działała bez pamiętania o aplikacji.
5. Dodaj widget: prawy klik na pulpicie → **Edytuj widżety…** → „MovieDesk”.

## Linki i serwisy

Panel → **Ustawienia** → **Linki** → **Dodaj link**, wpisz nazwę i adres (wystarczy
`example.com`). Dodać można dowolną stronę. Linki do Netflixa, HBO Max, Prime Video,
Disney+, SkyShowtime, Apple TV+, Canal+, Playera i Polsat Box Go są rozpoznawane
(oznaczenie „VOD”) i wyznaczają, z których serwisów pochodzą propozycje. Pozostałe linki
to zwykłe skróty. Kolejność zmieniasz przeciąganiem. Średni widget pokazuje 4 pierwsze
linki, duży 8, panel w pasku menu wszystkie.

## Prywatność

W repozytorium nie ma żadnych danych osobistych. Team ID i ewentualny własny prefiks
bundle ID są w `Config/Local.xcconfig` (w `.gitignore`). Ciasteczko Filmwebu
oraz klucze TMDB/OMDb wpisujesz w aplikacji — zostają w jej ustawieniach na Twoim Macu.

## Jak to działa

```
MovieDesk.app (pasek menu)                       Widget (WidgetKit)
  o północy: Filmweb → TMDB → ranking              czyta pulę i plakaty z App Group
  zapis puli + plakatów do App Group   ────────▶   pokazuje 3 filmy (kursor w App Group)
  reloadTimelines                                   ↻ = App Intent: kursor += 3
  moviedesk://open?url=… → przeglądarka ◀──────    kliknięcie plakatu lub skrótu
```

## Struktura

```
project.yml            definicja projektu (XcodeGen)
Config/                xcconfig: Team ID, prefiks bundle ID, App Group
Shared/                modele, App Group, widoki plakatów i ikon, intencja ↻
Widget/                rozszerzenie WidgetKit
App/                   pasek menu, ustawienia, Filmweb, TMDB, silnik rekomendacji
```
