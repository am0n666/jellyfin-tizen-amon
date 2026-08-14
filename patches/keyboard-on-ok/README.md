# keyboard-on-ok

Wirtualna klawiatura (IME) na telewizorze Samsung otwiera się **dopiero po wciśnięciu OK/Enter** na zaznaczonym polu tekstowym — a nie automatycznie przy każdym najechaniu na pole podczas przewijania pilotem (np. w ustawieniach).

## Faza działania

**POST** — łatka nie zawiera plików `*.patch` ani `overlay/`. Cała logika jest w `post.cmd`, uruchamianym przez `build.cmd` po kroku npm (gdy istnieje już zbudowany katalog `www\`), a przed pakowaniem `.wgt`.

## Pliki i sposób działania

- `keyboard-fix.js` — samodzielny skrypt uruchamiany w przeglądarce TV:
  - `focusin` na polu tekstowym → pole dostaje `readOnly` (Tizen nie pokazuje klawiatury dla pól readonly),
  - OK/Enter (keyCode `13`) na zablokowanym polu → zdejmuje `readOnly` i wymusza `blur()` + `focus()`, co otwiera klawiaturę; kursor ustawiany na końcu tekstu,
  - Done (`65376`) / Cancel (`65385`) z IME → blokada wraca, fokus zostaje na polu (dalej można nawigować strzałkami),
  - opuszczenie pola (`focusout`) → stan pola wraca do normy,
  - fallback: kliknięcie (mysz lub syntetyczny click z inputManagera jellyfin-web) na zablokowanym polu również otwiera klawiaturę.
- `post.cmd` — kopiuje `keyboard-fix.js` do katalogu z `index.html` (`www\`, awaryjnie `dist\`) i wstrzykuje `<script src="keyboard-fix.js"></script>` na początek `<head>` (przed bundlem aplikacji). Operacja jest idempotentna i weryfikowana — brak wstawki po zapisie przerywa build z błędem.

## Znane ograniczenia

- Łatka nie modyfikuje kodu jellyfin-web, więc jest odporna na zmiany wersji interfejsu; opiera się jednak na zachowaniu Tizen IME (brak klawiatury dla pól `readOnly` oraz keyCode'y `65376`/`65385` klawiszy Done/Cancel) — na innych platformach niż Samsung TV te kody mogą się różnić.
- Pola tworzone w nietypowy sposób (bez zdarzenia `focusin`, np. `contenteditable`) nie są objęte blokadą.
