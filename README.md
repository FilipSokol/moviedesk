# MovieDesk

Widget na pulpit macOS w stylu Liquid Glass: trzy filmy na dziś dobrane do Twoich ocen
z Filmwebu i dostępne w Twoich serwisach, do tego małe skróty do stron.

- **Widget** (średni i duży): trzy plakaty z tytułami, skróty do serwisów i przycisk ↻.
  Przycisk pokazuje kolejną trójkę — plakaty przesuwają się z prawej z lekkim
  opóźnieniem między kolumnami, a strzałka robi pełny obrót. Kliknięcie plakatu otwiera
  wyszukiwanie filmu w serwisie, w którym jest dostępny.
- **Pasek menu**: ikona ▶︎ otwiera panel z tymi samymi filmami i wszystkimi skrótami.
- **Ustawienia** (z panelu): zakładki „Rekomendacje” i „Linki”.

## Skąd biorą się propozycje

Codziennie o północy (albo zaraz po wybudzeniu Maca) aplikacja:

1. pobiera Twoje oceny filmów z Filmwebu,
2. dopasowuje je do TMDB (po tytule oryginalnym i roku),
3. bierze losowe 40 filmów ocenionych na 8+ i zbiera dla nich rekomendacje TMDB,
   pomija wszystko, co już oceniłeś, i układa ranking (wyżej: wyższa Twoja ocena
   filmu-źródła, więcej źródeł wskazujących ten sam film),
4. osobno wybiera filmy ocenione na 8+ ponad 5 lat temu — do obejrzenia ponownie,
5. zostawia tylko filmy dostępne w abonamencie wybranych serwisów w Polsce
   (TMDB `watch/providers`, dane JustWatch),
6. zapisuje pulę ~30 filmów (dwa nowe, jeden do powtórki, i tak dalej) oraz plakaty
   do kontenera App Group, z którego czyta widget.

Pierwsza synchronizacja trwa kilka minut (pobiera wszystkie oceny i tytuły), kolejne
pobierają tylko nowości. Lokalna pamięć podręczna leży w kontenerze aplikacji
(`Application Support/MovieDesk/library.json`).

Filmweb nie ma publicznego API — aplikacja korzysta z tego samego API, którego używa
strona filmweb.pl, z ciasteczkiem Twojej zalogowanej sesji. Jeśli Filmweb coś zmieni,
synchronizacja pokaże błąd w ustawieniach.

## Wymagania

- macOS 26 (Tahoe) lub nowszy, Xcode 26+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- darmowy klucz API TMDB: themoviedb.org → Ustawienia → API

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
4. Panel → **Ustawienia** → **Rekomendacje**: wklej ciasteczko Filmwebu i klucz TMDB,
   zaznacz serwisy, kliknij **Synchronizuj teraz**. Włącz **Uruchamiaj przy logowaniu**,
   żeby nocna synchronizacja działała bez pamiętania o aplikacji.
5. Dodaj widget: prawy klik na pulpicie → **Edytuj widżety…** → „MovieDesk”.

## Linki

Panel → **Ustawienia** → **Linki** → **Dodaj link**, wpisz nazwę i adres
(wystarczy `example.com`). Kolejność zmieniasz przeciąganiem wierszy. Średni widget
pokazuje 4 pierwsze linki, duży 8, panel w pasku menu wszystkie.

## Prywatność

W repozytorium nie ma żadnych danych osobistych. Team ID i ewentualny własny prefiks
bundle ID są w `Config/Local.xcconfig` (w `.gitignore`). Ciasteczko Filmwebu i klucz TMDB
wpisujesz w aplikacji — zostają w jej ustawieniach na Twoim Macu.

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
