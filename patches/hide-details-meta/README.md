# hide-details-meta (v8)

Ukrywa wybrane wiersze metadanych i sekcje interfejsu Jellyfin: domyślnie **Znaczniki, Reżyseria, Scenariusz, Wytwórnie, Gatunki** oraz sekcję **„Do obejrzenia\"** (Next Up).

## Historia wersji

- **v8** — koniec mignięcia ukrywanych elementów (FOUC). Przyczyna: w jellyfin-web `master` wiersze metadanych są komponentem React (`.detailsGroupItem`) **bez** starych klas `genresGroup` / `directorsGroup` itd., więc CSS v7 nic nie chował, a etykiety działały dopiero po `setTimeout(150)`. Dodatkowo sam `<style>` powstawał z JS, czyli po starcie bundla. v8 wstrzykuje `hide-meta.css` na początek `<head>` (przed bundlem), chowa wszystkie `.detailsGroupItem` aż JS oznaczy `data-jf-hm-keep` na wierszach do zostawienia (np. obsada) i skanuje w `requestAnimationFrame` (przed paintem, bez 150 ms).
- **v5** — górny pasek nawigacji nadal znikał, ale wyzwalaczem okazała się **zmiana motywu**, a nie samo wejście w ustawienia. Zmiana motywu podmienia arkusze stylów aplikacji i nie zmienia struktury strony szczegółów, więc mechanizm ukrywania łatki najprawdopodobniej nie jest tu przyczyną (v4 nie skanuje już stron ustawień). Niezależnie od przyczyny v5 dodaje **watchdog nagłówka**: jeśli `.skinHeader` stanie się niewidoczny (`display:none`, `visibility:hidden` lub `opacity:0`) poza odtwarzaniem wideo, łatka przywraca jego widoczność. Watchdog działa przy każdym skanie oraz cyklicznie co 1,5 s (zmiana motywu nie generuje mutacji DOM, na które reagowałby obserwator). Podczas odtwarzania wideo nagłówek ma być ukryty — tam łatka nie ingeruje.
  **Weryfikacja przyczyny:** żeby ustalić, czy problem w ogóle pochodzi od łatek, zakomentuj wszystkie wpisy w `patches.cfg`, zbuduj czystą wersję i zmień motyw. Jeśli pasek zniknie tak samo — to zachowanie samego jellyfin-web/Tizena.
- v4 — naprawa błędu z v3: po wejściu w Profil → Wyświetlanie i powrocie na ekran główny znikał górny pasek nawigacji. Przyczyna: zapasowy mechanizm etykiet skanował cały dokument (także strony ustawień) i gdy nie znalazł właściwego kontenera wiersza, ukrywał rodzica dopasowanego elementu — czasem duży kontener zawierający nagłówek aplikacji, który jest wspólny dla wszystkich ekranów. Zmiany: mechanizm etykiet działa tylko w obrębie strony szczegółów i ekranu głównego; usunięto awaryjne „ukryj rodzica\" (bez trafienia w kontener wiersza/sekcji nie ukrywa nic); dodano listę elementów chronionych (nagłówek, szuflada menu, zakładki, dialogi), których nie wolno ukryć ani ukryć ich przodka; dodano samonaprawę, która przy każdym skanie przywraca omyłkowo ukryte elementy chronione.
- v3 — poprawka po testach na TV: v2 ukryła „Do obejrzenia\" i wiersze DetailsGroupItems, ale Znaczniki zostały widoczne. Przyczyna zweryfikowana w szablonie `src/controllers/itemDetails/index.html` jellyfin-web: Znaczniki nie mają wiersza `tagsGroup` — są osobnym elementem `.itemTags`, a Gatunki występują dodatkowo jako akapit `.itemGenres` przy opisie. v3 dodaje do listy klas `.itemTags`, `.itemGenres` oraz `.nextUpSection` (dedykowana klasa sekcji Next Up na stronie serialu).
- v2 — poprawka po testach na TV: v1 nic nie ukrywała. Dwie przyczyny: (1) nagłówki sekcji typu „Do obejrzenia\" są w jellyfin-web opakowane w link `<a>` prowadzący do pełnej listy, a zabezpieczenie v1 odrzucało elementy wewnątrz linków; (2) v1 szukała etykiet wierszy tylko wewnątrz kontenera `.detailPageContent`, którego układ różni się między wersjami. v2 dodaje mechanizm oparty o stabilne klasy CSS wierszy i rozszerza wyszukiwanie etykiet na cały dokument.
- v1 — pierwsza wersja (nie działała).

## Dwa mechanizmy działania

1. **CSS z `hide-meta.css` (natychmiastowy)** — wstrzykiwany na początek `<head>` w `index.html`. Chowa wiersze po stałych klasach (`genresGroup`, `itemTags`, `nextUpSection` …) oraz wszystkie `.itemDetailsGroup .detailsGroupItem` bez atrybutu `data-jf-hm-keep`.
2. **Etykiety + klasyfikacja (JS)** — w `requestAnimationFrame` (przed paintem) oznacza wiersze React do zostawienia albo ukrycia i chowa sekcje po widocznym tekście (Next Up na ekranie głównym).

## Konfiguracja

Na górze `hide-meta.js` są dwie listy: `HIDE_CLASSES` (klasy wierszy) i `HIDE_LABELS` (etykiety, PL + EN). Obie można edytować bez znajomości reszty kodu. Te same klasy są też w `hide-meta.css` — przy zmianie listy klas zaktualizuj oba pliki.

## Faza działania

**POST** — `post.cmd` kopiuje `hide-meta.css` i `hide-meta.js` do katalogu z `index.html` (`www\`), wstawia `<link>` na początek `<head>` i `<script>` na końcu `<head>`. Operacja idempotentna i weryfikowana.

## Zabezpieczenia

Mechanizm etykiet pomija formularze i ustawienia, nagłówek aplikacji, okna dialogowe (panel filtrów) oraz zakładki bibliotek (np. zakładkę „Gatunki\" w widoku biblioteki). Elementy wewnątrz linków są dopuszczane wyłącznie, gdy są nagłówkiem sekcji.

## Szybki test bez telewizora

Zawartość `hide-meta.js` można wkleić do konsoli przeglądarki (F12) na zwykłym webowym interfejsie Jellyfin na komputerze — wiersze powinny zniknąć od razu. To najszybszy sposób weryfikacji i dostrajania listy `HIDE_LABELS` przed kolejną kompilacją.

## Znane ograniczenia

- Ukrywanie „Do obejrzenia\" działa **globalnie** — sekcja znika także z ekranu głównego. Jeśli to niepożądane, usuń wpisy `'do obejrzenia', 'next up'` z `HIDE_LABELS`.
- Jeśli serwer/interfejs używa innego tłumaczenia etykiety, dopisz je do `HIDE_LABELS`.
- Wiersze, które mają zostać (np. obsada), pojawiają się o jedną klatkę później niż reszta strony szczegółów — to świadoma wymiana zamiast mignięcia ukrywanych pól.
