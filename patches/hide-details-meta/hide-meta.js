(function () {
    'use strict';

    // ================================================================
    //  hide-details-meta  (v8)
    //  Ukrywa wiersze metadanych na stronie szczegolow oraz sekcje
    //  interfejsu. Dwa niezalezne mechanizmy:
    //   1) CSS z hide-meta.css w <head> (przed pierwszym paintem),
    //   2) dopasowanie po widocznej etykiecie + klasyfikacja
    //      .detailsGroupItem (requestAnimationFrame, przed paintem).
    //
    //  KONFIGURACJA - edytuj dwie listy ponizej.
    // ================================================================

    var HIDE_CLASSES = [
        '.genresGroup',
        '.itemGenres',
        '.directorsGroup',
        '.writersGroup',
        '.studiosGroup',
        '.itemTags',
        '.nextUpSection'
    ];

    var HIDE_LABELS = [
        'znaczniki', 'tagi', 'tags',
        'reżyser', 'reżyseria', 'director', 'directors',
        'scenariusz', 'writer', 'writers',
        'wytwórnie', 'wytwórnia', 'studios', 'studio',
        'gatunki', 'gatunek', 'genres', 'genre',
        'do obejrzenia', 'next up'
    ];

    var PROTECTED = '.skinHeader, .mainDrawer, .headerTabs, .emby-tabs-slider, .dialogContainer';
    var SCAN_ROOTS = '#itemDetailPage, #indexPage, #homePage, .homePage, .itemDetailPage';

    var SET = {};
    HIDE_LABELS.forEach(function (l) { SET[l] = 1; });

    var CSS =
        HIDE_CLASSES.join(',') + '{display:none!important}' +
        '.itemDetailsGroup .detailsGroupItem:not([data-jf-hm-keep="1"]){display:none!important}';

    function injectCss() {
        var st = document.getElementById('jf-hm-style');
        if (!st) {
            st = document.createElement('style');
            st.id = 'jf-hm-style';
            (document.head || document.documentElement).appendChild(st);
        }
        if (st.textContent !== CSS) st.textContent = CSS;
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
        if (el.closest('form, label, select, option, .inputContainer, .selectContainer, ' +
                       '.checkboxContainer, .listItem, ' + PROTECTED + ', ' +
                       '.emby-tab-button, [is="emby-tab-button"]')) {
            return false;
        }
        if (el.closest('button, a') && !isSectionHeader(el)) return false;
        return true;
    }

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
        var prot = document.querySelectorAll(PROTECTED);
        for (var i = 0; i < prot.length; i++) {
            if (row.contains(prot[i])) return false;
        }
        if (row.matches('[data-role="page"], .page, .mainAnimatedPage, .skinBody')) return false;
        return true;
    }

    function healProtected() {
        var hidden = document.querySelectorAll('[data-jf-hm-row="1"]');
        for (var i = 0; i < hidden.length; i++) {
            if (!safeToHide(hidden[i])) {
                hidden[i].style.removeProperty('display');
                hidden[i].removeAttribute('data-jf-hm-row');
            }
        }
    }

    // Wiersze React: CSS chowa wszystkie bez data-jf-hm-keep.
    // Tu oznaczamy, ktore zostawic (np. obsada), a ktore trzymac ukryte.
    function classifyGroupItems(root) {
        var items = root.querySelectorAll('.itemDetailsGroup .detailsGroupItem');
        for (var i = 0; i < items.length; i++) {
            var row = items[i];
            if (row.getAttribute('data-jf-hm-keep') === '1' || row.getAttribute('data-jf-hm-row') === '1') {
                continue;
            }
            var label = row.querySelector('.label');
            var t = norm(label && label.textContent);
            if (t && SET[t] === 1 && safeToHide(row)) {
                row.setAttribute('data-jf-hm-row', '1');
            } else {
                row.setAttribute('data-jf-hm-keep', '1');
            }
        }
    }

    function scan() {
        injectCss();
        healProtected();
        var roots = document.querySelectorAll(SCAN_ROOTS);
        for (var r = 0; r < roots.length; r++) {
            classifyGroupItems(roots[r]);
            var candidates = roots[r].querySelectorAll(
                '.sectionTitle, .sectionTitle > span, h2, h3, .label, [class*="Label"]'
            );
            for (var i = 0; i < candidates.length; i++) {
                var el = candidates[i];
                if (el.getAttribute('data-jf-hm') === '1') continue;
                if (!matches(el)) continue;
                var row = rowFor(el);
                if (row && row.classList && row.classList.contains('detailsGroupItem')) {
                    el.setAttribute('data-jf-hm', '1');
                    continue;
                }
                if (safeToHide(row)) {
                    row.style.setProperty('display', 'none', 'important');
                    row.setAttribute('data-jf-hm-row', '1');
                }
                el.setAttribute('data-jf-hm', '1');
            }
        }
    }

    var raf = 0;
    var rafFn = window.requestAnimationFrame || function (cb) { return setTimeout(cb, 0); };
    function schedule() {
        if (raf) return;
        raf = rafFn(function () {
            raf = 0;
            try { scan(); } catch (e) { /* nie wywracaj aplikacji */ }
        });
    }

    new MutationObserver(schedule).observe(document.documentElement, { childList: true, subtree: true });
    window.addEventListener('hashchange', schedule);
    document.addEventListener('DOMContentLoaded', schedule);

    injectCss();
    schedule();
})();
