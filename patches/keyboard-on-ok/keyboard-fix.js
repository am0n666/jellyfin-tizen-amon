(function () {
    'use strict';
    var SEL = 'input[type="text"],input[type="password"],input[type="email"],input[type="number"],input[type="search"],input[type="url"],input[type="tel"],input:not([type]),textarea';
    function isTextField(el) {
        return !!(el && el.matches && el.matches(SEL) && !el.disabled);
    }
    function guard(el) {
        if (!el.readOnly) {
            el.readOnly = true;
            el.setAttribute('data-jf-kb-guard', '1');
        }
    }
    function unguard(el) {
        if (el.getAttribute('data-jf-kb-guard') === '1') {
            el.readOnly = false;
            el.removeAttribute('data-jf-kb-guard');
        }
    }
    // Zdejmij blokade i wymus otwarcie IME (blur + refocus).
    // Flaga "opening" chroni sekwencje przed wlasnym handlerem focusout,
    // ktory inaczej rozbroilby pole w trakcie blur().
    function openKeyboard(el) {
        unguard(el);
        el.setAttribute('data-jf-kb-armed', '1');
        el.setAttribute('data-jf-kb-opening', '1');
        el.blur();
        setTimeout(function () {
            el.focus();
            el.removeAttribute('data-jf-kb-opening');
            try {
                var n = el.value ? el.value.length : 0;
                el.setSelectionRange(n, n);
            } catch (err) { /* np. input[type=number] */ }
        }, 60);
    }
    // Najechanie pilotem na pole -> zablokuj, zeby IME sie nie otworzylo.
    // Pole "uzbrojone" (po OK) pomijamy - to nasz wlasny refocus.
    document.addEventListener('focusin', function (e) {
        var el = e.target;
        if (isTextField(el) && el.getAttribute('data-jf-kb-armed') !== '1') {
            guard(el);
        }
    }, true);
    // Opuszczenie pola -> przywroc normalny stan i rozbroj,
    // ALE nie w trakcie naszej wlasnej sekwencji otwierania (blur+refocus)
    document.addEventListener('focusout', function (e) {
        var el = e.target;
        if (isTextField(el) && el.getAttribute('data-jf-kb-opening') !== '1') {
            unguard(el);
            el.removeAttribute('data-jf-kb-armed');
        }
    }, true);
    document.addEventListener('keydown', function (e) {
        var el = document.activeElement;
        if (!isTextField(el)) return;
        // OK/Enter na zablokowanym polu -> otworz klawiature
        if (e.keyCode === 13 && el.getAttribute('data-jf-kb-guard') === '1') {
            e.preventDefault();
            e.stopImmediatePropagation();
            openKeyboard(el);
            return;
        }
        // Done (65376) / Cancel (65385) z IME -> ponownie zablokuj,
        // fokus zostaje na polu, wiec mozna dalej nawigowac strzalkami
        if ((e.keyCode === 65376 || e.keyCode === 65385) && el.getAttribute('data-jf-kb-armed') === '1') {
            el.removeAttribute('data-jf-kb-armed');
            guard(el);
        }
    }, true);
    // Fallback: klik na zablokowanym polu (mysz / syntetyczny click z
    // inputManagera jellyfin-web) rowniez otwiera klawiature
    document.addEventListener('click', function (e) {
        var t = e.target;
        var el = t && t.closest ? t.closest(SEL) : null;
        if (el && el.getAttribute('data-jf-kb-guard') === '1') {
            e.preventDefault();
            e.stopImmediatePropagation();
            openKeyboard(el);
        }
    }, true);
})();
