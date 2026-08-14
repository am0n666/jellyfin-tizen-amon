# jellyfin-tizen-amon

Zestaw łatek (modyfikacji) do oficjalnego klienta [jellyfin-tizen](https://github.com/jellyfin/jellyfin-tizen) na telewizory Samsung (Tizen) wraz ze skryptem `build.cmd`, który **w pełni automatycznie** pobiera najnowsze źródła klienta i interfejsu (jellyfin-web), nakłada wybrane łatki i buduje gotowy, podpisany pakiet `.wgt` gotowy do instalacji na telewizorze.

Nie jest to fork — repozytorium nie przechowuje kopii kodu Jellyfin. Przy każdym uruchomieniu `build.cmd` sam klonuje najświeższe (lub wskazane) wersje oficjalnych repozytoriów `jellyfin-tizen` i `jellyfin-web`, a następnie modyfikuje je łatkami zdefiniowanymi w tym repozytorium.

## Jak to działa

1. **Sprawdzenie i instalacja zależności** — git, Node.js ≥ 20, Tizen Studio CLI oraz certyfikat/profil podpisywania są sprawdzane i w razie potrzeby instalowane automatycznie (przez `winget`).
2. **Pobranie i build interfejsu `jellyfin-web`** — klonowanie wybranej wersji (domyślnie najnowszy stabilny tag), kompilacja i cache'owanie w `work\` (rekompilacja następuje tylko przy zmianie wersji).
3. **Pobranie źródeł `jellyfin-tizen`** — domyślnie najnowsza gałąź `master`, opcjonalnie konkretny tag/wydanie.
4. **Nałożenie łatek — faza PRE** — na świeżo pobranych źródłach `jellyfin-tizen` (diffy `.patch`/`.diff`, pliki `overlay\`, skrypty `run.cmd`), przed instalacją zależności npm.
5. **`npm ci` + build klienta** — z podpiętym katalogiem `dist\` zbudowanego wcześniej `jellyfin-web` (zmienna `JELLYFIN_WEB_DIR`).
6. **Nałożenie łatek — faza POST** — na już zbudowanym interfejsie w katalogu `www\` (pliki `post-overlay\`, skrypty `post.cmd`) — na tym etapie łatki najczęściej wstrzykują własne skrypty JS/CSS do `index.html`.
7. **Pakowanie i podpisywanie** — `tizen build-web` + `tizen package`, wynikowy plik `.wgt` trafia do katalogu `OUTPUT_DIR` z nazwą zawierającą znacznik czasu.

Cały proces uruchamia się jednym poleceniem, bez żadnej ręcznej ingerencji.

## Wymagania

- Windows 10/11 (skrypt jest plikiem `.cmd`)
- Połączenie z internetem (pobieranie źródeł i zależności)
- Reszta narzędzi (git, Node.js, Tizen Studio) instaluje się automatycznie, o ile dostępny jest `winget`; w przeciwnym razie skrypt poprosi o ręczną instalację i poda odpowiedni link

## Szybki start

1. Skopiuj `config.cfg` i uzupełnij co najmniej:
   - `TIZEN_STUDIO` — katalog instalacyjny Tizen Studio,
   - `OUTPUT_DIR` — katalog, do którego trafi gotowy plik `.wgt`.
2. W `patches.cfg` odkomentuj/wypisz nazwy łatek, które mają zostać zastosowane (jedna nazwa = jeden podkatalog w `patches\`, kolejność w pliku = kolejność nakładania). Pusty plik lub jego brak oznacza budowanie czystej, oficjalnej wersji klienta bez żadnych modyfikacji.
3. Uruchom:

   ```
   build.cmd
   ```

4. Po zakończeniu w katalogu `OUTPUT_DIR` pojawi się plik `Jellyfin-mod_<data-godzina>.wgt`, gotowy do instalacji na telewizorze (np. przez Tizen Studio / `tizen install`).

## Konfiguracja (`config.cfg`)

Najważniejsze opcje (pełny opis wraz z wartościami domyślnymi znajduje się w komentarzach pliku):

| Klucz | Opis |
|---|---|
| `TIZEN_STUDIO` | Katalog instalacyjny Tizen Studio (wymagane) |
| `OUTPUT_DIR` | Katalog docelowy dla zbudowanych plików `.wgt` (wymagane) |
| `WORK_DIR` | Katalog roboczy na pobrane źródła i cache `jellyfin-web` |
| `JELLYFIN_TIZEN_REPO` / `JELLYFIN_TIZEN_REF` | Repozytorium i gałąź/tag klienta `jellyfin-tizen` |
| `JELLYFIN_WEB_VERSION` / `JELLYFIN_WEB_REPO` | Wersja (tag) i repozytorium interfejsu `jellyfin-web` |
| `REBUILD_WEB` | Wymusza pełną przebudowę `jellyfin-web` mimo cache |
| `CERT_PROFILE` / `CERT_ALIAS` / `CERT_PASSWORD` | Profil i certyfikat podpisywania pakietu `.wgt` (tworzone automatycznie przy pierwszym uruchomieniu) |
| `KEEP_SOURCES` | Nie usuwaj źródeł `jellyfin-tizen` między buildami (szybszy, mniej niezawodny build) |
| `WGT_NAME_PREFIX` | Prefiks nazwy pliku wynikowego |

## Struktura repozytorium

```
build.cmd        - skrypt budujący (uruchamia cały proces)
config.cfg       - konfiguracja główna (ścieżki, wersje, certyfikat)
patches.cfg      - lista włączonych łatek i kolejność ich nakładania
patches\         - katalog z łatkami, każda we własnym podkatalogu
```

## Format łatki (`patches\<nazwa>\`)

Każda łatka to podkatalog w `patches\`, mogący zawierać dowolny z poniższych elementów:

| Element | Faza | Opis |
|---|---|---|
| `*.patch`, `*.diff` | PRE | Diffy w formacie `git apply`, nakładane na źródła `jellyfin-tizen` zaraz po ich pobraniu |
| `overlay\` | PRE | Pliki kopiowane na źródła z nadpisaniem, przed `npm` |
| `run.cmd` | PRE | Dowolny skrypt uruchamiany przed `npm` |
| `post-overlay\` | POST | Pliki kopiowane po zbudowaniu interfejsu (katalog `www\`) |
| `post.cmd` | POST | Dowolny skrypt uruchamiany po zbudowaniu interfejsu, przed pakowaniem `.wgt` — tu zwykle modyfikuje się gotowy interfejs |

Skrypty `run.cmd` i `post.cmd` otrzymują dwa argumenty: `%1` = katalog źródeł `jellyfin-tizen`, `%2` = katalog łatki.

## Dostępne łatki

| Łatka | Opis |
|---|---|
| [`keyboard-on-ok`](patches/keyboard-on-ok/README.md) | Wirtualna klawiatura na TV otwiera się dopiero po naciśnięciu OK/Enter na polu tekstowym, a nie automatycznie przy każdym najechaniu pilotem |
| [`hide-details-meta`](patches/hide-details-meta/README.md) | Ukrywa wybrane metadane na stronie szczegółów pozycji (Znaczniki, Reżyseria, Scenariusz, Wytwórnie, Gatunki) oraz sekcję „Do obejrzenia” |
| [`prime-episodes`](patches/prime-episodes/README.md) | Zastępuje domyślną siatkę sezonów na stronie serialu widokiem odcinków w stylu Prime Video *(eksperymentalna)* |

Szczegóły działania, konfiguracji i znane ograniczenia każdej łatki opisane są w jej własnym pliku `README.md`.

## Dodawanie własnej łatki

1. Utwórz nowy katalog w `patches\`, np. `patches\moja-latka\`.
2. Dodaj w nim dowolną kombinację plików opisanych w sekcji [Format łatki](#format-łatki-patcheslatki): `*.patch`/`*.diff`, `overlay\`, `run.cmd`, `post-overlay\`, `post.cmd`.
3. Dopisz nazwę katalogu (`moja-latka`) w nowej linii pliku `patches.cfg` — kolejność wpisów decyduje o kolejności nakładania łatek.
4. Uruchom `build.cmd`.

Większość istniejących łatek modyfikuje już zbudowany interfejs w fazie POST poprzez wstrzyknięcie własnego skryptu JS do `index.html` — dzięki temu nie ingerują bezpośrednio w kod źródłowy `jellyfin-web`/`jellyfin-tizen` i są odporne na zmiany wersji. Warto trzymać się tego podejścia, o ile modyfikacja na to pozwala.

## Uwagi

- Domyślnie każdy build pobiera świeże źródła `jellyfin-tizen` (`KEEP_SOURCES=0`) — najbardziej niezawodne, ale wolniejsze podejście.
- `jellyfin-web` ma własny mechanizm cache w `work\jellyfin-web\dist` — rekompilacja następuje tylko przy zmianie wersji (`JELLYFIN_WEB_VERSION`) lub przy `REBUILD_WEB=1`.
- Plik wynikowy `.wgt` jest podpisywany automatycznie utworzonym certyfikatem deweloperskim — do własnej instalacji na telewizorze jest to wystarczające.
