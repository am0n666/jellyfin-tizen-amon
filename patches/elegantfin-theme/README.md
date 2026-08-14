# elegantfin-theme

Dodaje **ElegantFin** jako pozycję na liście **Ustawienia → Wyświetlanie → Motyw**. Nie trzeba wklejać `@import` w pole Niestandardowy kod CSS.

To **pełny, samodzielny motyw** — łatka **nie** dołącza wbudowanego Dark. Wybranie ElegantFin podmienia arkusz `themes/<id>/theme.css` (tak działa jellyfin-web), a ten plik zawiera import z CDN oraz korektę skali TV.

## Źródło

- Nazwa: `ElegantFin`
- URL: `https://cdn.jsdelivr.net/gh/lscambo13/ElegantFin@main/Theme/ElegantFin-jellyfin-theme-build-latest-minified.css`
- Projekt: [lscambo13/ElegantFin](https://github.com/lscambo13/ElegantFin)

## Skala na TV

jellyfin-web w trybie `.layout-tv` ustawia `font-size: 125%` (wytyczne Tizen/WebOS: minimum 20px). Na 43" 4K (logiczne 1080p) ElegantFin wygląda wtedy jak UI w za niskiej rozdzielczości.

`tv-override.css` cofa to do **100%** (baza pulpitu). Doklejany jest zaraz pod `@import` w `theme.css`.

Żeby zmienić skalę, edytuj `font-size` w `tv-override.css`:

- `110%` — trochę większe niż pulpit, mniejsze niż stock TV
- `90%` — jeszcze ciaśniej, jeśli 100% nadal za duże

## Faza działania

**POST** — `post.cmd` uruchamia `apply.ps1`:

1. czyta `themes.lst`,
2. tworzy `www/themes/elegantfin/theme.css` z `@import` + `tv-override.css`,
3. dopisuje wpis `{ name, id, color }` do `www/config.json`.

Operacja jest idempotentna. Brak `config.json` / `tv-override.css` albo nieudany zapis przerywa build.

## Konfiguracja

Edytuj `themes.lst` (jedna linia na motyw):

```
id|name|color|url
```

## Jak włączyć na TV

Po wgraniu `.wgt`: **Ustawienia → Wyświetlanie → Motyw → ElegantFin** i zapisz. TV musi mieć dostęp do `cdn.jsdelivr.net`.

## Znane ograniczenia

- ElegantFin jest oficjalnie instalowany jako Custom CSS (nakładka). Tutaj ładuje się **zamiast** `themes/dark/theme.css`.
- Aktualizacje motywu z CDN widać po restarcie aplikacji; przebudowa `.wgt` jest potrzebna przy zmianie URL albo `tv-override.css`.
- 100% schodzi poniżej oficjalnego minimum 20px Tizen — na 43" 4K z kanapy zwykle nadal czytelne. Jeśli tekst będzie za drobny, podnieś do `110%`.
- Motyw nie jest ustawiany automatycznie — trzeba go wybrać raz na koncie.
