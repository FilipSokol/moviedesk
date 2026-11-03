# MovieDesk

Widgety na pulpit macOS w stylu Liquid Glass: filmy i seriale na dziś, dobrane do Twojego
gustu z Filmwebu i dostępne w Twoich serwisach VOD, do tego skróty do stron.

## Widgety

| Widget | Rozmiary | Co robi |
|---|---|---|
| **Jeden na dziś** | mały, średni, duży | Jeden tytuł w dużym formacie: kadr, plakat, opis, ocena, „bo lubisz …”. Duży ma pasek „Dalej” — kliknięcie miniatury przenosi ją na główne miejsce — i „Skończysz ok. 22:41”. |
| **Na dziś** | średni, duży | Trzy tytuły obok siebie. Duży ma pod każdym przyciski: inny tytuł, nie pokazuj więcej, zapisz na później. |
| **Wieczór** | bardzo duży | Propozycja na wieczór na całym kadrze + kolejka „Dalej” z 4 tytułami. |
| **Skróty** | mały, średni | Same linki, większe i z nazwami. |

Każdy widget z propozycjami ma ustawienia („Edytuj widżet”): **Rodzaj** (filmy / seriale),
**Źródło** (w Twoim guście / z listy „Chcę zobaczyć” / do powtórki / zapisane) i **Serwis**.
Widgety o tych samych ustawieniach przewijają się razem; różne ustawienia — niezależnie.

Akcje i animacje:
- **↻ / ⏭** — nowe tytuły wjeżdżają z prawej, kolumna po kolumnie; strzałka robi pełny obrót.
- **Nie pokazuj więcej** — tytuł znika ze wszystkich widgetów i z przyszłych propozycji,
  na jego miejsce wskakuje następny; przez 8 sekund widać „Ukryto · Cofnij”.
- **Zapisz na później** — tytuł trafia do „Zapisanych” (filtr w widgecie, pasek w panelu)
  i zostaje, nawet gdy wypadnie z puli.
- Kliknięcie plakatu otwiera tytuł w serwisie, w którym jest dostępny.

W panelu z paska menu (ikona ▶︎) są te same trzy tytuły co w domyślnym widgecie „Na dziś”,
dymek z opisem po najechaniu, a pod prawym klikiem: inny tytuł, zapisz, „już obejrzane”,
nie pokazuj więcej. Ukryte i zapisane tytuły przywrócisz w ustawieniach.

## Skąd biorą się propozycje

Codziennie o północy (albo zaraz po wybudzeniu Maca) aplikacja:

1. pobiera z Filmwebu (przez zalogowaną sesję w aplikacji) Twoje oceny filmów i seriali
   oraz listę „Chcę zobaczyć”,
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
6. dokłada szczegóły (rok, gatunki, długość, sezony, kadr), ocenę (Filmweb dla tytułów
   z Filmwebu, IMDb przez OMDb, jeśli podasz klucz, w pozostałych przypadkach TMDB)
   i plakat, po czym zapisuje pulę ~60 tytułów w kontenerze App Group.

Tytuły ukryte w widgetach nie wracają. Gdy synchronizacja się nie uda (np. brak sieci
po wybudzeniu), ponawia się po 5, 15 i 60 minutach; jeśli dane są starsze niż półtorej
doby, widget pokazuje „Dane sprzed N dni · odśwież”.

Pierwsza synchronizacja trwa kilka minut; kolejne są szybkie, bo tytuły i dopasowania
do TMDB są zapamiętane (oceny pobierają się w całości, bo mogą się zmieniać). Pamięć
podręczna leży w kontenerze aplikacji (`Application Support/MovieDesk/library-v2.json`).

Filmweb nie ma publicznego API — aplikacja korzysta z API, którego używa strona
filmweb.pl. Logujesz się raz, w okienku Filmwebu w aplikacji (Ustawienia → Filmweb →
Zaloguj się…); sesja leży w magazynie WebKitu aplikacji. Token Filmwebu żyje ok. 15 minut,
ale strona sama go odnawia z długowiecznego ciasteczka logowania, więc nic nie wklejasz
i niczego nie odświeżasz ręcznie. Gdy Filmweb Cię wyloguje, ustawienia poproszą
o ponowne zalogowanie.

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
4. Panel → **Ustawienia** → **Rekomendacje**: **Zaloguj się…** do Filmwebu, wklej klucz
   TMDB (opcjonalnie OMDb), kliknij **Synchronizuj teraz**. Włącz **Uruchamiaj przy logowaniu**,
   żeby nocna synchronizacja działała bez pamiętania o aplikacji.
5. Dodaj widgety: prawy klik na pulpicie → **Edytuj widżety…** → „MovieDesk”.
   Bez Team ID w `Config/Local.xcconfig` build zatrzyma się z czytelnym błędem.

## Linki i serwisy

Panel → **Ustawienia** → **Linki** → **+** (albo ⌘N): wklej adres (wystarczy
`example.com`), nazwa podpowie się sama. Kliknij link na liście, żeby zmienić nazwę,
adres albo kolor. Dodać można dowolną stronę. Linki do Netflixa, HBO Max, Prime Video,
Disney+, SkyShowtime, Apple TV+, Canal+, Playera i Polsat Box Go są rozpoznawane
(oznaczenie „VOD”) i wyznaczają, z których serwisów pochodzą propozycje. Pozostałe linki
to zwykłe skróty. Kolejność zmieniasz przeciąganiem. Średni widget pokazuje 4 pierwsze
linki, duży 8, panel w pasku menu wszystkie.

## Prywatność

W repozytorium nie ma żadnych danych osobistych. Team ID i ewentualny własny prefiks
bundle ID są w `Config/Local.xcconfig` (w `.gitignore`). Klucze TMDB/OMDb
wpisujesz w aplikacji — zostają w jej ustawieniach na Twoim Macu; sesja Filmwebu jest
w magazynie WebKitu aplikacji. Nic z tego nie trafia do widgetu ani do repozytorium.

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
