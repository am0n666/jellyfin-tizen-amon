# elegantfin-theme

Dodaje **ElegantFin** jako pozycję na liście **Ustawienia → Wyświetlanie → Motyw**. Nie trzeba wklejać `@import` w pole Niestandardowy kod CSS.

To **pełny, samodzielny motyw** — łatka **nie** dołącza wbudowanego Dark. Wybranie ElegantFin podmienia arkusz `themes/<id>/theme.css` (tak działa jellyfin-web), a ten plik zawiera wyłącznie import z CDN.

## Źródło

- Nazwa: `ElegantFin`
- URL: `https://cdn.jsdelivr.net/gh/lscambo13/ElegantFin@main/Theme/ElegantFin-jellyfin-theme-build-latest-minified.css`
- Projekt: [lscambo13/ElegantFin](https://github.com/lscambo13/ElegantFin)

## Faza działania

**POST** — `post.cmd` uruchamia `apply.ps1`:

1. czyta `themes.lst`,
2. tworzy `www/themes/elegantfin/theme.css` z `@import url("...")`,
3. dopisuje wpis `{ name, id, color }` do `www/config.json` (lista motywów jellyfin-web).

Operacja jest idempotentna: ponowny build nie dubluje wpisu. Brak `config.json` albo nieudany zapis przerywa build.

## Konfiguracja

Edytuj `themes.lst` (jedna linia na motyw):

```
id|name|color|url
```

`id` to katalog i wartość zapisywana w ustawieniach użytkownika (`a-z`, `0-9`, `-`). `color` trafia do meta `theme-color`.

## Jak włączyć na TV

Po wgraniu `.wgt`: **Ustawienia → Wyświetlanie → Motyw → ElegantFin** i zapisz. TV musi mieć dostęp do `cdn.jsdelivr.net`.

## Znane ograniczenia

- ElegantFin jest oficjalnie instalowany jako Custom CSS (nakładka). Tutaj ładuje się **zamiast** `themes/dark/theme.css`. Jeśli czegoś brakuje, można w `theme.css` dodać najpierw `@import url("../dark/theme.css");`.
- Aktualizacje motywu z CDN widać po restarcie aplikacji; przebudowa `.wgt` jest potrzebna tylko przy zmianie URL w `themes.lst`.
- Tizen ma `<access origin="*">`, ale brak sieci / blokada DNS = motyw się nie załaduje (zostaną style bazowe bundla).
- Motyw nie jest ustawiany automatycznie — trzeba go wybrać raz na koncie.
