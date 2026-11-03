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

## Scenariusze

Przycisk scenariusza w widgecie (albo kapsułki w panelu) przełącza, czego szukamy:

| Scenariusz | Co pokazuje | Link prowadzi do |
|---|---|---|
| 👤 **Solo** | Twój gust: nowe tytuły, z listy „Chcę zobaczyć” i do powtórki — na Twoich serwisach | serwisu VOD |
| ✨ **Nowości** | najlepsze świeże filmy i seriale w Twoich serwisach z ostatniego miesiąca (premiery cyfrowe w PL, nowe odcinki); obejrzane nie znikają, tylko dostają znaczek z Twoją oceną (✓ 8) | serwisu VOD |
| 💿 **Premiery HD** | świeże filmy (ostatnie 2 lata) w Twoich ulubionych gatunkach, które mają już wydanie Blu-ray albo cyfrowe — w dobrej jakości, do kupienia | Google („tytuł rok Blu-ray”) |
| ❤️ **Randka** | na wieczór we dwoje: bez horrorów i bardzo krwawych filmów, mniej akcji i przemocy, więcej love story i dobrych dramatów/komedii — do włączenia od razu na Twoich serwisach | serwisu VOD |
| 💌 **Wspólna lista** | to samo co „Randka”, ale gdziekolwiek są dostępne | serwisu, a gdy filmu w nich nie ma — Google („gdzie obejrzeć”) |

Szczegóły i decyzje:
- Przemoc nie wyklucza filmu od razu (przykład: „Django” — wciąga, ale brutalne), tylko obniża
  ocenę; odpadają filmy z wieloma „krwawymi” słowami kluczowymi TMDB (gore, tortury, splatter…)
  i każdy horror. Reguły są w `App/PartnerProfile.swift`.
- W „Randce” i „Wspólnej liście” co czwarty tytuł to film, który znasz i oceniłeś wysoko
  („Znasz i lubisz”); reszta to filmy, których jeszcze nie oceniłeś.
- „Randka”, „Wspólna lista” i „Premiery HD” to tylko filmy (bez seriali).
- Przycisk pomija scenariusze, w których akurat nic nie ma. Bez linków do serwisów VOD
  działają „Premiery HD” i „Wspólna lista”.
- „Nowości” to przybliżenie: TMDB nie podaje dokładnej daty dodania tytułu do serwisu,
  więc liczą się premiery cyfrowe w Polsce z ostatnich ~5 tygodni, świeże filmy (pół roku),
  które już są w abonamencie, i seriale z odcinkami z ostatniego miesiąca.
- Tytuły, które już oceniłeś na Filmwebie, mają na plakacie zielony znaczek z Twoją oceną.
- Każdy scenariusz pamięta, gdzie skończyłeś przewijać. Ukrycie tytułu działa we wszystkich.

Każdy widget z propozycjami ma ustawienia („Edytuj widżet”): **Scenariusz na start**,
**Rodzaj** (filmy / seriale),
**Źródło** (w Twoim guście / z listy „Chcę zobaczyć” / do powtórki / zapisane) i **Serwis**.
Widgety o tych samych ustawieniach przewijają się razem; różne ustawienia — niezależnie.

Akcje i animacje:
- **↻ / ⏭** — „tasowanie kart”: każda karta robi pełny obrót z perspektywą i sprężystym
  dobiciem, kolumna po kolumnie; w połowie obrotu podmienia się plakat, a po nim przelatuje
  odblask. Zmiana scenariusza obraca wszystkie karty naraz z rozmyciem.
- **↶ Cofnij o krok** — wraca do tytułów sprzed ostatniego kliknięcia (do 20 kroków wstecz);
  karty obracają się wtedy w drugą stronę. W panelu działa też ⌘Z.
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

## Instalacja bez Xcode na co dzień

Raz skonfiguruj Team ID (krok 1 niżej), potem:

```bash
./Scripts/install.sh
```

Skrypt generuje projekt, buduje wersję Release, instaluje `MovieDesk.app` w `/Applications`
i ją uruchamia. W ustawieniach włącz **Uruchamiaj przy logowaniu** — od tej pory aplikacja
startuje sama, a dane odświeżają się co noc bez Twojego udziału. Skrypt uruchamiasz
ponownie tylko po zmianach w kodzie (`./Scripts/install.sh --pull` pobierze je i zbuduje).

Uwaga: przy darmowym koncie Apple ID podpis deweloperski może po jakimś czasie wygasnąć —
wtedy wystarczy jeszcze raz uruchomić skrypt.

### Widzę stare widgety albo nie widzę nowych

macOS pamięta widget z każdej kopii aplikacji, którą kiedykolwiek uruchomiłeś (buildy z Xcode,
starszy identyfikator aplikacji), i potrafi pokazywać w galerii starą wersję. Uruchom:

```bash
./Scripts/reset-widgets.sh
```

Skrypt zostawia tylko `/Applications/MovieDesk.app`, usuwa kopie z buildów Xcode i przeładowuje
usługi widgetów (`install.sh` robi to automatycznie). Potem usuń stare widgety z pulpitu
i dodaj nowe. Widgety na pulpicie reagują na kliknięcia, gdy pulpit jest na wierzchu —
jeśli są przygaszone przez okna, kliknij najpierw w pusty pulpit.

## Ikona

Źródło ikony to `Design/AppIcon.svg`; gotowe rozmiary są w `App/Assets.xcassets/AppIcon.appiconset`.

## Uruchomienie (z Xcode, do pracy nad kodem)

1. Utwórz lokalną konfigurację i wpisz w niej swój Team ID:

   ```bash
   cp Config/Local.xcconfig.example Config/Local.xcconfig
   ```

2. Wygeneruj projekt i otwórz go w Xcode:

   ```bash
   xcodegen && open -a Xcode MovieDesk.xcodeproj
   ```

3. Uruchom schemat **MovieDesk** (⌘R). W pasku menu pojawi się ikona ▶︎.
4. Panel → **Ustawienia** → **Rekomendacje**: **Zaloguj się…** do Filmwebu (logowanie przez
   Google otwiera osobne okienko; jeśli coś utknie, przycisk ↺ zaczyna od nowa), wklej klucz
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
