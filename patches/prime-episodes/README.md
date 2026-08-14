# prime-episodes (v3)

Na stronie serialu zastępuje domyślną sekcję **„Sezony\"** (kafelki z plakatami) interfejsem w stylu **Prime Video**: poziomy rząd przycisków z sezonami, a pod nim pionowa lista odcinków wybranego sezonu — miniatura 16:9, numer i tytuł odcinka, czas trwania, data premiery, opis (do 3 linii), znacznik ✓ dla obejrzanych i pasek postępu dla częściowo obejrzanych.

Kliknięcie/OK na odcinku otwiera jego stronę (skąd można odtworzyć lub wznowić). W połączeniu z łatką `keyboard-on-ok` i ukryciem „Do obejrzenia\" (łatka `hide-details-meta`) strona serialu robi się bardzo zbliżona do Prime Video.

**Status: eksperymentalna** — wymaga przetestowania na telewizorze; patrz ograniczenia niżej.

## v3 — brak mignięcia starego układu

W v2 styl i flaga `jfpv-pending` powstawały dopiero po załadowaniu `prime-episodes.js` z końca `<head>`, a podmiana czekała na `setTimeout(80)` + odpowiedź API. Przez ułamek sekundy były widoczne domyślne kafelki sezonów.

v3 wstrzykuje `prime-episodes.css` i maleńki `prime-boot.js` na **początek** `<head>`. Boot przy zmianie hasha od razu stawia `html.jfpv-pending`, a CSS chowa `#childrenCollapsible` / `#listChildrenCollapsible` przez `visibility:hidden` (nie `display:none` — inaczej łatka nie znalazłaby sekcji). Główny skrypt pyta `getItem` od razu: film/sezon odślania oryginał, serial czeka z ukryciem aż nowy widok jest w DOM. Skan jest w `requestAnimationFrame` zamiast 80 ms.

## Konfiguracja

Na górze `prime-episodes.js`:

- `SECTION_TITLES` — nagłówki sekcji, którą łatka podmienia (domyślnie `sezony`/`seasons`; dopisz tłumaczenie, jeśli interfejs działa w innym języku),
- `TXT` — teksty własne łatki (nagłówek „Odcinki\", „Sezon\", „min\").

## Faza działania

**POST** — `post.cmd` kopiuje `prime-episodes.css`, `prime-boot.js` i `prime-episodes.js` do katalogu z `index.html` (`www\`), wstawia `<link>` + boot na początek `<head>` i główny `<script>` na końcu `<head>`. Operacja idempotentna i weryfikowana.

## Sposób działania

Skrypt nie modyfikuje kodu jellyfin-web. Obserwuje DOM i adres (`#/details?id=...`); gdy wykryje stronę pozycji typu `Series`, znajduje sekcję „Sezony\" po nagłówku, podmienia jej zawartość i pobiera dane przez wbudowane API klienta (`ApiClient.getSeasons` / `getEpisodes` / `getScaledImageUrl`). Miniatura odcinka: obraz Primary odcinka, awaryjnie backdrop serialu.

## Znane ograniczenia

- Działa tylko na stronie **serialu** — nie zmienia wyglądu strony pojedynczego sezonu (ta pozostaje domyślna, choć przy tej łatce rzadko się na nią trafia).
- Nawigacja pilotem opiera się na menedżerze fokusa jellyfin-web (elementy listy to zwykłe przyciski) — kolejność poruszania się strzałkami i przewijanie do zaznaczonego elementu wymagają weryfikacji na TV.
- Wybór odcinka otwiera jego stronę zamiast od razu startować odtwarzanie — bezpośrednie odtwarzanie wymagałoby ingerencji w wewnętrzne moduły jellyfin-web i byłoby wrażliwe na wersję.
- Jeśli jellyfin-web zmieni strukturę sekcji lub nagłówek „Sezony\", łatka nie znajdzie sekcji do podmiany — objawem będzie zwykły, niezmieniony widok (łatka nie psuje wtedy niczego, po prostu się nie aktywuje). Bezpiecznik zdejmuje `jfpv-pending` po 4 s, żeby nie zostawić pustego miejsca.
- Na stronie filmu extras mogą pojawić się z lekkim opóźnieniem (do odpowiedzi `getItem`) — to koszt ukrycia kafelków sezonów przed pierwszym paintem.
