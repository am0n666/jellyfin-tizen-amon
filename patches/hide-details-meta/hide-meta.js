(function () {
    'use strict';

    // ================================================================
    //  hide-details-meta  (v7)
    //  Ukrywa wiersze metadanych na stronie szczegolow oraz sekcje
    //  interfejsu. Dwa niezalezne mechanizmy:
    //   1) CSS po klasach elementow (natychmiastowy, pewny),
    //   2) dopasowanie po widocznej etykiecie (zapasowy) - w v4
    //      mocno ograniczone, zeby nie ruszac nawigacji aplikacji.
    //
    //  KONFIGURACJA - edytuj dwie listy ponizej.
    // ================================================================

    // Mechanizm 1: klasy elementow do ukrycia (wg szablonu
    // src/controllers/itemDetails/index.html w jellyfin-web)
    var HIDE_CLASSES = [
        '.genresGroup',      // Gatunki (uklad wierszowy)
        '.itemGenres',       // Gatunki (akapit tekstowy przy opisie)
        '.directorsGroup',   // Rezyseria
        '.writersGroup',     // Scenariusz
        '.studiosGroup',     // Wytwornie
        '.itemTags',         // Znaczniki (nie maja wiersza "Group")
        '.nextUpSection'     // "Do obejrzenia" na stronie serialu
    ];

    // Mechanizm 2: widoczne etykiety sekcji/wierszy do ukrycia
    // (bez wielkosci liter, bez dwukropka; PL + EN dla pewnosci)
    var HIDE_LABELS = [
        'znaczniki', 'tagi', 'tags',
        'reżyser', 'reżyseria', 'director', 'directors',
        'scenariusz', 'writer', 'writers',
        'wytwórnie', 'wytwórnia', 'studios', 'studio',
        'gatunki', 'gatunek', 'genres', 'genre',
        'do obejrzenia', 'next up'
    ];

    // ----------------------------------------------------------------
    //  Ponizej nie trzeba nic zmieniac.
    // ----------------------------------------------------------------

    // Elementy, ktorych NIGDY nie wolno ukryc ani ukryc ich przodka.
    // To zabezpieczenie przed zniknieciem nawigacji aplikacji.
    var PROTECTED = '.skinHeader, .mainDrawer, .headerTabs, .emby-tabs-slider, .dialogContainer';

    // Mechanizm 2 dziala TYLKO w tych obszarach (nigdy w ustawieniach).
    var SCAN_ROOTS = '#itemDetailPage, #indexPage, #homePage, .homePage, .itemDetailPage';

    var SET = {};
    HIDE_LABELS.forEach(function (l) { SET[l] = 1; });

    function injectCss() {
        if (document.getElementById('jf-hm-style')) return;
        var st = document.createElement('style');
        st.id = 'jf-hm-style';
        st.textContent = HIDE_CLASSES.join(',') + '{display:none !important}';
        (document.head || document.documentElement).appendChild(st);
    }

    function norm(s) {
        return (s || '').replace(/\s+/g, ' ').trim().replace(/:$/, '').toLowerCase();
    }

    function isSectionHeader(el) {
        return el.classList.contains('sectionTitle') || !!el.closest('.sectionTitleContainer');
    }

    function matches(el) {
        if (el.childElementCount > 1) return false;
        var t = norm(el.textContent);
        if (!t || t.length > 40 || SET[t] !== 1) return false;
        // nie ruszaj formularzy/ustawien, nawigacji, dialogow, zakladek
        if (el.closest('form, label, select, option, .inputContainer, .selectContainer, ' +
                       '.checkboxContainer, .listItem, ' + PROTECTED + ', ' +
                       '.emby-tab-button, [is="emby-tab-button"]')) {
            return false;
        }
        // element w linku/przycisku dopuszczamy TYLKO gdy to naglowek sekcji
        if (el.closest('button, a') && !isSectionHeader(el)) return false;
        return true;
    }

    // Zwraca kontener do ukrycia albo null. BRAK awaryjnego
    // "ukryj rodzica" - to on powodowal znikanie gornego paska w v3.
    function rowFor(el) {
        if (isSectionHeader(el)) {
            return el.closest('.verticalSection');
        }
        var g = el.closest('.detailsGroupItem');
        if (g) return g;
        var p = el.parentElement;
        while (p && p !== document.body) {
            if (/(^|\s)\w+Group(\s|$)/.test(String(p.className || ''))) return p;
            p = p.parentElement;
        }
        return null;
    }

    function safeToHide(row) {
        if (!row || row === document.body || row === document.documentElement) return false;
        if (row.matches(PROTECTED) || row.closest(PROTECTED)) return false;
        // nigdy nie ukrywaj kontenera, ktory zawiera naglowek/menu aplikacji
        var prot = document.querySelectorAll(PROTECTED);
        for (var i = 0; i < prot.length; i++) {
            if (row.contains(prot[i])) return false;
        }
        // nigdy nie ukrywaj calej strony
        if (row.matches('[data-role="page"], .page, .mainAnimatedPage, .skinBody')) return false;
        return true;
    }

    // Awaryjne przywrocenie: gdyby cokolwiek chronionego zostalo ukryte
    // (np. przez starsza wersje latki), odblokuj to.
    function healProtected() {
        var hidden = document.querySelectorAll('[data-jf-hm-row="1"]');
        for (var i = 0; i < hidden.length; i++) {
            if (!safeToHide(hidden[i])) {
                hidden[i].style.removeProperty('display');
                hidden[i].removeAttribute('data-jf-hm-row');
            }
        }
    }

    function scan() {
        injectCss();
        healProtected();
        var roots = document.querySelectorAll(SCAN_ROOTS);
        for (var r = 0; r < roots.length; r++) {
            var candidates = roots[r].querySelectorAll(
                '.sectionTitle, .sectionTitle > span, h2, h3, .label, [class*="Label"]'
            );
            for (var i = 0; i < candidates.length; i++) {
                var el = candidates[i];
                if (el.getAttribute('data-jf-hm') === '1') continue;
                if (!matches(el)) continue;
                var row = rowFor(el);
                if (safeToHide(row)) {
                    row.style.setProperty('display', 'none', 'important');
                    row.setAttribute('data-jf-hm-row', '1');
                }
                el.setAttribute('data-jf-hm', '1');
            }
        }
    }

    var scheduled = false;
    function schedule() {
        if (scheduled) return;
        scheduled = true;
        setTimeout(function () {
            scheduled = false;
            try { scan(); } catch (e) { /* nie wywracaj aplikacji */ }
        }, 150);
    }

    new MutationObserver(schedule).observe(document.documentElement, { childList: true, subtree: true });
    window.addEventListener('hashchange', schedule);
    document.addEventListener('DOMContentLoaded', schedule);

    // CSS wstrzykujemy NATYCHMIAST przy wczytaniu skryptu (jest w <head>,
    // wiec przed zbudowaniem strony) - dzieki temu ukrywane elementy nie
    // migaja przez chwile przed ukryciem.
    injectCss();
    schedule();
})();