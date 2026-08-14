# prime-episodes

Na stronie serialu zastępuje domyślną sekcję **„Sezony"** (kafelki z plakatami) interfejsem w stylu **Prime Video**: poziomy rząd przycisków z sezonami, a pod nim pionowa lista odcinków wybranego sezonu — miniatura 16:9, numer i tytuł odcinka, czas trwania, data premiery, opis (do 3 linii), znacznik ✓ dla obejrzanych i pasek postępu dla częściowo obejrzanych.

Kliknięcie/OK na odcinku otwiera jego stronę (skąd można odtworzyć lub wznowić). W połączeniu z łatką `keyboard-on-ok` i ukryciem „Do obejrzenia" (łatka `hide-details-meta`) strona serialu robi się bardzo zbliżona do Prime Video.

**Status: eksperymentalna** — wymaga przetestowania na telewizorze; patrz ograniczenia niżej.

## Konfiguracja

Na górze `prime-episodes.js`:

- `SECTION_TITLES` — nagłówki sekcji, którą łatka podmienia (domyślnie `sezony`/`seasons`; dopisz tłumaczenie, jeśli interfejs działa w innym języku),
- `TXT` — teksty własne łatki (nagłówek „Odcinki", „Sezon", „min").

## Faza działania

**POST** — `post.cmd` kopiuje `prime-episodes.js` do katalogu z `index.html` (`www\`) i wstrzykuje `<script>` na końcu `<head>`. Operacja idempotentna i weryfikowana.

## Sposób działania

Skrypt nie modyfikuje kodu jellyfin-web. Obserwuje DOM i adres (`#/details?id=...`); gdy wykryje stronę pozycji typu `Series`, znajduje sekcję „Sezony" po nagłówku, podmienia jej zawartość i pobiera dane przez wbudowane API klienta (`ApiClient.getSeasons` / `getEpisodes` / `getScaledImageUrl`). Miniatura odcinka: obraz Primary odcinka, awaryjnie backdrop serialu. Styl (CSS) wstrzykiwany jest przez sam skrypt — nie ma osobnego pliku CSS.

## Znane ograniczenia

- Działa tylko na stronie **serialu** — nie zmienia wyglądu strony pojedynczego sezonu (ta pozostaje domyślna, choć przy tej łatce rzadko się na nią trafia).
- Nawigacja pilotem opiera się na menedżerze fokusa jellyfin-web (elementy listy to zwykłe przyciski) — kolejność poruszania się strzałkami i przewijanie do zaznaczonego elementu wymagają weryfikacji na TV.
- Wybór odcinka otwiera jego stronę zamiast od razu startować odtwarzanie — bezpośrednie odtwarzanie wymagałoby ingerencji w wewnętrzne moduły jellyfin-web i byłoby wrażliwe na wersję.
- Jeśli jellyfin-web zmieni strukturę sekcji lub nagłówek „Sezony", łatka nie znajdzie sekcji do podmiany — objawem będzie zwykły, niezmieniony widok (łatka nie psuje wtedy niczego, po prostu się nie aktywuje).
